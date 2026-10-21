"""
AquaEcoSched: Risk-Budget Constraint Enforcement Module (FR-06, Step 7)
Enforces hard environmental thresholds and ecological risk limits
BEFORE weighted score normalization and ranking.
"""

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Any
import pandas as pd

from .energy_carbon import EnergyCarbonEstimate
from .thermal_risk import ThermalRiskEstimate


@dataclass
class RiskBudgetCheckResult:
    pod_id: str
    passed_all_constraints: bool
    rejection_reasons: List[str] = field(default_factory=list)
    constraint_details: Dict[str, Any] = field(default_factory=dict)


@dataclass
class RiskBudgetOutput:
    passed_pod_ids: List[str]
    checks: Dict[str, RiskBudgetCheckResult]
    summary: Dict[str, Any]


class RiskBudgetEnforcer:
    """
    Enforces Step 7 of the AquaEcoSched workflow:
    Checks environmental risk limits and thresholds. Rejects pods that violate
    maximum temperature rise, internal pod temperature, carbon budget, or
    fragile marine sanctuary protection rules.
    """

    def __init__(
        self,
        max_water_temp_delta_c: float = 2.5,
        max_pod_temp_c: float = 45.0,
        max_environmental_risk_score: float = 0.65,
        max_carbon_budget_kg: Optional[float] = None,
        disallow_protected_zones: bool = True
    ):
        self.max_water_temp_delta_c = max_water_temp_delta_c
        self.max_pod_temp_c = max_pod_temp_c
        self.max_environmental_risk_score = max_environmental_risk_score
        self.max_carbon_budget_kg = max_carbon_budget_kg
        self.disallow_protected_zones = disallow_protected_zones

    def evaluate_constraints(
        self,
        energy_carbon_map: Dict[str, EnergyCarbonEstimate],
        thermal_risk_map: Dict[str, ThermalRiskEstimate],
        ocean_df: Optional[pd.DataFrame] = None
    ) -> RiskBudgetOutput:
        """
        Check all pods against configured environmental hard constraints.
        """
        checks: Dict[str, RiskBudgetCheckResult] = {}
        passed_ids: List[str] = []

        # Map ocean zones
        zone_lookup = {}
        if ocean_df is not None and not ocean_df.empty:
            for _, r in ocean_df.iterrows():
                zone_lookup[str(r["pod_id"])] = str(r.get("ecological_zone", "MODERATE")).upper()

        for pod_id, therm in thermal_risk_map.items():
            ec = energy_carbon_map.get(pod_id)
            rejection_reasons = []
            details = {}

            # 1. Seawater Delta T constraint
            details["delta_temp_c"] = therm.delta_temp_c
            details["max_water_temp_delta_c"] = self.max_water_temp_delta_c
            if therm.delta_temp_c > self.max_water_temp_delta_c:
                rejection_reasons.append(
                    f"Water temperature rise ({therm.delta_temp_c:.2f}°C) exceeds limit ({self.max_water_temp_delta_c:.2f}°C)"
                )

            # 2. Pod internal temperature threshold
            details["estimated_pod_temp_c"] = therm.estimated_pod_internal_temp_c
            details["max_pod_temp_c"] = self.max_pod_temp_c
            if therm.estimated_pod_internal_temp_c > self.max_pod_temp_c:
                rejection_reasons.append(
                    f"Pod internal temperature ({therm.estimated_pod_internal_temp_c:.1f}°C) exceeds thermal threshold ({self.max_pod_temp_c:.1f}°C)"
                )

            # 3. Environmental Risk Score limit
            details["environmental_risk_score"] = therm.environmental_risk_score
            details["max_risk_score"] = self.max_environmental_risk_score
            if therm.environmental_risk_score > self.max_environmental_risk_score:
                rejection_reasons.append(
                    f"Environmental risk score ({therm.environmental_risk_score:.3f}) exceeds ecological risk budget ({self.max_environmental_risk_score:.3f})"
                )

            # 4. Carbon budget cap (if enabled)
            if self.max_carbon_budget_kg is not None and ec is not None:
                details["workload_carbon_kg"] = ec.workload_carbon_kg_co2e
                details["max_carbon_budget_kg"] = self.max_carbon_budget_kg
                if ec.workload_carbon_kg_co2e > self.max_carbon_budget_kg:
                    rejection_reasons.append(
                        f"Workload carbon ({ec.workload_carbon_kg_co2e:.2f} kg CO2e) exceeds carbon budget ({self.max_carbon_budget_kg:.2f} kg)"
                    )

            # 5. Protected Marine Ecological Zone
            zone = zone_lookup.get(pod_id, "MODERATE")
            details["ecological_zone"] = zone
            if self.disallow_protected_zones and zone in ["PROTECTED_CORAL_REEF", "SANCTUARY", "MARINE_PROTECTED_AREA"]:
                rejection_reasons.append(
                    f"Disallowed pod in strictly protected marine ecosystem ({zone})"
                )

            passed = len(rejection_reasons) == 0
            if passed:
                passed_ids.append(pod_id)

            checks[pod_id] = RiskBudgetCheckResult(
                pod_id=pod_id,
                passed_all_constraints=passed,
                rejection_reasons=rejection_reasons,
                constraint_details=details
            )

        summary = {
            "total_evaluated": len(thermal_risk_map),
            "passed_count": len(passed_ids),
            "rejected_count": len(thermal_risk_map) - len(passed_ids),
            "rejections": {pid: c.rejection_reasons for pid, c in checks.items() if not c.passed_all_constraints}
        }

        return RiskBudgetOutput(
            passed_pod_ids=passed_ids,
            checks=checks,
            summary=summary
        )
