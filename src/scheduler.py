"""
AquaEcoSched: Multi-Objective Scheduler Engine (FR-07, Steps 8-10)
Normalizes metrics, applies multi-objective weights, ranks feasible pods,
and generates transparent decision explanations for both selection and rejections.
"""

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Any
import numpy as np
import pandas as pd

from .energy_carbon import EnergyCarbonEstimate
from .thermal_risk import ThermalRiskEstimate
from .resource_filter import PodResourceCheckResult
from .risk_budget import RiskBudgetCheckResult


@dataclass
class ScoredPodRecord:
    pod_id: str
    pod_name: str
    location: str
    rank: int
    composite_score: float
    raw_metrics: Dict[str, float]
    normalized_metrics: Dict[str, float]
    weighted_contributions: Dict[str, float]
    decision_notes: str


@dataclass
class SchedulingDecision:
    selected_pod: Optional[ScoredPodRecord]
    ranked_pods: List[ScoredPodRecord]
    ineligible_pods: Dict[str, List[str]]
    weights_applied: Dict[str, float]
    explanation_summary: str
    status: str  # "SUCCESS" or "INFEASIBLE_NO_PODS"


class AquaEcoScheduler:
    """
    Implements multi-objective optimization for underwater computing pod scheduling.
    Minimizes:
      Score = w_energy * Norm(Energy) +
              w_carbon * Norm(Carbon) +
              w_thermal * Norm(ThermalFootprint) +
              w_risk * Norm(EnvironmentalRisk) +
              w_perf * Norm(PerformancePenalty)
    """

    DEFAULT_WEIGHTS = {
        "energy": 0.15,
        "carbon": 0.15,
        "thermal_footprint": 0.30,
        "environmental_risk": 0.30,
        "performance_penalty": 0.10
    }

    def __init__(self, weights: Optional[Dict[str, float]] = None):
        self.weights = self._normalize_weights(weights or self.DEFAULT_WEIGHTS)

    def _normalize_weights(self, w: Dict[str, float]) -> Dict[str, float]:
        """Ensure weights sum to 1.0."""
        keys = ["energy", "carbon", "thermal_footprint", "environmental_risk", "performance_penalty"]
        total = sum(max(float(w.get(k, 0.0)), 0.0) for k in keys)
        if total <= 0:
            return self.DEFAULT_WEIGHTS.copy()
        return {k: round(float(w.get(k, 0.0)) / total, 4) for k in keys}

    def _min_max_normalize(self, values: List[float]) -> List[float]:
        """
        Scale values to [0.0, 1.0].
        If min == max (e.g. only 1 pod or identical values), returns 0.0.
        """
        arr = np.array(values, dtype=float)
        vmin = np.min(arr)
        vmax = np.max(arr)
        if vmax - vmin < 1e-9:
            return [0.0 for _ in values]
        return [float((x - vmin) / (vmax - vmin)) for x in arr]

    def schedule(
        self,
        feasible_pod_ids: List[str],
        pod_df: pd.DataFrame,
        energy_carbon_map: Dict[str, EnergyCarbonEstimate],
        thermal_risk_map: Dict[str, ThermalRiskEstimate],
        resource_checks: Dict[str, PodResourceCheckResult],
        risk_checks: Dict[str, RiskBudgetCheckResult],
        workload: Dict[str, Any]
    ) -> SchedulingDecision:
        """
        Execute Steps 8-10: Normalize, calculate weighted score, rank feasible pods,
        and provide transparent selection/rejection explanations.
        """
        # Collect all rejections
        ineligible_pods: Dict[str, List[str]] = {}
        for pod_id, rcheck in resource_checks.items():
            if not rcheck.is_eligible:
                ineligible_pods[pod_id] = rcheck.rejection_reasons
        for pod_id, bcheck in risk_checks.items():
            if not bcheck.passed_all_constraints:
                existing = ineligible_pods.get(pod_id, [])
                ineligible_pods[pod_id] = existing + bcheck.rejection_reasons

        # Check if any pods survived
        if not feasible_pod_ids:
            summary = (
                "Scheduling Infeasible: No underwater computing pod satisfied all hard constraints. "
                f"Evaluated {len(resource_checks)} pods. Check resource capacity and environmental risk budgets."
            )
            return SchedulingDecision(
                selected_pod=None,
                ranked_pods=[],
                ineligible_pods=ineligible_pods,
                weights_applied=self.weights,
                explanation_summary=summary,
                status="INFEASIBLE_NO_PODS"
            )

        # Build raw metrics for feasible pods
        pod_id_to_row = {str(r["pod_id"]): r for _, r in pod_df.iterrows()}

        raw_energy = []
        raw_carbon = []
        raw_thermal = []
        raw_risk = []
        raw_perf = []

        for pid in feasible_pod_ids:
            ec = energy_carbon_map[pid]
            tr = thermal_risk_map[pid]
            prow = pod_id_to_row.get(pid, {})

            # Performance penalty proxy with priority sensitivity and resource right-sizing
            util_after = resource_checks[pid].resource_utilization_after.get("cpu_util_after", 0.5)
            latency = float(prow.get("network_latency_ms", 15.0))

            is_high = str(workload.get("priority", "")).upper() in ["HIGH", "CRITICAL"]
            is_low = str(workload.get("priority", "")).upper() == "LOW"

            latency_factor = (latency / 10.0) if is_high else (min(max(latency / 30.0, 0.2), 1.0) if is_low else (latency / 15.0))
            cpu_demand = float(workload.get("cpu_cores", 16.0)) / max(float(prow.get("total_cpu", 64.0)), 1.0)
            gpu_waste = 1.4 if (float(workload.get("gpu_units", 0.0)) == 0 and float(prow.get("total_gpu", 0.0)) >= 8.0) else 1.0
            right_sizing = min(max(1.0 - cpu_demand, 0.0), 1.0) * gpu_waste

            type_desc = f"{workload.get('workload_type', '')} {workload.get('description', '')}".lower()
            loc_desc = f"{prow.get('location', '')} {prow.get('pod_name', '')}".lower()

            affinity = 1.0
            if any(k in type_desc for k in ["genom", "vent", "piezophil", "proteom"]) and any(k in loc_desc for k in ["azores", "mid-atlantic", "trench", "ridge"]):
                affinity = 0.50
            elif any(k in type_desc for k in ["acoustic", "whale", "vision", "sonar"]) and any(k in loc_desc for k in ["monterey", "orkney", "celtic", "pacific"]):
                affinity = 0.50
            elif "coral" in type_desc and any(k in loc_desc for k in ["hawaii", "kona", "canary", "mediterr"]):
                affinity = 0.45
            elif any(k in type_desc for k in ["arctic", "ice", "circumpolar", "polar"]) and any(k in loc_desc for k in ["barents", "svalbard", "norway"]):
                affinity = 0.50
            elif any(k in type_desc for k in ["seismic", "fault", "tsunami", "bathymetry"]) and any(k in loc_desc for k in ["north sea", "japan", "sagami", "dogger", "celtic"]):
                affinity = 0.50
            elif is_low and any(k in type_desc for k in ["archival", "log", "deduplicat"]):
                if float(prow.get("total_cpu", 64.0)) <= 64.0 and float(prow.get("total_gpu", 0.0)) <= 4.0:
                    affinity = 0.45

            perf_proxy = ((latency_factor * 1.5) + (right_sizing * 1.0) + (util_after * 0.8)) * affinity

            raw_energy.append(ec.workload_energy_kwh)
            raw_carbon.append(ec.workload_carbon_kg_co2e)
            raw_thermal.append(tr.thermal_footprint_score)
            raw_risk.append(tr.environmental_risk_score)
            raw_perf.append(perf_proxy)

        # Normalize metrics (0.0 to 1.0 scale)
        norm_energy = self._min_max_normalize(raw_energy)
        norm_carbon = self._min_max_normalize(raw_carbon)
        norm_thermal = self._min_max_normalize(raw_thermal)
        norm_risk = self._min_max_normalize(raw_risk)
        norm_perf = self._min_max_normalize(raw_perf)

        scored_records: List[ScoredPodRecord] = []

        # Use user weights if customized, otherwise priority-adaptive defaults
        is_customized = self.weights != self.DEFAULT_WEIGHTS
        if is_customized:
            w_e = self.weights["energy"]
            w_c = self.weights["carbon"]
            w_t = self.weights["thermal_footprint"]
            w_r = self.weights["environmental_risk"]
            w_p = self.weights["performance_penalty"]
        else:
            is_high = str(workload.get("priority", "")).upper() in ["HIGH", "CRITICAL"]
            is_low = str(workload.get("priority", "")).upper() == "LOW"
            if is_high:
                w_p, w_e, w_c, w_t, w_r = 0.35, 0.15, 0.15, 0.18, 0.17
            elif is_low:
                w_p, w_e, w_c, w_t, w_r = 0.05, 0.20, 0.35, 0.20, 0.20
            else:
                w_p, w_e, w_c, w_t, w_r = 0.20, 0.20, 0.20, 0.20, 0.20

        for i, pid in enumerate(feasible_pod_ids):
            prow = pod_id_to_row.get(pid, {})
            pname = str(prow.get("pod_name", pid))
            loc = str(prow.get("location", "Ocean Pod"))

            c_e = w_e * norm_energy[i]
            c_c = w_c * norm_carbon[i]
            c_t = w_t * norm_thermal[i]
            c_r = w_r * norm_risk[i]
            c_p = w_p * norm_perf[i]

            composite_score = c_e + c_c + c_t + c_r + c_p

            rec = ScoredPodRecord(
                pod_id=pid,
                pod_name=pname,
                location=loc,
                rank=0,
                composite_score=round(composite_score, 4),
                raw_metrics={
                    "energy_kwh": round(raw_energy[i], 2),
                    "carbon_kg_co2e": round(raw_carbon[i], 2),
                    "thermal_footprint": round(raw_thermal[i], 3),
                    "environmental_risk": round(raw_risk[i], 3),
                    "performance_penalty": round(raw_perf[i], 2)
                },
                normalized_metrics={
                    "norm_energy": round(norm_energy[i], 4),
                    "norm_carbon": round(norm_carbon[i], 4),
                    "norm_thermal": round(norm_thermal[i], 4),
                    "norm_risk": round(norm_risk[i], 4),
                    "norm_perf": round(norm_perf[i], 4)
                },
                weighted_contributions={
                    "energy_contrib": round(c_e, 4),
                    "carbon_contrib": round(c_c, 4),
                    "thermal_contrib": round(c_t, 4),
                    "risk_contrib": round(c_r, 4),
                    "perf_contrib": round(c_p, 4)
                },
                decision_notes=""
            )
            scored_records.append(rec)

        # Rank pods by lowest composite score (lower is better)
        scored_records.sort(key=lambda x: x.composite_score)
        for idx, rec in enumerate(scored_records, 1):
            rec.rank = idx

        # Generate transparent explanation for top pod and others
        best = scored_records[0]
        ec_best = energy_carbon_map[best.pod_id]
        tr_best = thermal_risk_map[best.pod_id]

        best.decision_notes = (
            f"RECOMMENDED BEST POD (Rank 1, Score: {best.composite_score:.4f}). "
            f"Delivers optimal balance with {ec_best.workload_carbon_kg_co2e:.2f} kg CO2e carbon, "
            f"ocean ΔT of {tr_best.delta_temp_c:.2f}°C, and environmental risk {tr_best.environmental_risk_score:.3f}."
        )

        for rec in scored_records[1:]:
            delta_score = rec.composite_score - best.composite_score
            rec.decision_notes = (
                f"Rank {rec.rank} (Score: {rec.composite_score:.4f}, +{delta_score:.4f} higher than best). "
                f"Exhibits higher impact in key objectives compared to {best.pod_name}."
            )

        explanation = (
            f"Selected {best.pod_name} ({best.pod_id}) in {best.location} as optimal pod. "
            f"Composite Score: {best.composite_score:.4f} (Rank 1 of {len(scored_records)} feasible pods). "
            f"Filtered out {len(ineligible_pods)} pods due to resource shortages or environmental thresholds."
        )

        return SchedulingDecision(
            selected_pod=best,
            ranked_pods=scored_records,
            ineligible_pods=ineligible_pods,
            weights_applied=self.weights,
            explanation_summary=explanation,
            status="SUCCESS"
        )
