"""
AquaEcoSched: Resource Filter Module (FR-04)
Calculates available resource capacity and enforces hard hardware constraints.
Rejects pods that cannot satisfy the workload's CPU, GPU, RAM, or operational status.
"""

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple, Any
import pandas as pd


@dataclass
class PodResourceCheckResult:
    pod_id: str
    is_eligible: bool
    available_cpu: float
    available_gpu: float
    available_ram_gb: float
    available_storage_gb: float = 0.0
    rejection_reasons: List[str] = field(default_factory=list)
    resource_utilization_after: Dict[str, float] = field(default_factory=dict)


@dataclass
class ResourceFilterOutput:
    eligible_pods_df: pd.DataFrame
    all_pod_checks: Dict[str, PodResourceCheckResult]
    summary: Dict[str, Any]


class ResourceFilter:
    """
    Enforces Step 4 of the AquaEcoSched workflow:
    Available resource = Total - Used
    Rejects pods with insufficient capacity or non-active status.
    """

    ALLOWED_STATUSES = {"ACTIVE", "ONLINE"}

    def __init__(self, allow_degraded: bool = False):
        self.allow_degraded = allow_degraded
        if allow_degraded:
            self.allowed_statuses = {"ACTIVE", "ONLINE", "DEGRADED"}
        else:
            self.allowed_statuses = self.ALLOWED_STATUSES

    def filter_pods(
        self,
        pod_df: pd.DataFrame,
        workload: Dict[str, Any]
    ) -> ResourceFilterOutput:
        """
        Evaluate pod hardware feasibility against workload demands.

        Parameters:
            pod_df: DataFrame of validated pod resources
            workload: Dict containing cpu_cores, gpu_units, ram_gb, storage_gb
        """
        req_cpu = float(workload.get("cpu_cores", 0))
        req_gpu = float(workload.get("gpu_units", 0))
        req_ram = float(workload.get("ram_gb", 0))
        req_storage = float(workload.get("storage_gb", 0))

        checks: Dict[str, PodResourceCheckResult] = {}
        eligible_rows = []

        df = pod_df.copy()

        # Calculate available capacity: Available = Total - Used
        df["avail_cpu"] = df["total_cpu"] - df["used_cpu"]
        df["avail_gpu"] = df["total_gpu"] - df["used_gpu"]
        df["avail_ram_gb"] = df["total_ram_gb"] - df["used_ram_gb"]
        if "total_storage_gb" in df.columns and "used_storage_gb" in df.columns:
            df["avail_storage_gb"] = df["total_storage_gb"] - df["used_storage_gb"]
        else:
            df["avail_storage_gb"] = 2000.0  # Safe default if column not yet added

        for _, row in df.iterrows():
            pod_id = str(row["pod_id"])
            status = str(row["status"]).upper().strip()
            avail_cpu = float(row["avail_cpu"])
            avail_gpu = float(row["avail_gpu"])
            avail_ram = float(row["avail_ram_gb"])
            avail_storage = float(row["avail_storage_gb"])

            rejection_reasons = []

            # 1. Status Check
            if status not in self.allowed_statuses:
                rejection_reasons.append(f"Pod operational status is '{status}' (requires ACTIVE/ONLINE)")

            # 2. CPU Capacity Check
            if avail_cpu < req_cpu:
                rejection_reasons.append(
                    f"Insufficient CPU: requires {req_cpu:g} cores, only {avail_cpu:g} available (Total: {row['total_cpu']}, Used: {row['used_cpu']})"
                )

            # 3. GPU Capacity Check
            if avail_gpu < req_gpu:
                rejection_reasons.append(
                    f"Insufficient GPU: requires {req_gpu:g} units, only {avail_gpu:g} available (Total: {row['total_gpu']}, Used: {row['used_gpu']})"
                )

            # 4. RAM Capacity Check
            if avail_ram < req_ram:
                rejection_reasons.append(
                    f"Insufficient RAM: requires {req_ram:g} GB, only {avail_ram:g} GB available (Total: {row['total_ram_gb']}, Used: {row['used_ram_gb']})"
                )

            # 5. Storage Capacity Check
            if req_storage > 0 and avail_storage < req_storage:
                tot_st = row.get('total_storage_gb', avail_storage)
                used_st = row.get('used_storage_gb', 0)
                rejection_reasons.append(
                    f"Insufficient Storage: requires {req_storage:g} GB, only {avail_storage:g} GB available (Total: {tot_st}, Used: {used_st})"
                )

            is_eligible = len(rejection_reasons) == 0

            # Calculate prospective utilization if scheduled
            tot_cpu = max(float(row["total_cpu"]), 1.0)
            tot_gpu = max(float(row["total_gpu"]), 1.0)
            tot_ram = max(float(row["total_ram_gb"]), 1.0)

            new_used_cpu = float(row["used_cpu"]) + (req_cpu if is_eligible else 0)
            new_used_gpu = float(row["used_gpu"]) + (req_gpu if is_eligible else 0)
            new_used_ram = float(row["used_ram_gb"]) + (req_ram if is_eligible else 0)

            utilization = {
                "cpu_util_after": round(new_used_cpu / tot_cpu, 4),
                "gpu_util_after": round(new_used_gpu / tot_gpu, 4),
                "ram_util_after": round(new_used_ram / tot_ram, 4),
            }

            check_res = PodResourceCheckResult(
                pod_id=pod_id,
                is_eligible=is_eligible,
                available_cpu=avail_cpu,
                available_gpu=avail_gpu,
                available_ram_gb=avail_ram,
                available_storage_gb=avail_storage,
                rejection_reasons=rejection_reasons,
                resource_utilization_after=utilization
            )
            checks[pod_id] = check_res

            if is_eligible:
                row_dict = row.to_dict()
                row_dict["cpu_util_after"] = utilization["cpu_util_after"]
                row_dict["gpu_util_after"] = utilization["gpu_util_after"]
                row_dict["ram_util_after"] = utilization["ram_util_after"]
                eligible_rows.append(row_dict)

        eligible_df = pd.DataFrame(eligible_rows) if eligible_rows else pd.DataFrame(columns=df.columns)

        summary = {
            "total_pods_evaluated": len(df),
            "eligible_pods_count": len(eligible_df),
            "rejected_pods_count": len(df) - len(eligible_df),
            "workload_demands": {
                "cpu_cores": req_cpu,
                "gpu_units": req_gpu,
                "ram_gb": req_ram
            }
        }

        return ResourceFilterOutput(
            eligible_pods_df=eligible_df,
            all_pod_checks=checks,
            summary=summary
        )
