"""
Unit tests for DataValidator (FR-02, FR-03)
"""

import pytest
import pandas as pd
from datetime import datetime, timezone, timedelta
from src.data_validation import DataValidator


def test_workload_validation_success():
    validator = DataValidator()
    df = pd.DataFrame([{
        "workload_id": "WL-TEST",
        "workload_type": "AI Test",
        "cpu_cores": 16,
        "gpu_units": 4,
        "ram_gb": 64,
        "duration_hours": 2.5
    }])
    clean_df, report = validator.validate_workload_df(df)
    assert report.is_valid is True
    assert len(report.errors) == 0
    assert len(clean_df) == 1


def test_workload_validation_detects_negative_and_missing():
    validator = DataValidator()
    df = pd.DataFrame([{
        "workload_id": "WL-BAD",
        "workload_type": "AI Test",
        "cpu_cores": -8,
        "gpu_units": 2,
        "ram_gb": 32,
        "duration_hours": 1.0
    }])
    clean_df, report = validator.validate_workload_df(df)
    assert report.is_valid is False
    assert any("negative" in err.lower() for err in report.errors)


def test_pod_resources_detects_used_greater_than_total():
    validator = DataValidator()
    df = pd.DataFrame([{
        "pod_id": "POD-OVERFLOW",
        "total_cpu": 32,
        "used_cpu": 64,  # Used > Total! Physical impossibility
        "total_gpu": 8,
        "used_gpu": 2,
        "total_ram_gb": 128,
        "used_ram_gb": 64,
        "status": "ACTIVE",
        "base_power_kw": 20.0
    }])
    clean_df, report = validator.validate_pod_resources_df(df)
    assert report.is_valid is False
    assert any("used_cpu > total_cpu" in err.lower() or "impossibility" in err.lower() for err in report.errors)


def test_ocean_conditions_detects_stale_data():
    now = datetime.now(timezone.utc)
    stale_time = (now - timedelta(hours=48)).isoformat()
    validator = DataValidator(max_stale_hours=24.0, reference_time=now)
    df = pd.DataFrame([{
        "pod_id": "POD-STALE",
        "timestamp": stale_time,
        "water_temperature_c": 12.0,
        "current_speed_mps": 0.8,
        "salinity_psu": 35.0,
        "depth_m": 60.0,
        "grid_carbon_intensity_kg_per_kwh": 0.15
    }])
    clean_df, report = validator.validate_ocean_conditions_df(df)
    assert any("stale" in w.lower() for w in report.warnings)


def test_ocean_conditions_detects_physical_temp_bounds():
    validator = DataValidator()
    df = pd.DataFrame([{
        "pod_id": "POD-VOLCANO",
        "timestamp": "2026-10-15T00:00:00Z",
        "water_temperature_c": 95.0,  # Impossible ocean water temp
        "current_speed_mps": 1.0,
        "salinity_psu": 35.0,
        "depth_m": 50.0,
        "grid_carbon_intensity_kg_per_kwh": 0.20
    }])
    clean_df, report = validator.validate_ocean_conditions_df(df)
    assert report.is_valid is False
    assert any("physical bounds" in err.lower() for err in report.errors)
