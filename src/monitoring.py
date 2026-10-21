"""
AquaEcoSched: Workload Execution & Monitoring Module (Steps 11 & 12, Slide 7)
Simulates lifecycle execution of scheduled workloads on underwater computing pods.
Tracks resource allocation, dynamic release, and simulated pod telemetry updates.
"""

from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Dict, List, Optional, Any
import time
import pandas as pd


@dataclass
class WorkloadExecutionTask:
    task_id: str
    workload_id: str
    workload_type: str
    assigned_pod_id: str
    assigned_pod_name: str
    status: str  # "QUEUED", "RUNNING", "COMPLETED", "FAILED"
    progress_pct: float
    start_time: str
    completion_time: Optional[str]
    cpu_allocated: float
    gpu_allocated: float
    ram_allocated: float
    runtime_hours_simulated: float
    energy_consumed_kwh: float
    carbon_emitted_kg: float
    logs: List[str] = field(default_factory=list)


class PodExecutionMonitor:
    """
    Manages and tracks active and completed workloads across underwater pods.
    Simulates allocation, progress, and resource deallocation.
    """

    def __init__(self):
        self.active_tasks: Dict[str, WorkloadExecutionTask] = {}
        self.task_history: List[WorkloadExecutionTask] = []
        self._counter = 1

    def spawn_simulation_task(
        self,
        workload: Dict[str, Any],
        selected_pod_row: pd.Series,
        energy_kwh: float,
        carbon_kg: float
    ) -> WorkloadExecutionTask:
        """
        Creates and registers a simulated execution run for a selected pod.
        """
        task_id = f"TASK-EXEC-{self._counter:04d}"
        self._counter += 1

        now_str = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
        pod_id = str(selected_pod_row.get("pod_id", "POD-SIM"))
        pod_name = str(selected_pod_row.get("pod_name", pod_id))

        task = WorkloadExecutionTask(
            task_id=task_id,
            workload_id=str(workload.get("workload_id", "WL-SIM")),
            workload_type=str(workload.get("workload_type", "General Compute")),
            assigned_pod_id=pod_id,
            assigned_pod_name=pod_name,
            status="RUNNING",
            progress_pct=0.0,
            start_time=now_str,
            completion_time=None,
            cpu_allocated=float(workload.get("cpu_cores", 0)),
            gpu_allocated=float(workload.get("gpu_units", 0)),
            ram_allocated=float(workload.get("ram_gb", 0)),
            runtime_hours_simulated=float(workload.get("duration_hours", 1.0)),
            energy_consumed_kwh=round(energy_kwh, 4),
            carbon_emitted_kg=round(carbon_kg, 4),
            logs=[
                f"[{now_str}] Task {task_id} initialized for workload {workload.get('workload_id')}.",
                f"[{now_str}] Pod hardware allocated: {workload.get('cpu_cores')} CPU cores, {workload.get('gpu_units')} GPUs, {workload.get('ram_gb')} GB RAM on {pod_name}.",
                f"[{now_str}] Subsea telemetry verified: Ambient ocean cooling active."
            ]
        )

        self.active_tasks[task_id] = task
        self.task_history.append(task)
        return task

    def advance_progress(self, task_id: str, delta_pct: float = 25.0) -> Optional[WorkloadExecutionTask]:
        """Advance simulated task progress towards 100%."""
        task = self.active_tasks.get(task_id)
        if not task:
            return None

        task.progress_pct = min(100.0, task.progress_pct + delta_pct)
        now_str = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

        if task.progress_pct >= 100.0:
            task.status = "COMPLETED"
            task.completion_time = now_str
            task.logs.append(f"[{now_str}] Workload completed successfully on {task.assigned_pod_name}.")
            task.logs.append(f"[{now_str}] Pod resources deallocated and returned to available pool.")
        else:
            task.logs.append(f"[{now_str}] Execution checkpoint: {task.progress_pct:.0f}% completed.")

        return task

    def allocate_resources_to_pod_df(
        self,
        pod_df: pd.DataFrame,
        workload: Dict[str, Any],
        target_pod_id: str
    ) -> pd.DataFrame:
        """Update pod DataFrame used resources when a workload is scheduled."""
        updated_df = pod_df.copy()
        mask = updated_df["pod_id"] == target_pod_id
        if mask.any():
            updated_df.loc[mask, "used_cpu"] += float(workload.get("cpu_cores", 0))
            updated_df.loc[mask, "used_gpu"] += float(workload.get("gpu_units", 0))
            updated_df.loc[mask, "used_ram_gb"] += float(workload.get("ram_gb", 0))
        return updated_df
