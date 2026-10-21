"""
Unit tests for EnergyCarbonEstimator (FR-05)
Formula verification: Energy (kWh) = Power (kW) * Time (h); Carbon = Energy * Carbon Intensity
"""

import pytest
import pandas as pd
from src.energy_carbon import EnergyCarbonEstimator


def test_energy_and_carbon_formula():
    estimator = EnergyCarbonEstimator()
    pod_row = pd.Series({
        "pod_id": "POD-ECO",
        "base_power_kw": 20.0,
        "max_power_kw": 80.0,
        "pue": 1.10,
        "total_cpu": 64,
        "total_gpu": 8,
        "total_ram_gb": 256
    })
    ocean_row = pd.Series({
        "grid_carbon_intensity_kg_per_kwh": 0.05  # Clean wind/tidal
    })
    workload = {
        "cpu_cores": 32,
        "gpu_units": 4,
        "ram_gb": 128,
        "duration_hours": 4.0
    }

    result = estimator.compute_energy_and_carbon(pod_row, ocean_row, workload)

    assert result.runtime_hours == 4.0
    assert result.workload_energy_kwh > 0
    # Energy = Power * Time
    assert abs(result.workload_energy_kwh - (result.workload_power_kw * 4.0)) < 1e-3
    # Carbon = Energy * Carbon Intensity
    assert abs(result.workload_carbon_kg_co2e - (result.workload_energy_kwh * 0.05)) < 1e-3
    assert result.carbon_intensity_kg_per_kwh == 0.05
