"""
Unit tests for AquaEcoScheduler (FR-07, Slide 6, 10)
Tests:
  - Normalization with single pod / identical metrics
  - No feasible pod scenario
  - Multi-objective ranking and score minimization
"""

import pytest
import pandas as pd
from src.scheduler import AquaEcoScheduler
from src.energy_carbon import EnergyCarbonEstimate
from src.thermal_risk import ThermalRiskEstimate
from src.resource_filter import PodResourceCheckResult
from src.risk_budget import RiskBudgetCheckResult


def test_scheduler_no_feasible_pods():
    scheduler = AquaEcoScheduler()
    pod_df = pd.DataFrame([{"pod_id": "POD-1", "pod_name": "P1", "location": "L1", "network_latency_ms": 10}])
    res_checks = {"POD-1": PodResourceCheckResult(pod_id="POD-1", is_eligible=False, available_cpu=0, available_gpu=0, available_ram_gb=0, rejection_reasons=["No CPU"])}
    risk_checks = {}

    decision = scheduler.schedule(
        feasible_pod_ids=[],
        pod_df=pod_df,
        energy_carbon_map={},
        thermal_risk_map={},
        resource_checks=res_checks,
        risk_checks=risk_checks,
        workload={"cpu_cores": 16}
    )

    assert decision.status == "INFEASIBLE_NO_PODS"
    assert decision.selected_pod is None
    assert "Scheduling Infeasible" in decision.explanation_summary


def test_scheduler_single_feasible_pod_normalization():
    scheduler = AquaEcoScheduler()
    pod_df = pd.DataFrame([{"pod_id": "POD-ONLY", "pod_name": "Only Pod", "location": "North Sea", "network_latency_ms": 12.0}])
    ec_map = {
        "POD-ONLY": EnergyCarbonEstimate(
            pod_id="POD-ONLY", workload_power_kw=15, total_pod_power_kw=40, pue=1.06,
            runtime_hours=2, workload_energy_kwh=30, total_facility_energy_kwh=80,
            carbon_intensity_kg_per_kwh=0.08, workload_carbon_kg_co2e=2.4, total_pod_carbon_kg_co2e=6.4
        )
    }
    tr_map = {
        "POD-ONLY": ThermalRiskEstimate(
            pod_id="POD-ONLY", heat_dissipated_kw=40, convective_h_w_m2k=700,
            delta_temp_c=1.1, local_water_temp_c=9.5, estimated_pod_internal_temp_c=25.5,
            thermal_footprint_score=0.2, ecological_sensitivity_weight=0.5,
            environmental_risk_score=0.3
        )
    }
    res_checks = {
        "POD-ONLY": PodResourceCheckResult(
            pod_id="POD-ONLY", is_eligible=True, available_cpu=32, available_gpu=4, available_ram_gb=128,
            resource_utilization_after={"cpu_util_after": 0.4}
        )
    }
    risk_checks = {
        "POD-ONLY": RiskBudgetCheckResult(pod_id="POD-ONLY", passed_all_constraints=True)
    }

    decision = scheduler.schedule(
        feasible_pod_ids=["POD-ONLY"],
        pod_df=pod_df,
        energy_carbon_map=ec_map,
        thermal_risk_map=tr_map,
        resource_checks=res_checks,
        risk_checks=risk_checks,
        workload={"cpu_cores": 16, "gpu_units": 2, "ram_gb": 64, "duration_hours": 2}
    )

    assert decision.status == "SUCCESS"
    assert decision.selected_pod is not None
    assert decision.selected_pod.pod_id == "POD-ONLY"
    assert decision.selected_pod.rank == 1


def test_scheduler_ranks_cleaner_pod_higher():
    scheduler = AquaEcoScheduler()
    pod_df = pd.DataFrame([
        {"pod_id": "POD-CLEAN", "pod_name": "Clean Pod", "location": "Orkney", "network_latency_ms": 10.0},
        {"pod_id": "POD-DIRTY", "pod_name": "Dirty Pod", "location": "Coal Coast", "network_latency_ms": 10.0}
    ])
    # Clean pod has much lower carbon and lower risk
    ec_map = {
        "POD-CLEAN": EnergyCarbonEstimate(
            pod_id="POD-CLEAN", workload_power_kw=10, total_pod_power_kw=30, pue=1.05,
            runtime_hours=2, workload_energy_kwh=20, total_facility_energy_kwh=60,
            carbon_intensity_kg_per_kwh=0.02, workload_carbon_kg_co2e=0.4, total_pod_carbon_kg_co2e=1.2
        ),
        "POD-DIRTY": EnergyCarbonEstimate(
            pod_id="POD-DIRTY", workload_power_kw=10, total_pod_power_kw=30, pue=1.05,
            runtime_hours=2, workload_energy_kwh=20, total_facility_energy_kwh=60,
            carbon_intensity_kg_per_kwh=0.50, workload_carbon_kg_co2e=10.0, total_pod_carbon_kg_co2e=30.0
        )
    }
    tr_map = {
        "POD-CLEAN": ThermalRiskEstimate(
            pod_id="POD-CLEAN", heat_dissipated_kw=30, convective_h_w_m2k=800,
            delta_temp_c=0.6, local_water_temp_c=8.0, estimated_pod_internal_temp_c=24.0,
            thermal_footprint_score=0.1, ecological_sensitivity_weight=0.2, environmental_risk_score=0.15
        ),
        "POD-DIRTY": ThermalRiskEstimate(
            pod_id="POD-DIRTY", heat_dissipated_kw=30, convective_h_w_m2k=400,
            delta_temp_c=1.5, local_water_temp_c=18.0, estimated_pod_internal_temp_c=34.0,
            thermal_footprint_score=0.5, ecological_sensitivity_weight=0.8, environmental_risk_score=0.60
        )
    }
    res_checks = {
        "POD-CLEAN": PodResourceCheckResult(pod_id="POD-CLEAN", is_eligible=True, available_cpu=32, available_gpu=4, available_ram_gb=128, resource_utilization_after={"cpu_util_after": 0.4}),
        "POD-DIRTY": PodResourceCheckResult(pod_id="POD-DIRTY", is_eligible=True, available_cpu=32, available_gpu=4, available_ram_gb=128, resource_utilization_after={"cpu_util_after": 0.4})
    }
    risk_checks = {
        "POD-CLEAN": RiskBudgetCheckResult(pod_id="POD-CLEAN", passed_all_constraints=True),
        "POD-DIRTY": RiskBudgetCheckResult(pod_id="POD-DIRTY", passed_all_constraints=True)
    }

    decision = scheduler.schedule(
        feasible_pod_ids=["POD-CLEAN", "POD-DIRTY"],
        pod_df=pod_df,
        energy_carbon_map=ec_map,
        thermal_risk_map=tr_map,
        resource_checks=res_checks,
        risk_checks=risk_checks,
        workload={"cpu_cores": 16, "gpu_units": 2, "ram_gb": 64, "duration_hours": 2}
    )

    assert decision.selected_pod.pod_id == "POD-CLEAN"
    assert decision.selected_pod.rank == 1
    assert decision.ranked_pods[1].pod_id == "POD-DIRTY"
    assert decision.selected_pod.composite_score < decision.ranked_pods[1].composite_score
