"""
Unit tests for ResourceFilter (FR-04)
Tests: Enough resources / insufficient resources / pod status rejection
"""

import pytest
import pandas as pd
from src.resource_filter import ResourceFilter


def test_resource_filter_passes_capable_pod():
    filter_engine = ResourceFilter()
    pod_df = pd.DataFrame([{
        "pod_id": "POD-CAPABLE",
        "total_cpu": 64,
        "used_cpu": 16,
        "total_gpu": 8,
        "used_gpu": 2,
        "total_ram_gb": 256,
        "used_ram_gb": 64,
        "status": "ACTIVE"
    }])
    workload = {"cpu_cores": 16, "gpu_units": 4, "ram_gb": 64}

    result = filter_engine.filter_pods(pod_df, workload)
    assert len(result.eligible_pods_df) == 1
    assert result.all_pod_checks["POD-CAPABLE"].is_eligible is True


def test_resource_filter_rejects_insufficient_cpu():
    filter_engine = ResourceFilter()
    pod_df = pd.DataFrame([{
        "pod_id": "POD-TIGHT-CPU",
        "total_cpu": 32,
        "used_cpu": 28,  # Only 4 available
        "total_gpu": 8,
        "used_gpu": 0,
        "total_ram_gb": 128,
        "used_ram_gb": 16,
        "status": "ACTIVE"
    }])
    workload = {"cpu_cores": 16, "gpu_units": 2, "ram_gb": 32}

    result = filter_engine.filter_pods(pod_df, workload)
    assert len(result.eligible_pods_df) == 0
    check = result.all_pod_checks["POD-TIGHT-CPU"]
    assert check.is_eligible is False
    assert any("Insufficient CPU" in r for r in check.rejection_reasons)


def test_resource_filter_rejects_maintenance_pod():
    filter_engine = ResourceFilter()
    pod_df = pd.DataFrame([{
        "pod_id": "POD-MAINT",
        "total_cpu": 128,
        "used_cpu": 0,
        "total_gpu": 16,
        "used_gpu": 0,
        "total_ram_gb": 512,
        "used_ram_gb": 0,
        "status": "MAINTENANCE"
    }])
    workload = {"cpu_cores": 8, "gpu_units": 1, "ram_gb": 16}

    result = filter_engine.filter_pods(pod_df, workload)
    assert len(result.eligible_pods_df) == 0
    check = result.all_pod_checks["POD-MAINT"]
    assert check.is_eligible is False
    assert any("MAINTENANCE" in r for r in check.rejection_reasons)
