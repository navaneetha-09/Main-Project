"""
End-to-End Integration Tests for AquaEcoSched
Validates full 12-step workflow from dataset loading to monitoring & reporting.
"""

import pytest
import os
import pandas as pd
from src.data_validation import DataValidator
from src.resource_filter import ResourceFilter
from src.energy_carbon import EnergyCarbonEstimator
from src.thermal_risk import ThermalRiskEstimator
from src.risk_budget import RiskBudgetEnforcer
from src.scheduler import AquaEcoScheduler
from src.reporting import BaselineComparator, SchedulingReporter
from src.monitoring import PodExecutionMonitor


def test_full_pipeline_with_sample_data():
    base_dir = os.path.dirname(os.path.dirname(__file__))
    workload_path = os.path.join(base_dir, "data", "workload_profiles.csv")
    pod_path = os.path.join(base_dir, "data", "pod_resources.csv")
    ocean_path = os.path.join(base_dir, "data", "ocean_conditions.csv")

    assert os.path.exists(workload_path)
    assert os.path.exists(pod_path)
    assert os.path.exists(ocean_path)

    # 1 & 2: Load datasets
    wl_df = pd.read_csv(workload_path)
    pod_df = pd.read_csv(pod_path)
    ocean_df = pd.read_csv(ocean_path)

    # 3: Validate
    validator = DataValidator()
    clean_wl, rep_wl = validator.validate_workload_df(wl_df)
    clean_pod, rep_pod = validator.validate_pod_resources_df(pod_df)
    clean_ocean, rep_ocean = validator.validate_ocean_conditions_df(ocean_df)

    assert rep_wl.is_valid
    assert rep_pod.is_valid
    assert rep_ocean.is_valid

    # Select first workload
    workload = clean_wl.iloc[0].to_dict()

    # 4: Resource filter
    res_filter = ResourceFilter()
    res_out = res_filter.filter_pods(clean_pod, workload)
    assert len(res_out.eligible_pods_df) > 0

    # 5 & 6: Impact estimation
    ec_estimator = EnergyCarbonEstimator()
    tr_estimator = ThermalRiskEstimator()

    ec_map = {}
    tr_map = {}
    ocean_map = {str(r["pod_id"]): r for _, r in clean_ocean.iterrows()}

    for _, prow in clean_pod.iterrows():
        pid = str(prow["pod_id"])
        orow = ocean_map.get(pid)
        ec = ec_estimator.compute_energy_and_carbon(prow, orow, workload)
        power_kw = ec.total_pod_power_kw
        tr = tr_estimator.estimate_thermal_and_risk(prow, orow, power_kw)
        ec_map[pid] = ec
        tr_map[pid] = tr

    # 7: Risk budget
    risk_enforcer = RiskBudgetEnforcer(
        max_water_temp_delta_c=2.5,
        max_environmental_risk_score=0.65,
        disallow_protected_zones=True
    )
    budget_out = risk_enforcer.evaluate_constraints(ec_map, tr_map, clean_ocean)
    assert len(budget_out.passed_pod_ids) > 0

    # Intersect hardware eligible & environmental compliant pods
    hardware_eligible_pids = set(res_out.eligible_pods_df["pod_id"].tolist())
    feasible_pids = [pid for pid in budget_out.passed_pod_ids if pid in hardware_eligible_pids]
    assert len(feasible_pids) > 0

    # 8-10: Multi-Objective Scheduler
    scheduler = AquaEcoScheduler()
    decision = scheduler.schedule(
        feasible_pod_ids=feasible_pids,
        pod_df=clean_pod,
        energy_carbon_map=ec_map,
        thermal_risk_map=tr_map,
        resource_checks=res_out.all_pod_checks,
        risk_checks=budget_out.checks,
        workload=workload
    )

    assert decision.status == "SUCCESS"
    assert decision.selected_pod is not None
    assert decision.selected_pod.rank == 1

    # 11: Simulated Execution
    monitor = PodExecutionMonitor()
    selected_row = clean_pod.loc[clean_pod["pod_id"] == decision.selected_pod.pod_id].iloc[0]
    task = monitor.spawn_simulation_task(
        workload,
        selected_row,
        decision.selected_pod.raw_metrics["energy_kwh"],
        decision.selected_pod.raw_metrics["carbon_kg_co2e"]
    )
    assert task.status == "RUNNING"
    task = monitor.advance_progress(task.task_id, 100.0)
    assert task.status == "COMPLETED"

    # 12: Baseline comparison & Reporting
    comparator = BaselineComparator()
    comparison = comparator.evaluate_workload(
        workload, clean_pod, clean_ocean, scheduler, risk_enforcer
    )
    assert "AquaEcoSched" in comparison
    assert "FirstFit" in comparison
    assert "ResourceOnly" in comparison

    # Export generation
    json_report = SchedulingReporter.generate_json_report(decision, workload, {})
    assert len(json_report) > 50
    ranking_df = SchedulingReporter.generate_ranking_dataframe(decision)
    assert len(ranking_df) == len(decision.ranked_pods)
