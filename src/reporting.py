"""
AquaEcoSched: Reporting & Baseline Evaluation Engine (FR-08, Slide 7, 10)
Generates audit reports, CSV/JSON export artifacts, and executes rigorous
baseline comparisons against First-Fit and Resource-Only scheduling policies.
"""

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Dict, List, Optional, Any
import json
import pandas as pd
import numpy as np

from .data_validation import DataValidator
from .resource_filter import ResourceFilter
from .energy_carbon import EnergyCarbonEstimator, EnergyCarbonEstimate
from .thermal_risk import ThermalRiskEstimator, ThermalRiskEstimate
from .risk_budget import RiskBudgetEnforcer
from .scheduler import AquaEcoScheduler, SchedulingDecision


@dataclass
class PolicyComparisonMetric:
    policy_name: str
    selected_pod_id: Optional[str]
    selected_pod_name: Optional[str]
    scheduled_successfully: bool
    energy_kwh: float
    carbon_kg_co2e: float
    water_temp_delta_c: float
    environmental_risk_score: float
    constraint_violations: int
    violation_details: List[str]


class BaselineComparator:
    """
    Executes multiple workloads across AquaEcoSched and baseline policies:
    1. AquaEcoSched (Multi-Objective Environmental-Aware)
    2. First-Fit Baseline (Hardware eligible only, picks first available pod)
    3. Resource-Only Baseline (Best-Fit resource packing, ignores environment)
    """

    def __init__(self):
        self.validator = DataValidator()
        self.res_filter = ResourceFilter()
        self.ec_estimator = EnergyCarbonEstimator()
        self.tr_estimator = ThermalRiskEstimator()

    def evaluate_workload(
        self,
        workload: Dict[str, Any],
        pod_df: pd.DataFrame,
        ocean_df: pd.DataFrame,
        scheduler: AquaEcoScheduler,
        risk_enforcer: RiskBudgetEnforcer
    ) -> Dict[str, PolicyComparisonMetric]:
        """
        Evaluate a single workload across all 3 policies under identical conditions.
        """
        # Step 4: Hardware filter
        res_out = self.res_filter.filter_pods(pod_df, workload)
        eligible_df = res_out.eligible_pods_df
        all_checks = res_out.all_pod_checks

        # Step 5 & 6: Compute impact for all pods
        ec_map: Dict[str, EnergyCarbonEstimate] = {}
        tr_map: Dict[str, ThermalRiskEstimate] = {}

        ocean_map = {str(r["pod_id"]): r for _, r in ocean_df.iterrows()}

        for _, prow in pod_df.iterrows():
            pid = str(prow["pod_id"])
            orow = ocean_map.get(pid)
            ec = self.ec_estimator.compute_energy_and_carbon(prow, orow, workload)
            power_kw = ec.total_pod_power_kw
            tr = self.tr_estimator.estimate_thermal_and_risk(prow, orow, power_kw)
            ec_map[pid] = ec
            tr_map[pid] = tr

        # Step 7: Risk budget
        budget_out = risk_enforcer.evaluate_constraints(ec_map, tr_map, ocean_df)

        # 1. AquaEcoSched Policy
        aqua_decision = scheduler.schedule(
            feasible_pod_ids=budget_out.passed_pod_ids,
            pod_df=pod_df,
            energy_carbon_map=ec_map,
            thermal_risk_map=tr_map,
            resource_checks=all_checks,
            risk_checks=budget_out.checks,
            workload=workload
        )

        aqua_metric = self._extract_policy_metric(
            "AquaEcoSched (Eco-Aware)",
            aqua_decision.selected_pod.pod_id if aqua_decision.selected_pod else None,
            pod_df, ec_map, tr_map, budget_out.checks
        )

        # 2. First-Fit Baseline (picks first eligible pod without environmental check)
        first_fit_pid = None
        if not eligible_df.empty:
            first_fit_pid = str(eligible_df.iloc[0]["pod_id"])

        ff_metric = self._extract_policy_metric(
            "Baseline: First-Fit",
            first_fit_pid,
            pod_df, ec_map, tr_map, budget_out.checks
        )

        # 3. Resource-Only Baseline (picks pod with least remaining capacity above demand - tightest fit)
        res_only_pid = None
        if not eligible_df.empty:
            req_cpu = float(workload.get("cpu_cores", 0))
            # Sort by least surplus CPU
            sorted_by_fit = eligible_df.sort_values(by="avail_cpu", ascending=True)
            res_only_pid = str(sorted_by_fit.iloc[0]["pod_id"])

        ro_metric = self._extract_policy_metric(
            "Baseline: Resource-Only",
            res_only_pid,
            pod_df, ec_map, tr_map, budget_out.checks
        )

        return {
            "AquaEcoSched": aqua_metric,
            "FirstFit": ff_metric,
            "ResourceOnly": ro_metric
        }

    def _extract_policy_metric(
        self,
        policy_name: str,
        pod_id: Optional[str],
        pod_df: pd.DataFrame,
        ec_map: Dict[str, EnergyCarbonEstimate],
        tr_map: Dict[str, ThermalRiskEstimate],
        budget_checks: Dict[str, Any]
    ) -> PolicyComparisonMetric:
        if not pod_id:
            return PolicyComparisonMetric(
                policy_name=policy_name,
                selected_pod_id=None,
                selected_pod_name="None (Infeasible)",
                scheduled_successfully=False,
                energy_kwh=0.0,
                carbon_kg_co2e=0.0,
                water_temp_delta_c=0.0,
                environmental_risk_score=0.0,
                constraint_violations=0,
                violation_details=["No pod allocated"]
            )

        pname = str(pod_df.loc[pod_df["pod_id"] == pod_id, "pod_name"].iloc[0]) if (pod_df["pod_id"] == pod_id).any() else pod_id
        ec = ec_map[pod_id]
        tr = tr_map[pod_id]

        violations = []
        if pod_id in budget_checks:
            bcheck = budget_checks[pod_id]
            if not bcheck.passed_all_constraints:
                violations = bcheck.rejection_reasons

        return PolicyComparisonMetric(
            policy_name=policy_name,
            selected_pod_id=pod_id,
            selected_pod_name=pname,
            scheduled_successfully=True,
            energy_kwh=round(ec.workload_energy_kwh, 3),
            carbon_kg_co2e=round(ec.workload_carbon_kg_co2e, 3),
            water_temp_delta_c=round(tr.delta_temp_c, 3),
            environmental_risk_score=round(tr.environmental_risk_score, 3),
            constraint_violations=len(violations),
            violation_details=violations
        )


class SchedulingReporter:
    """
    Generates structured reports and exports in CSV and JSON formats.
    """

    @staticmethod
    def generate_json_report(
        decision: SchedulingDecision,
        workload: Dict[str, Any],
        config: Dict[str, Any]
    ) -> str:
        data = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "workload": workload,
            "status": decision.status,
            "weights_applied": decision.weights_applied,
            "explanation_summary": decision.explanation_summary,
            "selected_pod": {
                "pod_id": decision.selected_pod.pod_id,
                "pod_name": decision.selected_pod.pod_name,
                "location": decision.selected_pod.location,
                "composite_score": decision.selected_pod.composite_score,
                "raw_metrics": decision.selected_pod.raw_metrics,
                "normalized_metrics": decision.selected_pod.normalized_metrics,
                "decision_notes": decision.selected_pod.decision_notes
            } if decision.selected_pod else None,
            "all_ranked_pods": [
                {
                    "rank": p.rank,
                    "pod_id": p.pod_id,
                    "pod_name": p.pod_name,
                    "composite_score": p.composite_score,
                    "raw_metrics": p.raw_metrics,
                    "decision_notes": p.decision_notes
                } for p in decision.ranked_pods
            ],
            "ineligible_pods": decision.ineligible_pods,
            "model_config": config
        }
        return json.dumps(data, indent=2)

    @staticmethod
    def generate_ranking_dataframe(decision: SchedulingDecision) -> pd.DataFrame:
        if not decision.ranked_pods:
            return pd.DataFrame()

        rows = []
        for p in decision.ranked_pods:
            rows.append({
                "Rank": p.rank,
                "Pod ID": p.pod_id,
                "Pod Name": p.pod_name,
                "Location": p.location,
                "Composite Score": p.composite_score,
                "Energy (kWh)": p.raw_metrics["energy_kwh"],
                "Carbon (kg CO2e)": p.raw_metrics["carbon_kg_co2e"],
                "Thermal Plume": p.raw_metrics["thermal_footprint"],
                "Eco Risk": p.raw_metrics["environmental_risk"],
                "Perf Penalty": p.raw_metrics["performance_penalty"],
                "Decision Notes": p.decision_notes
            })
        return pd.DataFrame(rows)
