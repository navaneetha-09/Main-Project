"""
AquaEcoSched: Thermal & Environmental Risk Module (FR-05, Slide 6)
Implements a documented hydrodynamic heat-transfer model and ecological risk proxy.

PHYSICAL MODEL DOCUMENTATION:
-----------------------------
1. Heat Generation:
   Q = P_total (kW) * 1000 = [Watts]
2. Forced Convective Seawater Cooling:
   h = h_base + h_velocity * (v_current / v_ref)^0.8  [W / (m^2 * K)]
   where:
     - h_base = 350 W/(m^2*K) (natural buoyancy convection in seawater)
     - h_velocity = 850 W/(m^2*K)
     - v_ref = 1.0 m/s (reference flow velocity)
3. Temperature Rise (Delta T):
   Delta T = Q / (h * Surface_Area)  [deg C]
4. Thermal Footprint Index:
   Quantifies the surrounding volume of water subjected to thermal elevation.
5. Environmental Risk Score (0.0 to 1.0):
   Synthesizes thermal elevation Delta T, ambient temperature, ecological zone
   sensitivity, and depth dispersion.
"""

from dataclasses import dataclass
from typing import Dict, Any, Optional
import numpy as np
import pandas as pd


@dataclass
class ThermalRiskEstimate:
    pod_id: str
    heat_dissipated_kw: float
    convective_h_w_m2k: float
    delta_temp_c: float
    local_water_temp_c: float
    estimated_pod_internal_temp_c: float
    thermal_footprint_score: float
    ecological_sensitivity_weight: float
    environmental_risk_score: float
    model_type: str = "Hydrodynamic Convection Proxy (Documented Physics)"


class ThermalRiskEstimator:
    """
    Computes pod surface temperature rise and ecological risk metrics.
    """

    # Ecological zone sensitivity weights
    ZONE_SENSITIVITY = {
        "LOW_IMPACT": 0.20,
        "MODERATE": 0.50,
        "SENSITIVE_BENTHIC": 0.85,
        "PROTECTED_CORAL_REEF": 1.00
    }

    def __init__(
        self,
        h_base: float = 350.0,
        h_velocity: float = 850.0,
        internal_hx_delta: float = 16.0
    ):
        self.h_base = h_base
        self.h_velocity = h_velocity
        self.internal_hx_delta = internal_hx_delta

    def compute_convective_coefficient(self, current_speed_mps: float) -> float:
        """
        Convective heat transfer coefficient h in W/(m^2 * K).
        Flow velocity enhances heat transfer following empirical Reynolds scaling (v^0.8).
        """
        v = max(float(current_speed_mps), 0.05)
        h = self.h_base + self.h_velocity * (v ** 0.8)
        return float(h)

    def estimate_thermal_and_risk(
        self,
        pod_row: pd.Series,
        ocean_row: Optional[pd.Series],
        power_estimate_kw: float
    ) -> ThermalRiskEstimate:
        """
        Calculates thermal dissipation, temperature delta, and composite environmental risk.
        """
        pod_id = str(pod_row.get("pod_id", "UNKNOWN"))
        surface_area = float(pod_row.get("surface_area_m2", 120.0))

        # Ambient ocean parameters
        if ocean_row is not None:
            ambient_temp = float(ocean_row.get("water_temperature_c", 10.0))
            current_speed = float(ocean_row.get("current_speed_mps", 0.5))
            depth = float(ocean_row.get("depth_m", 50.0))
            zone = str(ocean_row.get("ecological_zone", "MODERATE")).strip().upper()
        else:
            ambient_temp = 10.0
            current_speed = 0.5
            depth = 50.0
            zone = "MODERATE"

        # Heat generated in Watts: Q = P (kW) * 1000
        q_watts = max(power_estimate_kw, 1.0) * 1000.0

        # Convective heat transfer coefficient h
        h = self.compute_convective_coefficient(current_speed)

        # Delta T = Q / (h * A) in Celsius
        delta_temp = q_watts / (h * surface_area)
        local_water_temp = ambient_temp + delta_temp
        internal_temp = local_water_temp + self.internal_hx_delta

        # Thermal footprint score (0 to 1):
        # Higher heat dissipation with slow current creates a larger stagnant thermal plume
        dispersion_capacity = max(current_speed * np.sqrt(depth), 0.5)
        thermal_footprint_raw = (delta_temp * (power_estimate_kw / 50.0)) / dispersion_capacity
        # Sigmoid or clamped scale to [0, 1]
        thermal_footprint_score = float(np.clip(thermal_footprint_raw / 3.5, 0.02, 1.0))

        # Ecological sensitivity factor
        zone_weight = self.ZONE_SENSITIVITY.get(zone, 0.50)

        # Environmental Risk Score calculation (0 to 1 scale):
        # Combines thermal plume, vulnerability of local ecosystem, and ambient heat baseline
        # Coral reefs or warm seas (>20C) are much more vulnerable to Delta T
        ambient_vulnerability = np.clip((ambient_temp - 5.0) / 25.0, 0.1, 1.0)
        
        # Depth penalty: shallow water (<40m) has higher photic zone impact
        depth_penalty = 1.0 if depth >= 100.0 else (1.0 + (100.0 - depth) / 150.0)

        raw_risk = (
            0.45 * thermal_footprint_score +
            0.35 * zone_weight * (1.0 + ambient_vulnerability) +
            0.20 * (delta_temp / 3.0)
        ) * (depth_penalty / 1.2)

        risk_score = float(np.clip(raw_risk, 0.01, 1.0))

        return ThermalRiskEstimate(
            pod_id=pod_id,
            heat_dissipated_kw=round(power_estimate_kw, 2),
            convective_h_w_m2k=round(h, 1),
            delta_temp_c=round(delta_temp, 3),
            local_water_temp_c=round(local_water_temp, 2),
            estimated_pod_internal_temp_c=round(internal_temp, 2),
            thermal_footprint_score=round(thermal_footprint_score, 4),
            ecological_sensitivity_weight=round(zone_weight, 2),
            environmental_risk_score=round(risk_score, 4)
        )
