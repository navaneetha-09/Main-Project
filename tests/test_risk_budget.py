"""
Unit tests for RiskBudgetEnforcer (FR-06, Step 7)
Tests: Risk budget pass / fail, temperature threshold rejection, sanctuary rule
"""

import pytest
import pandas as pd
from src.energy_carbon import EnergyCarbonEstimate
from src.thermal_risk import ThermalRiskEstimate
from src.risk_budget import RiskBudgetEnforcer


def test_risk_budget_passes_compliant_pod():
    enforcer = RiskBudgetEnforcer(max_water_temp_delta_c=2.5, max_environmental_risk_score=0.65)
    ec_map = {
        "POD-GOOD": EnergyCarbonEstimate(
            pod_id="POD-GOOD", workload_power_kw=10, total_pod_power_kw=30, pue=1.06,
            runtime_hours=2, workload_energy_kwh=20, total_facility_energy_kwh=60,
            carbon_intensity_kg_per_kwh=0.05, workload_carbon_kg_co2e=1.0, total_pod_carbon_kg_co2e=3.0
        )
    }
    tr_map = {
        "POD-GOOD": ThermalRiskEstimate(
            pod_id="POD-GOOD", heat_dissipated_kw=30, convective_h_w_m2k=800,
            delta_temp_c=0.8, local_water_temp_c=9.2, estimated_pod_internal_temp_c=25.2,
            thermal_footprint_score=0.15, ecological_sensitivity_weight=0.5,
            environmental_risk_score=0.25
        )
    }
    ocean_df = pd.DataFrame([{"pod_id": "POD-GOOD", "ecological_zone": "MODERATE"}])

    out = enforcer.evaluate_constraints(ec_map, tr_map, ocean_df)
    assert "POD-GOOD" in out.passed_pod_ids
    assert out.checks["POD-GOOD"].passed_all_constraints is True


def test_risk_budget_rejects_excessive_temperature_rise():
    enforcer = RiskBudgetEnforcer(max_water_temp_delta_c=1.5)
    ec_map = {
        "POD-HOT": EnergyCarbonEstimate(
            pod_id="POD-HOT", workload_power_kw=25, total_pod_power_kw=90, pue=1.1,
            runtime_hours=2, workload_energy_kwh=50, total_facility_energy_kwh=180,
            carbon_intensity_kg_per_kwh=0.2, workload_carbon_kg_co2e=10.0, total_pod_carbon_kg_co2e=36.0
        )
    }
    tr_map = {
        "POD-HOT": ThermalRiskEstimate(
            pod_id="POD-HOT", heat_dissipated_kw=90, convective_h_w_m2k=400,
            delta_temp_c=3.2,  # Exceeds 1.5 C limit!
            local_water_temp_c=20.2, estimated_pod_internal_temp_c=36.2,
            thermal_footprint_score=0.75, ecological_sensitivity_weight=0.5,
            environmental_risk_score=0.55
        )
    }
    out = enforcer.evaluate_constraints(ec_map, tr_map, None)
    assert "POD-HOT" not in out.passed_pod_ids
    assert out.checks["POD-HOT"].passed_all_constraints is False
    assert any("Water temperature rise" in r for r in out.checks["POD-HOT"].rejection_reasons)


def test_risk_budget_rejects_protected_coral_reef():
    enforcer = RiskBudgetEnforcer(disallow_protected_zones=True)
    ec_map = {
        "POD-REEF": EnergyCarbonEstimate(
            pod_id="POD-REEF", workload_power_kw=10, total_pod_power_kw=30, pue=1.06,
            runtime_hours=2, workload_energy_kwh=20, total_facility_energy_kwh=60,
            carbon_intensity_kg_per_kwh=0.05, workload_carbon_kg_co2e=1.0, total_pod_carbon_kg_co2e=3.0
        )
    }
    tr_map = {
        "POD-REEF": ThermalRiskEstimate(
            pod_id="POD-REEF", heat_dissipated_kw=30, convective_h_w_m2k=800,
            delta_temp_c=0.5, local_water_temp_c=24.5, estimated_pod_internal_temp_c=40.5,
            thermal_footprint_score=0.20, ecological_sensitivity_weight=1.0,
            environmental_risk_score=0.45
        )
    }
    ocean_df = pd.DataFrame([{"pod_id": "POD-REEF", "ecological_zone": "PROTECTED_CORAL_REEF"}])

    out = enforcer.evaluate_constraints(ec_map, tr_map, ocean_df)
    assert "POD-REEF" not in out.passed_pod_ids
    assert any("protected marine ecosystem" in r for r in out.checks["POD-REEF"].rejection_reasons)
