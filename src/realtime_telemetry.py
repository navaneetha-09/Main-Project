"""
AquaEcoSched: Real-Time Oceanographic Telemetry Service
Generates live-synchronized telemetry feeds, dynamic oceanographic fluctuations,
tidal harmonic modulations, and real-time streaming telemetry snapshots.
"""

import os
import math
import numpy as np
import pandas as pd
from datetime import datetime, timezone, timedelta
from typing import Dict, Any, Optional, Tuple


class RealtimeOceanTelemetryService:
    """
    Simulates and ingests high-fidelity real-time subsea oceanographic sensor feeds.
    Applies hydrodynamic tidal harmonic variation, diurnal thermocline oscillations,
    and real-time grid carbon intensity diurnal cycles.
    """

    def __init__(self, data_dir: Optional[str] = None):
        self.data_dir = data_dir or os.path.join(os.path.dirname(os.path.dirname(__file__)), "data")
        self._last_snapshot_time = datetime.now(timezone.utc)

    @classmethod
    def get_current_utc_timestamp(cls) -> str:
        """Returns current UTC ISO-8601 formatted timestamp."""
        return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    def generate_realtime_snapshot(
        self,
        base_df: pd.DataFrame,
        time_offset_seconds: float = 0.0,
        current_multiplier: float = 1.0,
        temp_shift_c: float = 0.0,
        carbon_multiplier: float = 1.0
    ) -> pd.DataFrame:
        """
        Takes a base ocean telemetry dataframe and projects it to the CURRENT exact moment
        with hydrodynamic physics-based micro-fluctuations.
        """
        if base_df is None or base_df.empty:
            return pd.DataFrame()

        df = base_df.copy()
        now = datetime.now(timezone.utc) + timedelta(seconds=time_offset_seconds)
        current_iso = now.strftime("%Y-%m-%dT%H:%M:%SZ")

        # Tidal cycle: M2 semidiurnal tide period is ~12.42 hours (44712 seconds)
        seconds_of_day = now.hour * 3600 + now.minute * 60 + now.second
        tidal_phase = (2 * math.pi * seconds_of_day) / 44712.0

        # Diurnal solar cycle: 24 hours (86400 seconds)
        solar_phase = (2 * math.pi * seconds_of_day) / 86400.0

        # Dynamic updates
        df["timestamp"] = current_iso

        # 1. Tidal current speed oscillation: +/- 15% periodic wave + small turbulence
        np.random.seed(int(seconds_of_day) % 10000)
        noise_v = np.random.normal(0.0, 0.02, size=len(df))
        df["current_speed_mps"] = np.clip(
            (df["current_speed_mps"] * (1.0 + 0.15 * math.sin(tidal_phase)) + noise_v) * current_multiplier,
            0.05, 5.0
        ).round(3)

        # 2. Water temperature drift: slight diurnal thermocline variation (+/- 0.4 C)
        noise_t = np.random.normal(0.0, 0.05, size=len(df))
        df["water_temperature_c"] = np.clip(
            (df["water_temperature_c"] + 0.35 * math.sin(solar_phase - math.pi / 2) + noise_t + temp_shift_c),
            -2.0, 35.0
        ).round(2)

        # 3. Grid carbon intensity: diurnal grid load (higher during peak hours)
        df["grid_carbon_intensity_kg_per_kwh"] = np.clip(
            (df["grid_carbon_intensity_kg_per_kwh"] * (1.0 + 0.12 * math.sin(solar_phase))) * carbon_multiplier,
            0.01, 1.5
        ).round(4)

        # 4. Turbidity micro-fluctuations
        if "ambient_turbidity_ntu" in df.columns:
            df["ambient_turbidity_ntu"] = np.clip(
                df["ambient_turbidity_ntu"] * (1.0 + 0.10 * math.cos(tidal_phase)),
                0.1, 20.0
            ).round(2)

        self._last_snapshot_time = now
        return df

    def sync_ocean_csv_to_live_utc(self) -> Tuple[int, str]:
        """
        Updates the ocean_conditions.csv file so that its timestamps reflect the current live UTC time.
        """
        ocean_path = os.path.join(self.data_dir, "ocean_conditions.csv")
        if not os.path.exists(ocean_path):
            return 0, "File not found"

        df = pd.read_csv(ocean_path)
        live_df = self.generate_realtime_snapshot(df)
        live_df.to_csv(ocean_path, index=False)
        return len(live_df), self.get_current_utc_timestamp()

    def generate_high_frequency_stream(
        self,
        pod_id: str,
        base_temp_c: float,
        base_current_mps: float,
        base_carbon_kg: float,
        num_points: int = 15,
        interval_seconds: int = 10
    ) -> pd.DataFrame:
        """
        Generates high-frequency sub-minute real-time telemetry time-series for live streaming dashboards.
        """
        now = datetime.now(timezone.utc)
        timestamps = [(now - timedelta(seconds=(num_points - 1 - i) * interval_seconds)).strftime("%H:%M:%S") for i in range(num_points)]
        
        np.random.seed(42)
        v_stream = [max(0.05, round(base_current_mps + 0.08 * math.sin(i * 0.4) + np.random.normal(0, 0.01), 3)) for i in range(num_points)]
        t_stream = [round(base_temp_c + 0.12 * math.sin(i * 0.3) + np.random.normal(0, 0.02), 2) for i in range(num_points)]
        c_stream = [round(base_carbon_kg * (1.0 + 0.05 * math.sin(i * 0.2)), 4) for i in range(num_points)]

        return pd.DataFrame({
            "Time": timestamps,
            "Pod ID": [pod_id] * num_points,
            "Water Temp (°C)": t_stream,
            "Current Speed (m/s)": v_stream,
            "Grid Carbon (kg/kWh)": c_stream
        })
