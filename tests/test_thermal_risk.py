"""
Unit tests for ThermalRiskEstimator (FR-05)
Validates hydrodynamic convection scaling and ecological risk calculation.
"""

import pytest
import pandas as pd
from src.thermal_risk import ThermalRiskEstimator


def test_convective_heat_transfer_increases_with_current_velocity():
    estimator = ThermalRiskEstimator()
    h_slow = estimator.compute_convective_coefficient(0.1)
    h_fast = estimator.compute_convective_coefficient(1.5)
    # Higher ocean current velocity must yield higher convection coefficient
    assert h_fast > h_slow


def test_delta_temp_decreases_with_fast_current():
    estimator = ThermalRiskEstimator()
    pod = pd.Series({"pod_id": "POD-T1", "surface_area_m2": 120.0})

    ocean_slow = pd.Series({"water_temperature_c": 10.0, "current_speed_mps": 0.1, "depth_m": 50.0, "ecological_zone": "MODERATE"})
    ocean_fast = pd.Series({"water_temperature_c": 10.0, "current_speed_mps": 1.5, "depth_m": 50.0, "ecological_zone": "MODERATE"})

    res_slow = estimator.estimate_thermal_and_risk(pod, ocean_slow, power_estimate_kw=60.0)
    res_fast = estimator.estimate_thermal_and_risk(pod, ocean_fast, power_estimate_kw=60.0)

    # In fast current, heat dissipates quicker, resulting in lower Delta T
    assert res_fast.delta_temp_c < res_slow.delta_temp_c


def test_protected_coral_zone_has_higher_risk():
    estimator = ThermalRiskEstimator()
    pod = pd.Series({"pod_id": "POD-T2", "surface_area_m2": 120.0})

    ocean_coral = pd.Series({"water_temperature_c": 24.0, "current_speed_mps": 0.3, "depth_m": 25.0, "ecological_zone": "PROTECTED_CORAL_REEF"})
    ocean_deep = pd.Series({"water_temperature_c": 4.0, "current_speed_mps": 0.3, "depth_m": 200.0, "ecological_zone": "LOW_IMPACT"})

    res_coral = estimator.estimate_thermal_and_risk(pod, ocean_coral, power_estimate_kw=50.0)
    res_deep = estimator.estimate_thermal_and_risk(pod, ocean_deep, power_estimate_kw=50.0)

    assert res_coral.environmental_risk_score > res_deep.environmental_risk_score
