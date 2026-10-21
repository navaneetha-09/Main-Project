"""
AquaEcoSched: Data Validation Module (FR-02, FR-03)
Validates workload, pod resource, and ocean condition datasets for integrity,
consistency, reasonable physical units, and timestamps.
"""

from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Dict, List, Optional, Tuple, Any
import pandas as pd
import numpy as np


@dataclass
class ValidationReport:
    """Holds data validation findings, errors, and warnings."""
    is_valid: bool = True
    errors: List[str] = field(default_factory=list)
    warnings: List[str] = field(default_factory=list)
    summary: Dict[str, Any] = field(default_factory=dict)

    def add_error(self, msg: str):
        self.errors.append(msg)
        self.is_valid = False

    def add_warning(self, msg: str):
        self.warnings.append(msg)


class DataValidator:
    """
    Validates and standardizes workload, pod-resource, and ocean-condition datasets.
    """

    REQUIRED_WORKLOAD_COLS = [
        "workload_id", "workload_type", "cpu_cores", "gpu_units",
        "ram_gb", "duration_hours"
    ]

    REQUIRED_POD_COLS = [
        "pod_id", "total_cpu", "used_cpu", "total_gpu", "used_gpu",
        "total_ram_gb", "used_ram_gb", "status", "base_power_kw"
    ]

    REQUIRED_OCEAN_COLS = [
        "pod_id", "timestamp", "water_temperature_c", "current_speed_mps",
        "salinity_psu", "depth_m", "grid_carbon_intensity_kg_per_kwh"
    ]

    VALID_POD_STATUSES = {"ACTIVE", "ONLINE", "MAINTENANCE", "DEGRADED", "OFFLINE"}

    def __init__(self, max_stale_hours: float = 24.0, reference_time: Optional[datetime] = None):
        self.max_stale_hours = max_stale_hours
        self.reference_time = reference_time or datetime.now(timezone.utc)

    def validate_workload_df(self, df: pd.DataFrame) -> Tuple[pd.DataFrame, ValidationReport]:
        """Validate workload profiles dataframe."""
        report = ValidationReport()
        if df is None or df.empty:
            report.add_error("Workload dataset is empty or None.")
            return df, report

        df_clean = df.copy()

        # Check required columns
        missing_cols = [c for c in self.REQUIRED_WORKLOAD_COLS if c not in df_clean.columns]
        if missing_cols:
            report.add_error(f"Workload dataset missing required columns: {missing_cols}")
            return df_clean, report

        # Check duplicates
        dups = df_clean.duplicated(subset=["workload_id"]).sum()
        if dups > 0:
            report.add_warning(f"Found {dups} duplicate workload_id records; duplicates dropped.")
            df_clean = df_clean.drop_duplicates(subset=["workload_id"], keep="first")

        # Numeric and positive value checks
        numeric_cols = ["cpu_cores", "gpu_units", "ram_gb", "duration_hours"]
        for col in numeric_cols:
            if not pd.api.types.is_numeric_dtype(df_clean[col]):
                try:
                    df_clean[col] = pd.to_numeric(df_clean[col])
                except Exception:
                    report.add_error(f"Workload column '{col}' contains non-numeric values.")
            
            # Check range
            invalid_neg = (df_clean[col] < 0).sum()
            if invalid_neg > 0:
                report.add_error(f"Workload column '{col}' contains {invalid_neg} negative values.")

            if col in ["cpu_cores", "ram_gb", "duration_hours"]:
                zeros = (df_clean[col] <= 0).sum()
                if zeros > 0:
                    report.add_error(f"Workload column '{col}' has {zeros} zero or negative values.")

        report.summary["workload_count"] = len(df_clean)
        return df_clean, report

    def validate_pod_resources_df(self, df: pd.DataFrame) -> Tuple[pd.DataFrame, ValidationReport]:
        """Validate pod resources dataframe."""
        report = ValidationReport()
        if df is None or df.empty:
            report.add_error("Pod resources dataset is empty or None.")
            return df, report

        df_clean = df.copy()

        missing_cols = [c for c in self.REQUIRED_POD_COLS if c not in df_clean.columns]
        if missing_cols:
            report.add_error(f"Pod resources dataset missing required columns: {missing_cols}")
            return df_clean, report

        # Duplicate check
        dups = df_clean.duplicated(subset=["pod_id"]).sum()
        if dups > 0:
            report.add_warning(f"Found {dups} duplicate pod_id records; keeping first occurrence.")
            df_clean = df_clean.drop_duplicates(subset=["pod_id"], keep="first")

        # Normalize status to uppercase string
        df_clean["status"] = df_clean["status"].astype(str).str.strip().str.upper()
        invalid_status = df_clean[~df_clean["status"].isin(self.VALID_POD_STATUSES)]
        if not invalid_status.empty:
            report.add_warning(f"Pods with unknown status found: {invalid_status['pod_id'].tolist()}. Defaulting to DEGRADED.")
            df_clean.loc[~df_clean["status"].isin(self.VALID_POD_STATUSES), "status"] = "DEGRADED"

        # Check numeric and physical impossibilities: Used > Total
        pairs = [
            ("total_cpu", "used_cpu", "CPU"),
            ("total_gpu", "used_gpu", "GPU"),
            ("total_ram_gb", "used_ram_gb", "RAM")
        ]

        for tot_col, used_col, res_name in pairs:
            for c in [tot_col, used_col]:
                if not pd.api.types.is_numeric_dtype(df_clean[c]):
                    try:
                        df_clean[c] = pd.to_numeric(df_clean[c])
                    except Exception:
                        report.add_error(f"Pod column '{c}' contains non-numeric values.")

            # Negative check
            if (df_clean[tot_col] < 0).any() or (df_clean[used_col] < 0).any():
                report.add_error(f"Negative values detected in pod {res_name} allocations.")

            # Impossible resource check: Used > Total
            impossible = df_clean[df_clean[used_col] > df_clean[tot_col]]
            if not impossible.empty:
                bad_ids = impossible["pod_id"].tolist()
                report.add_error(f"Physical impossibility: used_{res_name} > total_{res_name} for pods: {bad_ids}")

        # Power sanity check
        if not pd.api.types.is_numeric_dtype(df_clean["base_power_kw"]):
            df_clean["base_power_kw"] = pd.to_numeric(df_clean["base_power_kw"], errors="coerce").fillna(20.0)
        
        neg_power = (df_clean["base_power_kw"] <= 0).sum()
        if neg_power > 0:
            report.add_error(f"Found {neg_power} pods with zero or negative base_power_kw.")

        # Optional columns defaults
        if "max_power_kw" not in df_clean.columns:
            df_clean["max_power_kw"] = df_clean["base_power_kw"] * 3.5
        if "pue" not in df_clean.columns:
            df_clean["pue"] = 1.07
        if "network_latency_ms" not in df_clean.columns:
            df_clean["network_latency_ms"] = 15.0
        if "surface_area_m2" not in df_clean.columns:
            df_clean["surface_area_m2"] = 120.0

        report.summary["pod_count"] = len(df_clean)
        report.summary["active_pods"] = (df_clean["status"].isin(["ACTIVE", "ONLINE"])).sum()
        return df_clean, report

    def validate_ocean_conditions_df(self, df: pd.DataFrame) -> Tuple[pd.DataFrame, ValidationReport]:
        """Validate ocean conditions dataframe."""
        report = ValidationReport()
        if df is None or df.empty:
            report.add_error("Ocean conditions dataset is empty or None.")
            return df, report

        df_clean = df.copy()

        missing_cols = [c for c in self.REQUIRED_OCEAN_COLS if c not in df_clean.columns]
        if missing_cols:
            report.add_error(f"Ocean conditions dataset missing required columns: {missing_cols}")
            return df_clean, report

        # Duplicates check
        dups = df_clean.duplicated(subset=["pod_id"]).sum()
        if dups > 0:
            report.add_warning(f"Found {dups} duplicate pod_id entries in ocean conditions; using newest timestamp.")
            if "timestamp" in df_clean.columns:
                df_clean = df_clean.sort_values(by="timestamp", ascending=False).drop_duplicates(subset=["pod_id"], keep="first")
            else:
                df_clean = df_clean.drop_duplicates(subset=["pod_id"], keep="first")

        # Timestamp parsing & staleness check
        try:
            df_clean["parsed_timestamp"] = pd.to_datetime(df_clean["timestamp"], utc=True)
            # Check staleness if reference time provided
            age_hours = (self.reference_time - df_clean["parsed_timestamp"]).dt.total_seconds() / 3600.0
            stale_mask = age_hours > self.max_stale_hours
            if stale_mask.any():
                stale_pods = df_clean.loc[stale_mask, "pod_id"].tolist()
                report.add_warning(
                    f"Stale ocean data detected for pods {stale_pods} (> {self.max_stale_hours}h old)."
                )
        except Exception as e:
            report.add_warning(f"Could not parse timestamps in ocean conditions: {e}")

        # Check physical oceanographic boundaries
        # Water temp: typically -2.5°C to 38.0°C in ocean
        bad_temp = df_clean[(df_clean["water_temperature_c"] < -4.0) | (df_clean["water_temperature_c"] > 45.0)]
        if not bad_temp.empty:
            report.add_error(f"Ocean temperature out of physical bounds (-4 to 45°C) for pods: {bad_temp['pod_id'].tolist()}")

        # Current speed: 0 to 6 m/s
        bad_curr = df_clean[(df_clean["current_speed_mps"] < 0) | (df_clean["current_speed_mps"] > 8.0)]
        if not bad_curr.empty:
            report.add_error(f"Current speed out of physical bounds (0 to 8 m/s) for pods: {bad_curr['pod_id'].tolist()}")

        # Salinity: 0 to 45 PSU
        bad_sal = df_clean[(df_clean["salinity_psu"] < 0) | (df_clean["salinity_psu"] > 50.0)]
        if not bad_sal.empty:
            report.add_warning(f"Salinity unusual (<0 or >50 PSU) for pods: {bad_sal['pod_id'].tolist()}")

        # Depth: must be > 0
        bad_depth = df_clean[df_clean["depth_m"] <= 0]
        if not bad_depth.empty:
            report.add_error(f"Depth must be positive (> 0m) for underwater pods: {bad_depth['pod_id'].tolist()}")

        # Carbon intensity: must be >= 0
        bad_ci = df_clean[df_clean["grid_carbon_intensity_kg_per_kwh"] < 0]
        if not bad_ci.empty:
            report.add_error(f"Grid carbon intensity cannot be negative for pods: {bad_ci['pod_id'].tolist()}")

        # Optional columns defaults
        if "ecological_zone" not in df_clean.columns:
            df_clean["ecological_zone"] = "MODERATE"
        if "current_direction_deg" not in df_clean.columns:
            df_clean["current_direction_deg"] = 0.0

        report.summary["ocean_records"] = len(df_clean)
        return df_clean, report

    def validate_cross_dataset_integrity(
        self,
        pod_df: pd.DataFrame,
        ocean_df: pd.DataFrame
    ) -> ValidationReport:
        """Ensure pod_id alignment between pod resources and ocean conditions."""
        report = ValidationReport()
        if pod_df is None or ocean_df is None or pod_df.empty or ocean_df.empty:
            report.add_error("One or both datasets empty for cross-dataset check.")
            return report

        pod_ids = set(pod_df["pod_id"].unique())
        ocean_pod_ids = set(ocean_df["pod_id"].unique())

        missing_in_ocean = pod_ids - ocean_pod_ids
        if missing_in_ocean:
            report.add_warning(f"Pods with missing ocean condition telemetry: {sorted(list(missing_in_ocean))}. These pods cannot compute thermal/risk safely.")

        orphan_ocean = ocean_pod_ids - pod_ids
        if orphan_ocean:
            report.add_warning(f"Ocean records for unknown pod_ids: {sorted(list(orphan_ocean))}")

        report.summary["matched_pods"] = len(pod_ids.intersection(ocean_pod_ids))
        return report
