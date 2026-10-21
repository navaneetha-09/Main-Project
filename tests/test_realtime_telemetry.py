import pytest
import os
import pandas as pd
from datetime import datetime, timezone
from src.realtime_telemetry import RealtimeOceanTelemetryService
from src.data_validation import DataValidator


def test_utc_timestamp_format():
    ts = RealtimeOceanTelemetryService.get_current_utc_timestamp()
    assert ts.endswith("Z")
    dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
    assert dt.tzinfo is not None


def test_realtime_snapshot_physics():
    service = RealtimeOceanTelemetryService()
    ocean_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "ocean_conditions.csv")
    df = pd.read_csv(ocean_path)
    
    snapshot_df = service.generate_realtime_snapshot(df, current_multiplier=1.2, temp_shift_c=0.5)
    
    assert len(snapshot_df) == len(df)
    assert not snapshot_df.empty
    # Validate physical ranges
    assert (snapshot_df["water_temperature_c"] >= -2.0).all()
    assert (snapshot_df["water_temperature_c"] <= 35.0).all()
    assert (snapshot_df["current_speed_mps"] >= 0.05).all()
    assert (snapshot_df["grid_carbon_intensity_kg_per_kwh"] > 0).all()


def test_snapshot_validates_cleanly():
    service = RealtimeOceanTelemetryService()
    ocean_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "ocean_conditions.csv")
    df = pd.read_csv(ocean_path)
    
    snapshot_df = service.generate_realtime_snapshot(df)
    validator = DataValidator(max_stale_hours=24.0)
    clean_df, report = validator.validate_ocean_conditions_df(snapshot_df)
    
    assert report.is_valid
    assert len(report.errors) == 0
    assert len(clean_df) == len(df)
