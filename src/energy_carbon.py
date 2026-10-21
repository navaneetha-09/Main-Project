"""
AquaEcoSched: Energy & Carbon Estimation Module (FR-05, Slide 6)
Implements:
  - Energy (kWh) = Power (kW) * Time (h)
  - Carbon (kg CO2e) = Energy * Carbon intensity (kg CO2e / kWh)
Includes both incremental workload consumption and total facility consumption.
"""

from dataclasses import dataclass
from typing import Dict, Any, Optional
import pandas as pd


@dataclass
class EnergyCarbonEstimate:
    pod_id: str
    workload_power_kw: float
    total_pod_power_kw: float
    pue: float
    runtime_hours: float
    workload_energy_kwh: float
    total_facility_energy_kwh: float
    carbon_intensity_kg_per_kwh: float
    workload_carbon_kg_co2e: float
    total_pod_carbon_kg_co2e: float


class EnergyCarbonEstimator:
    """
    Computes rigorous energy (kWh) and carbon emissions (kg CO2e)
    for underwater computing pods executing a workload.
    """

    def __init__(
        self,
        cpu_weight: float = 0.50,
        gpu_weight: float = 0.40,
        ram_weight: float = 0.10
    ):
        self.cpu_weight = cpu_weight
        self.gpu_weight = gpu_weight
        self.ram_weight = ram_weight

    def estimate_pod_power(
        self,
        pod_row: pd.Series,
        workload: Dict[str, Any]
    ) -> Dict[str, float]:
        """
        Estimate power consumption in kilowatts (kW).
        P_dynamic = (P_max - P_base) * (alpha * (req_cpu/tot_cpu) + beta * (req_gpu/tot_gpu) + gamma * (req_ram/tot_ram))
        """
        base_power = float(pod_row.get("base_power_kw", 20.0))
        max_power = float(pod_row.get("max_power_kw", base_power * 3.5))
        pue = float(pod_row.get("pue", 1.07))

        tot_cpu = max(float(pod_row.get("total_cpu", 64)), 1.0)
        tot_gpu = max(float(pod_row.get("total_gpu", 8)), 1.0)
        tot_ram = max(float(pod_row.get("total_ram_gb", 256)), 1.0)

        req_cpu = float(workload.get("cpu_cores", 0))
        req_gpu = float(workload.get("gpu_units", 0))
        req_ram = float(workload.get("ram_gb", 0))

        # Dynamic fraction
        dynamic_span = max(max_power - base_power, 5.0)
        cpu_frac = min(req_cpu / tot_cpu, 1.0)
        gpu_frac = min(req_gpu / tot_gpu, 1.0)
        ram_frac = min(req_ram / tot_ram, 1.0)

        weighted_util = (
            self.cpu_weight * cpu_frac +
            self.gpu_weight * gpu_frac +
            self.ram_weight * ram_frac
        )

        workload_dynamic_power = dynamic_span * weighted_util
        total_it_power = base_power + workload_dynamic_power

        # Facility power with PUE
        workload_facility_power = workload_dynamic_power * pue
        total_facility_power = total_it_power * pue

        return {
            "workload_it_power_kw": round(workload_dynamic_power, 3),
            "workload_facility_power_kw": round(workload_facility_power, 3),
            "total_facility_power_kw": round(total_facility_power, 3),
            "pue": pue
        }

    def compute_energy_and_carbon(
        self,
        pod_row: pd.Series,
        ocean_row: Optional[pd.Series],
        workload: Dict[str, Any]
    ) -> EnergyCarbonEstimate:
        """
        Calculates energy in kWh and carbon in kg CO2e.
        """
        runtime_hours = float(workload.get("duration_hours", 1.0))
        power_info = self.estimate_pod_power(pod_row, workload)

        workload_kw = power_info["workload_facility_power_kw"]
        total_kw = power_info["total_facility_power_kw"]
        pue = power_info["pue"]

        # Energy (kWh) = Power (kW) * Time (h)
        workload_energy_kwh = workload_kw * runtime_hours
        total_energy_kwh = total_kw * runtime_hours

        # Carbon intensity from ocean/regional grid connection (kg CO2e / kWh)
        carbon_intensity = 0.20  # default reasonable average
        if ocean_row is not None and "grid_carbon_intensity_kg_per_kwh" in ocean_row:
            val = ocean_row["grid_carbon_intensity_kg_per_kwh"]
            if pd.notna(val) and val >= 0:
                carbon_intensity = float(val)

        # Carbon (kg CO2e) = Energy (kWh) * Carbon intensity
        workload_carbon_kg = workload_energy_kwh * carbon_intensity
        total_carbon_kg = total_energy_kwh * carbon_intensity

        return EnergyCarbonEstimate(
            pod_id=str(pod_row["pod_id"]),
            workload_power_kw=round(workload_kw, 3),
            total_pod_power_kw=round(total_kw, 3),
            pue=pue,
            runtime_hours=runtime_hours,
            workload_energy_kwh=round(workload_energy_kwh, 4),
            total_facility_energy_kwh=round(total_energy_kwh, 4),
            carbon_intensity_kg_per_kwh=round(carbon_intensity, 4),
            workload_carbon_kg_co2e=round(workload_carbon_kg, 4),
            total_pod_carbon_kg_co2e=round(total_carbon_kg, 4)
        )
