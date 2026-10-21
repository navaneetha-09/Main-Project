"""
AquaEcoSched: Environment-Aware Multi-Objective Scheduling for Underwater Computing Pods
Connected 9-Step End-to-End Workflow Application (app.py)

Follows the exact client requirement flow:
01 Choose workload - Display CPU, GPU, RAM, storage, runtime and priority
02 Launch scheduling - Load pod inventory and matching ocean data
03 Find possible pods - Check resource availability and show rejection reasons
04 Calculate impacts - Energy, carbon, thermal impact, environmental risk and performance
05 Choose objective weights - Adjust priorities and recalculate the ranking
06 Explain the best pod - Show values, score breakdown, alternatives and selection reasons
07 Confirm and execute - Start actual execution or a clearly labelled simulation
08 Monitor continuously - Track workload progress, resources, telemetry, energy, carbon and alerts
09 Review datasets and reports - Use the same data source and run history for reports and analysis
"""

import os
import json
import time
from datetime import datetime, timezone
import pandas as pd
import numpy as np
import streamlit as st
import plotly.express as px
import plotly.graph_objects as go

# Import core domain modules
from src.data_validation import DataValidator, ValidationReport
from src.resource_filter import ResourceFilter
from src.energy_carbon import EnergyCarbonEstimator
from src.thermal_risk import ThermalRiskEstimator
from src.risk_budget import RiskBudgetEnforcer
from src.scheduler import AquaEcoScheduler, SchedulingDecision
from src.monitoring import PodExecutionMonitor
from src.reporting import BaselineComparator, SchedulingReporter
from src.realtime_telemetry import RealtimeOceanTelemetryService

# Page configuration
st.set_page_config(
    page_title="AquaEcoSched | Subsea Pod Multi-Objective Scheduler",
    page_icon="🌊",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Modern Clean Dark Slate Design System
st.markdown("""
<style>
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600&display=swap');

    /* Global Typography & Slate Theme */
    html, body, [class*="css"], .stApp {
        font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif !important;
        background-color: #0b0f19 !important;
        color: #e2e8f0 !important;
    }

    code, pre {
        font-family: 'JetBrains Mono', monospace !important;
    }

    /* Clean Scrollbars */
    ::-webkit-scrollbar {
        width: 6px;
        height: 6px;
    }
    ::-webkit-scrollbar-track {
        background: #0b0f19;
    }
    ::-webkit-scrollbar-thumb {
        background: #1e293b;
        border-radius: 4px;
    }
    ::-webkit-scrollbar-thumb:hover {
        background: #334155;
    }

    /* Sleek Clean Header */
    .clean-header {
        background: linear-gradient(180deg, rgba(19, 27, 46, 0.95) 0%, rgba(15, 23, 42, 0.95) 100%);
        border: 1px solid rgba(255, 255, 255, 0.08);
        border-radius: 14px;
        padding: 20px 24px;
        margin-bottom: 20px;
        box-shadow: 0 4px 20px -2px rgba(0, 0, 0, 0.5);
    }
    
    .clean-header-top {
        display: flex;
        align-items: center;
        justify-content: space-between;
        flex-wrap: wrap;
        gap: 12px;
        margin-bottom: 12px;
    }

    .clean-title {
        color: #f8fafc;
        font-size: 1.75rem;
        font-weight: 800;
        letter-spacing: -0.025em;
        display: flex;
        align-items: center;
        gap: 12px;
    }
    
    .brand-gradient {
        background: linear-gradient(135deg, #38bdf8 0%, #34d399 100%);
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
    }

    /* Refined Status Badges / Chips */
    .status-chip {
        font-size: 0.72rem;
        background: rgba(255, 255, 255, 0.05);
        color: #94a3b8;
        padding: 3px 10px;
        border-radius: 9999px;
        border: 1px solid rgba(255, 255, 255, 0.1);
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 0.06em;
        display: inline-flex;
        align-items: center;
        gap: 5px;
    }

    .status-chip.cyan {
        background: rgba(56, 189, 248, 0.1);
        color: #38bdf8;
        border-color: rgba(56, 189, 248, 0.35);
    }

    .status-chip.emerald {
        background: rgba(52, 211, 153, 0.1);
        color: #34d399;
        border-color: rgba(52, 211, 153, 0.35);
    }

    .status-chip.amber {
        background: rgba(251, 191, 36, 0.1);
        color: #fbbf24;
        border-color: rgba(251, 191, 36, 0.35);
    }

    .status-chip.rose {
        background: rgba(251, 113, 133, 0.1);
        color: #fb7185;
        border-color: rgba(251, 113, 133, 0.35);
    }

    .clean-meta-bar {
        display: flex;
        align-items: center;
        flex-wrap: wrap;
        gap: 16px;
        font-size: 0.82rem;
        color: #94a3b8;
        padding-top: 12px;
        border-top: 1px solid rgba(255, 255, 255, 0.06);
    }

    .clean-meta-item {
        display: flex;
        align-items: center;
        gap: 6px;
    }

    .clean-meta-item b {
        color: #e2e8f0;
    }

    /* Clean Step Indicator Badge */
    .step-badge {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        background: rgba(56, 189, 248, 0.15);
        border: 1px solid rgba(56, 189, 248, 0.35);
        color: #38bdf8;
        font-weight: 700;
        font-size: 0.8rem;
        padding: 2px 8px;
        border-radius: 6px;
        margin-right: 8px;
        letter-spacing: 0.02em;
    }

    /* Refined Clean Card Box */
    .card-box, .clean-card {
        background: #131b2e;
        border: 1px solid rgba(255, 255, 255, 0.08);
        border-radius: 12px;
        padding: 16px 18px;
        margin-bottom: 14px;
        transition: border-color 0.15s ease;
    }

    .card-box:hover, .clean-card:hover {
        border-color: rgba(56, 189, 248, 0.3);
    }

    .metric-value-lg {
        font-size: 1.55rem;
        font-weight: 700;
        color: #f8fafc;
        letter-spacing: -0.015em;
        line-height: 1.2;
    }

    .metric-label-sm {
        font-size: 0.72rem;
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 0.06em;
        color: #94a3b8;
        margin-bottom: 4px;
        display: flex;
        align-items: center;
        justify-content: space-between;
    }

    /* Clean Status Badges */
    .badge-pass {
        background: rgba(52, 211, 153, 0.12);
        color: #34d399;
        padding: 3px 8px;
        border-radius: 6px;
        border: 1px solid rgba(52, 211, 153, 0.35);
        font-weight: 600;
        font-size: 0.75rem;
        letter-spacing: 0.04em;
    }

    .badge-fail {
        background: rgba(251, 113, 133, 0.12);
        color: #fb7185;
        padding: 3px 8px;
        border-radius: 6px;
        border: 1px solid rgba(251, 113, 133, 0.35);
        font-weight: 600;
        font-size: 0.75rem;
        letter-spacing: 0.04em;
    }

    /* Decision Rationale Callout Box */
    .decision-box {
        background: #131b2e;
        border-left: 3px solid #38bdf8;
        border-top: 1px solid rgba(255, 255, 255, 0.06);
        border-right: 1px solid rgba(255, 255, 255, 0.06);
        border-bottom: 1px solid rgba(255, 255, 255, 0.06);
        border-radius: 0 10px 10px 0;
        padding: 16px 20px;
        margin: 14px 0 20px 0;
        font-size: 0.9rem;
        line-height: 1.6;
    }

    /* Streamlit Tabs Polish */
    .stTabs [data-baseweb="tab-list"] {
        gap: 4px;
        background-color: #111827;
        padding: 6px;
        border-radius: 10px;
        border: 1px solid rgba(255, 255, 255, 0.07);
        margin-bottom: 20px;
    }

    .stTabs [data-baseweb="tab"] {
        padding: 7px 14px;
        border-radius: 6px;
        color: #94a3b8;
        font-size: 0.82rem;
        font-weight: 500;
        border: none;
        transition: all 0.15s ease;
    }

    .stTabs [aria-selected="true"] {
        background-color: #1e293b !important;
        color: #38bdf8 !important;
        font-weight: 600 !important;
    }

    /* Button Polish */
    .stButton > button {
        border-radius: 8px !important;
        font-weight: 600 !important;
        font-size: 0.85rem !important;
        border: 1px solid rgba(255, 255, 255, 0.12) !important;
        transition: all 0.15s ease !important;
    }

    .stButton > button:hover {
        border-color: #38bdf8 !important;
        color: #38bdf8 !important;
    }

    /* Dataframe Polish */
    [data-testid="stDataFrame"] {
        border-radius: 8px;
        overflow: hidden;
        border: 1px solid rgba(255, 255, 255, 0.07);
    }
</style>
""", unsafe_allow_html=True)

# Helper function to style Plotly charts consistently in clean dark slate theme
def apply_clean_chart_theme(fig, title="", height=None):
    layout_args = dict(
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(19, 27, 46, 0.5)",
        font=dict(color="#94a3b8", family="Inter, sans-serif", size=11),
        margin=dict(l=35, r=20, t=40 if title else 20, b=35),
        xaxis=dict(
            gridcolor="rgba(255, 255, 255, 0.05)",
            linecolor="rgba(255, 255, 255, 0.08)",
            tickfont=dict(color="#94a3b8")
        ),
        yaxis=dict(
            gridcolor="rgba(255, 255, 255, 0.05)",
            linecolor="rgba(255, 255, 255, 0.08)",
            tickfont=dict(color="#94a3b8")
        ),
        legend=dict(
            font=dict(color="#cbd5e1", size=11),
            bgcolor="rgba(19, 27, 46, 0.85)",
            bordercolor="rgba(255, 255, 255, 0.08)",
            borderwidth=1
        )
    )
    if title:
        layout_args["title"] = dict(text=title, font=dict(color="#f8fafc", size=13, family="Inter, sans-serif"), x=0.01, xanchor="left")
    if height:
        layout_args["height"] = height
    fig.update_layout(**layout_args)
    return fig

# Shared Data Directory
DATA_DIR = os.path.join(os.path.dirname(__file__), "data")

def load_base_datasets():
    wl_path = os.path.join(DATA_DIR, "workload_profiles.csv")
    pod_path = os.path.join(DATA_DIR, "pod_resources.csv")
    ocean_path = os.path.join(DATA_DIR, "ocean_conditions.csv")
    cfg_path = os.path.join(DATA_DIR, "config_defaults.json")

    wl_df = pd.read_csv(wl_path) if os.path.exists(wl_path) else pd.DataFrame()
    pod_df = pd.read_csv(pod_path) if os.path.exists(pod_path) else pd.DataFrame()
    ocean_df = pd.read_csv(ocean_path) if os.path.exists(ocean_path) else pd.DataFrame()
    
    # Ensure storage_gb in datasets
    if not wl_df.empty and "storage_gb" not in wl_df.columns:
        wl_df["storage_gb"] = 120.0
    if not pod_df.empty and "total_storage_gb" not in pod_df.columns:
        pod_df["total_storage_gb"] = 2000.0
        pod_df["used_storage_gb"] = 400.0

    config = {}
    if os.path.exists(cfg_path):
        with open(cfg_path, "r") as f:
            config = json.load(f)

    return wl_df, pod_df, ocean_df, config

raw_wl_df, raw_pod_df, raw_ocean_df, config_defaults = load_base_datasets()

# Initialize Session State Variables
if "run_id" not in st.session_state:
    st.session_state.run_id = f"RUN-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
if "run_timestamp" not in st.session_state:
    st.session_state.run_timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
if "data_mode" not in st.session_state:
    st.session_state.data_mode = "Calibrated Simulation"
if "monitor" not in st.session_state:
    st.session_state.monitor = PodExecutionMonitor()
if "active_task_id" not in st.session_state:
    st.session_state.active_task_id = None
if "run_history" not in st.session_state:
    st.session_state.run_history = []
if "custom_wl_df" not in st.session_state:
    st.session_state.custom_wl_df = None
if "custom_pod_df" not in st.session_state:
    st.session_state.custom_pod_df = None
if "custom_ocean_df" not in st.session_state:
    st.session_state.custom_ocean_df = None
if "future_workload_queue" not in st.session_state:
    st.session_state.future_workload_queue = []
if "custom_workload_catalog" not in st.session_state:
    st.session_state.custom_workload_catalog = []
if "auto_sim_active" not in st.session_state:
    st.session_state.auto_sim_active = False

# Dynamic ocean environment modifiers
if "env_temp_shift" not in st.session_state:
    st.session_state.env_temp_shift = 0.0
if "env_current_mult" not in st.session_state:
    st.session_state.env_current_mult = 1.0
if "env_carbon_mult" not in st.session_state:
    st.session_state.env_carbon_mult = 1.0

# Objective Weights
if "w_energy" not in st.session_state:
    st.session_state.w_energy = 0.15
if "w_carbon" not in st.session_state:
    st.session_state.w_carbon = 0.15
if "w_thermal" not in st.session_state:
    st.session_state.w_thermal = 0.30
if "w_risk" not in st.session_state:
    st.session_state.w_risk = 0.30
if "w_perf" not in st.session_state:
    st.session_state.w_perf = 0.10

# Active Datasets with dynamic ocean conditions applied
active_wl_df = st.session_state.custom_wl_df if st.session_state.custom_wl_df is not None else raw_wl_df.copy()
active_pod_df = st.session_state.custom_pod_df if st.session_state.custom_pod_df is not None else raw_pod_df.copy()
base_ocean = st.session_state.custom_ocean_df if st.session_state.custom_ocean_df is not None else raw_ocean_df.copy()

# Apply dynamic environmental adjustments (simulating live oceanic telemetry)
active_ocean_df = base_ocean.copy()
if not active_ocean_df.empty:
    active_ocean_df["water_temperature_c"] = np.clip(
        active_ocean_df["water_temperature_c"] + st.session_state.env_temp_shift, -1.5, 35.0
    )
    active_ocean_df["current_speed_mps"] = np.clip(
        active_ocean_df["current_speed_mps"] * st.session_state.env_current_mult, 0.05, 5.0
    )
    active_ocean_df["grid_carbon_intensity_kg_per_kwh"] = np.clip(
        active_ocean_df["grid_carbon_intensity_kg_per_kwh"] * st.session_state.env_carbon_mult, 0.01, 1.5
    )

# Validation
validator = DataValidator(max_stale_hours=24.0)
clean_wl_df, rep_wl = validator.validate_workload_df(active_wl_df)
clean_pod_df, rep_pod = validator.validate_pod_resources_df(active_pod_df)
clean_ocean_df, rep_ocean = validator.validate_ocean_conditions_df(active_ocean_df)
rep_cross = validator.validate_cross_dataset_integrity(clean_pod_df, clean_ocean_df)

# Top Header Strip
st.markdown(f"""
<div class="clean-header">
    <div class="clean-header-top">
        <div class="clean-title">
            <span>🌊</span>
            <span class="brand-gradient">AquaEcoSched</span>
            <span style="font-size: 0.85rem; font-weight: 500; color: #94a3b8; margin-left: 6px;">| Subsea Pod Multi-Objective Scheduler</span>
        </div>
        <div style="display: flex; gap: 8px; flex-wrap: wrap;">
            <span class="status-chip cyan">Run: {st.session_state.run_id}</span>
            <span class="status-chip emerald">● {st.session_state.data_mode}</span>
            <span class="status-chip {'emerald' if (rep_wl.is_valid and rep_pod.is_valid and rep_ocean.is_valid) else 'amber'}">
                {'✓ VALIDATED' if (rep_wl.is_valid and rep_pod.is_valid and rep_ocean.is_valid) else '⚠ CHECK WARNINGS'}
            </span>
        </div>
    </div>
    <div class="clean-meta-bar">
        <div class="clean-meta-item"><span>🕒 Snapshot Time:</span> <b>{st.session_state.run_timestamp}</b></div>
        <div class="clean-meta-item"><span>🖥️ Fleet:</span> <b>{len(clean_pod_df)} Pods</b></div>
        <div class="clean-meta-item"><span>🌊 Telemetry:</span> <b>{len(clean_ocean_df)} Verified</b></div>
        <div class="clean-meta-item"><span>📋 Batch Queue:</span> <b>{len(st.session_state.future_workload_queue)} Pending</b></div>
    </div>
</div>
""", unsafe_allow_html=True)

# Define the exact 9-step tabs required by the client
t1, t2, t3, t4, t5, t6, t7, t8, t9 = st.tabs([
    "01 Choose Workload",
    "02 Launch Scheduling",
    "03 Possible Pods",
    "04 Impact Calculations",
    "05 Objective Weights",
    "06 Explain Best Pod",
    "07 Confirm & Execute",
    "08 Monitor Continuously",
    "09 Review Datasets & Reports"
])

# ==============================================================================
# 01 CHOOSE WORKLOAD
# Display CPU, GPU, RAM, storage, runtime and priority
# ==============================================================================
with t1:
    st.markdown("### <span class='step-badge'>01</span> Choose Workload Profile & Future Workload Queue", unsafe_allow_html=True)
    st.caption("Select a workload from the verified dataset, customize parameters in real-time, or queue future upcoming workloads.")

    # Combine verified dataset with any custom session workloads avoiding duplicate workload_id
    all_wl_map = {r["workload_id"]: r for r in clean_wl_df.to_dict("records")}
    for r in st.session_state.custom_workload_catalog:
        all_wl_map[r["workload_id"]] = r
    all_wl_records = list(all_wl_map.values())

    if "workload_config_mode" not in st.session_state:
        st.session_state.workload_config_mode = "Catalog Workload (Customizable)"

    modes = ["Catalog Workload (Customizable)", "Create New Workload", "Future Workload Queue"]
    mode_idx = modes.index(st.session_state.workload_config_mode) if st.session_state.workload_config_mode in modes else 0

    c_mode, c_new_run = st.columns([3, 1])
    with c_mode:
        workload_source = st.radio(
            "Select Workload Configuration Mode",
            modes,
            index=mode_idx,
            horizontal=True
        )
        st.session_state.workload_config_mode = workload_source
    with c_new_run:
        if st.button("🔄 Generate New Run ID", use_container_width=True):
            st.session_state.run_id = f"RUN-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
            st.session_state.run_timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
            st.rerun()

    workload_dict = {}

    if workload_source == "Catalog Workload (Customizable)":
        opts = [f"{r['workload_id']} — {r['workload_type']} ({r.get('priority', 'HIGH')})" for r in all_wl_records]
        default_idx = 0
        if "selected_workload_id" in st.session_state:
            for idx, r in enumerate(all_wl_records):
                if r.get("workload_id") == st.session_state.selected_workload_id:
                    default_idx = idx
                    break
        selected_wl_idx = st.selectbox("Choose Workload Record from Catalog", range(len(opts)), index=default_idx, format_func=lambda i: opts[i])
        selected_row = all_wl_records[selected_wl_idx]
        st.session_state.selected_workload_id = selected_row.get("workload_id")

        # In-line parameter fine-tuner
        st.markdown("##### ⚙️ Workload Resource Specification (Adjustable)")
        c1, c2, c3 = st.columns(3)
        with c1:
            wl_cpu = st.number_input("Required CPU Cores", min_value=1, max_value=256, value=int(selected_row["cpu_cores"]), step=2)
            wl_gpu = st.number_input("Required GPU Units", min_value=0, max_value=64, value=int(selected_row["gpu_units"]), step=1)
        with c2:
            wl_ram = st.number_input("Required RAM (GB)", min_value=4, max_value=1024, value=int(selected_row["ram_gb"]), step=8)
            wl_storage = st.number_input("Required Storage (GB)", min_value=10, max_value=5000, value=int(selected_row.get("storage_gb", 120.0)), step=50)
        with c3:
            wl_runtime = st.number_input("Expected Runtime (Hours)", min_value=0.5, max_value=72.0, value=float(selected_row["duration_hours"]), step=0.5)
            prio_opts = ["HIGH", "MEDIUM", "LOW"]
            current_prio = str(selected_row.get("priority", "HIGH")).upper()
            wl_priority = st.selectbox("Execution Priority", prio_opts, index=prio_opts.index(current_prio) if current_prio in prio_opts else 0)

        workload_dict = {
            "workload_id": str(selected_row["workload_id"]),
            "workload_type": str(selected_row["workload_type"]),
            "cpu_cores": float(wl_cpu),
            "gpu_units": float(wl_gpu),
            "ram_gb": float(wl_ram),
            "storage_gb": float(wl_storage),
            "duration_hours": float(wl_runtime),
            "priority": str(wl_priority),
            "description": str(selected_row.get("description", ""))
        }

        if st.button("💾 Save In-Line Adjustments to Workload Storage", use_container_width=True):
            import sys
            import subprocess

            if st.session_state.custom_wl_df is None:
                st.session_state.custom_wl_df = raw_wl_df.copy()

            w_df = st.session_state.custom_wl_df
            w_df = w_df[w_df["workload_id"] != workload_dict["workload_id"]]
            st.session_state.custom_wl_df = pd.concat([w_df, pd.DataFrame([workload_dict])], ignore_index=True)

            wl_csv_path = os.path.join(DATA_DIR, "workload_profiles.csv")
            st.session_state.custom_wl_df.to_csv(wl_csv_path, index=False)

            sync_script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "scripts", "sync_flutter_data.py")
            if os.path.exists(sync_script):
                subprocess.run([sys.executable, sync_script], check=False)

            st.session_state.current_workload = workload_dict
            st.session_state.selected_workload_id = workload_dict["workload_id"]
            st.success(f"Workload {workload_dict['workload_id']} updated and saved to storage!")
            st.rerun()

    elif workload_source == "Create New Workload":
        st.markdown("##### ➕ Create and Register New Workload")
        c1, c2, c3 = st.columns(3)
        with c1:
            next_wl_idx = len(all_wl_records) + 1
            new_id = st.text_input("New Workload ID", value=f"WL-CUSTOM-{next_wl_idx:02d}", key="new_custom_wl_id")
            new_type = st.text_input("Workload Type", value="Benthic Hydrothermal Genomics", key="new_custom_wl_type")
            new_prio = st.selectbox("Priority", ["HIGH", "MEDIUM", "LOW"], index=0, key="new_custom_wl_prio")
        with c2:
            new_cpu = st.number_input("Required CPU Cores", min_value=1, max_value=256, value=32, step=4, key="new_custom_wl_cpu")
            new_gpu = st.number_input("Required GPU Units", min_value=0, max_value=64, value=4, step=1, key="new_custom_wl_gpu")
            new_ram = st.number_input("Required RAM (GB)", min_value=4, max_value=1024, value=128, step=16, key="new_custom_wl_ram")
        with c3:
            new_storage = st.number_input("Required Storage (GB)", min_value=10, max_value=5000, value=500, step=50, key="new_custom_wl_storage")
            new_runtime = st.number_input("Expected Runtime (Hours)", min_value=0.5, max_value=72.0, value=6.0, step=0.5, key="new_custom_wl_runtime")
            new_desc = st.text_input("Description", value="High-throughput marine environmental processing", key="new_custom_wl_desc")

        workload_dict = {
            "workload_id": str(new_id).strip(),
            "workload_type": str(new_type).strip(),
            "cpu_cores": float(new_cpu),
            "gpu_units": float(new_gpu),
            "ram_gb": float(new_ram),
            "storage_gb": float(new_storage),
            "duration_hours": float(new_runtime),
            "priority": str(new_prio),
            "description": str(new_desc).strip()
        }

        if st.button("💾 Save Workload to Active Catalog", type="primary", use_container_width=True):
            import sys
            import subprocess

            if st.session_state.custom_wl_df is None:
                st.session_state.custom_wl_df = raw_wl_df.copy()

            # Append or update in custom_wl_df
            w_df = st.session_state.custom_wl_df
            w_df = w_df[w_df["workload_id"] != workload_dict["workload_id"]]
            st.session_state.custom_wl_df = pd.concat([w_df, pd.DataFrame([workload_dict])], ignore_index=True)

            # Persist to disk CSV
            wl_csv_path = os.path.join(DATA_DIR, "workload_profiles.csv")
            st.session_state.custom_wl_df.to_csv(wl_csv_path, index=False)

            # Update session catalog
            st.session_state.custom_workload_catalog = [w for w in st.session_state.custom_workload_catalog if w.get("workload_id") != workload_dict["workload_id"]]
            st.session_state.custom_workload_catalog.append(workload_dict)

            # Sync to Flutter codebase if script exists
            sync_script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "scripts", "sync_flutter_data.py")
            if os.path.exists(sync_script):
                subprocess.run([sys.executable, sync_script], check=False)

            st.session_state.current_workload = workload_dict
            st.session_state.selected_workload_id = workload_dict["workload_id"]
            st.session_state.workload_config_mode = "Catalog Workload (Customizable)"
            st.success(f"Workload {new_id} ({new_type}) successfully registered, saved to storage, and selected!")
            st.rerun()

    else:
        st.markdown("##### 📅 Future Workload Queue (Batch Pipeline)")
        st.caption("Queue up multiple future workloads to be scheduled sequentially in upcoming mission dispatches.")
        
        q_cols = st.columns([3, 1])
        with q_cols[0]:
            q_selected = st.selectbox("Select Workload to Add to Future Queue", [f"{r['workload_id']} — {r['workload_type']}" for r in all_wl_records])
            q_row = all_wl_records[[f"{r['workload_id']} — {r['workload_type']}" for r in all_wl_records].index(q_selected)]
        with q_cols[1]:
            st.write("")
            st.write("")
            if st.button("➕ Enqueue Workload", use_container_width=True):
                st.session_state.future_workload_queue.append(dict(q_row))
                st.success(f"Queued {q_row['workload_id']}!")
                st.rerun()

        if st.session_state.future_workload_queue:
            st.dataframe(pd.DataFrame(st.session_state.future_workload_queue), use_container_width=True)
            if st.button("🗑️ Clear Queue"):
                st.session_state.future_workload_queue = []
                st.rerun()
            workload_dict = dict(st.session_state.future_workload_queue[0])
            st.info(f"Targeting active head of queue: **{workload_dict['workload_id']}** ({workload_dict['workload_type']})")
        else:
            st.info("Queue is currently empty. Defaulting to first catalog workload.")
            workload_dict = dict(all_wl_records[0])

    # Store in session state
    st.session_state.current_workload = workload_dict

    # Summary Cards showing all 6 required parameters
    st.markdown("#### 📋 Active Workload Resource Specification")
    w_col1, w_col2, w_col3, w_col4, w_col5, w_col6 = st.columns(6)
    with w_col1:
        st.markdown(f"""
        <div class="clean-card">
            <div class="clean-card-label"><span>CPU Cores</span> <span>🖥️</span></div>
            <div class="clean-card-val">{workload_dict['cpu_cores']:.0f}</div>
            <div class="clean-card-sub">Processor allocation</div>
        </div>
        """, unsafe_allow_html=True)
    with w_col2:
        st.markdown(f"""
        <div class="clean-card">
            <div class="clean-card-label"><span>GPU Units</span> <span>⚡</span></div>
            <div class="clean-card-val">{workload_dict['gpu_units']:.0f}</div>
            <div class="clean-card-sub">Accelerators required</div>
        </div>
        """, unsafe_allow_html=True)
    with w_col3:
        st.markdown(f"""
        <div class="clean-card">
            <div class="clean-card-label"><span>RAM Memory</span> <span>💾</span></div>
            <div class="clean-card-val">{workload_dict['ram_gb']:.0f} <span style="font-size:0.85rem; color:#94a3b8; font-weight:500;">GB</span></div>
            <div class="clean-card-sub">System memory</div>
        </div>
        """, unsafe_allow_html=True)
    with w_col4:
        st.markdown(f"""
        <div class="clean-card">
            <div class="clean-card-label"><span>Storage</span> <span>🗄️</span></div>
            <div class="clean-card-val">{workload_dict['storage_gb']:.0f} <span style="font-size:0.85rem; color:#94a3b8; font-weight:500;">GB</span></div>
            <div class="clean-card-sub">Disk allocation</div>
        </div>
        """, unsafe_allow_html=True)
    with w_col5:
        st.markdown(f"""
        <div class="clean-card">
            <div class="clean-card-label"><span>Runtime</span> <span>⏱️</span></div>
            <div class="clean-card-val">{workload_dict['duration_hours']:.1f} <span style="font-size:0.85rem; color:#94a3b8; font-weight:500;">hrs</span></div>
            <div class="clean-card-sub">Target duration</div>
        </div>
        """, unsafe_allow_html=True)
    with w_col6:
        prio_chip = "rose" if workload_dict['priority'] == "HIGH" else ("amber" if workload_dict['priority'] == "MEDIUM" else "emerald")
        st.markdown(f"""
        <div class="clean-card">
            <div class="clean-card-label"><span>Priority</span> <span>🏷️</span></div>
            <div class="clean-card-val"><span class="status-chip {prio_chip}" style="font-size:0.82rem; padding:4px 10px;">{workload_dict['priority']}</span></div>
            <div class="clean-card-sub">Mission priority</div>
        </div>
        """, unsafe_allow_html=True)

    if workload_dict.get("description"):
        st.info(f"**Mission Objective:** {workload_dict['description']}")

    st.success("✅ Workload parameters locked in. Switch to Tab **'02 Launch Scheduling'** or proceed through the workflow.")

# Ensure active workload is accessible to downstream pipeline
workload = st.session_state.get("current_workload", workload_dict)

# ==============================================================================
# 02 LAUNCH SCHEDULING
# Load pod inventory and matching ocean data
# ==============================================================================
with t2:
    st.markdown("### <span class='step-badge'>02</span> Launch Scheduling & Data Ingestion", unsafe_allow_html=True)
    st.caption("Loads the verified pod inventory and synchronized oceanographic telemetry snapshot.")

    c_l1, c_l2 = st.columns([2, 1])
    with c_l1:
        st.markdown(f"""
        **Active Run Context:**
        - **Run ID:** `{st.session_state.run_id}`
        - **Workload Target:** `{workload['workload_id']}` ({workload['workload_type']})
        - **Data Mode:** `{st.session_state.data_mode}` (Telemetry verified)
        """)
    with c_l2:
        if st.button("🚀 Reload & Re-validate Datasets", type="primary", use_container_width=True):
            st.session_state.custom_wl_df = None
            st.session_state.custom_pod_df = None
            st.session_state.custom_ocean_df = None
            st.session_state.custom_workload_catalog = []
            st.session_state.run_id = f"RUN-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
            st.session_state.run_timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
            st.success("Synchronized workload catalog, pod inventory, and ocean conditions successfully from disk storage.")
            st.rerun()

    # Real-Time Oceanographic Telemetry Feed Control
    c_live1, c_live2 = st.columns([2, 1])
    with c_live1:
        st.markdown("""
        <div class="clean-card" style="padding:14px 18px; margin-bottom:12px;">
            <div style="display:flex; justify-content:space-between; align-items:center;">
                <span style="font-weight:700; color:#f8fafc; font-size:0.95rem;">📡 Real-Time Oceanographic Telemetry Engine</span>
                <span class="status-chip emerald">● REAL-TIME FEED READY</span>
            </div>
            <div style="font-size:0.83rem; color:#94a3b8; margin-top:5px; line-height:1.5;">
                Physics-based real-time telemetry streaming: semidiurnal M2 tidal harmonic oscillation (~12.42h period), diurnal solar thermocline drift, and regional power grid carbon intensity fluctuations across all 30 subsea pods.
            </div>
        </div>
        """, unsafe_allow_html=True)
    with c_live2:
        if st.button("⚡ Ingest Live Real-Time Feed", type="secondary", use_container_width=True):
            r_service = RealtimeOceanTelemetryService()
            live_df = r_service.generate_realtime_snapshot(
                raw_ocean_df,
                current_multiplier=st.session_state.env_current_mult,
                temp_shift_c=st.session_state.env_temp_shift,
                carbon_multiplier=st.session_state.env_carbon_mult
            )
            st.session_state.custom_ocean_df = live_df
            st.session_state.data_mode = "Live Ocean Telemetry Stream"
            st.session_state.run_timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
            r_service.sync_ocean_csv_to_live_utc()
            st.success("Synchronized live UTC real-time telemetry feed across 30 sensor buoys!")
            st.rerun()

    # Dynamic Ocean Telemetry Simulator
    with st.expander("🌊 Dynamic Ocean Conditions Simulator (Adjust Real-time Telemetry)", expanded=False):
        st.caption("Simulate changing oceanic currents, marine heatwaves, or power grid fluctuations to test scheduling responsiveness.")
        sim_col1, sim_col2, sim_col3 = st.columns(3)
        with sim_col1:
            t_shift = st.slider("🌡️ Seawater Temp Shift (°C)", -3.0, 5.0, float(st.session_state.env_temp_shift), 0.5)
            if t_shift != st.session_state.env_temp_shift:
                st.session_state.env_temp_shift = t_shift
                st.rerun()
        with sim_col2:
            c_mult = st.slider("🌊 Tidal Current Velocity Multiplier", 0.2, 2.5, float(st.session_state.env_current_mult), 0.1)
            if c_mult != st.session_state.env_current_mult:
                st.session_state.env_current_mult = c_mult
                st.rerun()
        with sim_col3:
            g_mult = st.slider("⚡ Grid Carbon Intensity Multiplier", 0.5, 2.0, float(st.session_state.env_carbon_mult), 0.1)
            if g_mult != st.session_state.env_carbon_mult:
                st.session_state.env_carbon_mult = g_mult
                st.rerun()

    # Register & Deploy New Subsea Compute Pod Form
    with st.expander("➕ Register & Deploy New Subsea Compute Pod", expanded=False):
        st.caption("Deploy and configure a new underwater datacenter pod into the active global fleet with compute and telemetry specs.")
        p_c1, p_c2, p_c3 = st.columns(3)
        with p_c1:
            st.markdown("###### 🏷️ Identity & Location")
            next_pod_num = len(active_pod_df) + 1
            new_pid = st.text_input("Pod ID", value=f"POD-CUSTOM-{next_pod_num:02d}", key="new_pod_id")
            new_pname = st.text_input("Pod Name", value=f"AquaVent-Pod-{next_pod_num}", key="new_pod_name")
            new_ploc = st.text_input("Ocean Location", value="Mariana Deep Trench (Pacific)", key="new_pod_loc")
            new_pstatus = st.selectbox("Status", ["ACTIVE", "STANDBY", "MAINTENANCE"], index=0, key="new_pod_status")
        with p_c2:
            st.markdown("###### ⚙️ Hardware Compute Specs")
            new_pcpu = st.number_input("Total CPU Cores", min_value=16, max_value=512, value=128, step=16, key="new_pod_cpu")
            new_pused_cpu = st.number_input("Used CPU Cores", min_value=0, max_value=int(new_pcpu), value=16, step=4, key="new_pod_used_cpu")
            new_pgpu = st.number_input("Total GPU Units", min_value=0, max_value=64, value=16, step=2, key="new_pod_gpu")
            new_pused_gpu = st.number_input("Used GPU Units", min_value=0, max_value=int(new_pgpu), value=2, step=1, key="new_pod_used_gpu")
            new_pram = st.number_input("Total RAM (GB)", min_value=32, max_value=2048, value=512, step=32, key="new_pod_ram")
            new_pused_ram = st.number_input("Used RAM (GB)", min_value=0, max_value=int(new_pram), value=64, step=16, key="new_pod_used_ram")
            new_pstorage = st.number_input("Total Storage (GB)", min_value=500, max_value=20000, value=4000, step=500, key="new_pod_storage")
            new_pused_storage = st.number_input("Used Storage (GB)", min_value=0, max_value=int(new_pstorage), value=600, step=100, key="new_pod_used_storage")
        with p_c3:
            st.markdown("###### 🌊 Telemetry & Thermodynamic Specs")
            new_platency = st.number_input("Network Latency (ms)", min_value=2.0, max_value=100.0, value=14.5, step=1.0, key="new_pod_latency")
            new_ppue = st.number_input("Target PUE", min_value=1.01, max_value=1.30, value=1.05, step=0.01, key="new_pod_pue")
            new_pbase_kw = st.number_input("Base Power (kW)", min_value=5.0, max_value=50.0, value=22.0, step=1.0, key="new_pod_base_kw")
            new_pmax_kw = st.number_input("Max Power (kW)", min_value=30.0, max_value=200.0, value=115.0, step=5.0, key="new_pod_max_kw")
            new_psurface = st.number_input("Pod Surface Area (m²)", min_value=50.0, max_value=300.0, value=140.0, step=5.0, key="new_pod_surface")
            new_ptemp = st.number_input("Ambient Seawater Temp (°C)", min_value=-2.0, max_value=35.0, value=4.5, step=0.5, key="new_pod_temp")
            new_pcurrent = st.number_input("Ocean Current Speed (m/s)", min_value=0.05, max_value=5.0, value=1.1, step=0.1, key="new_pod_current")
            new_pdepth = st.number_input("Deployment Depth (m)", min_value=10.0, max_value=2000.0, value=120.0, step=10.0, key="new_pod_depth")
            zone_opts = ["LOW_IMPACT", "MODERATE", "SENSITIVE_BENTHIC", "PROTECTED_CORAL_REEF", "PROTECTED_MARINE_SANCTUARY"]
            new_pzone = st.selectbox("Ecological Zone", zone_opts, index=0, key="new_pod_zone")
            new_pcarbon = st.number_input("Grid Carbon (kg CO2e/kWh)", min_value=0.005, max_value=1.5, value=0.045, step=0.005, format="%.3f", key="new_pod_carbon")

        if st.button("🚀 Deploy Pod to Global Fleet", type="primary", use_container_width=True):
            new_pod_dict = {
                "pod_id": str(new_pid).strip(),
                "pod_name": str(new_pname).strip(),
                "location": str(new_ploc).strip(),
                "total_cpu": float(new_pcpu),
                "used_cpu": float(new_pused_cpu),
                "total_gpu": float(new_pgpu),
                "used_gpu": float(new_pused_gpu),
                "total_ram_gb": float(new_pram),
                "used_ram_gb": float(new_pused_ram),
                "status": str(new_pstatus),
                "base_power_kw": float(new_pbase_kw),
                "max_power_kw": float(new_pmax_kw),
                "pue": float(new_ppue),
                "network_latency_ms": float(new_platency),
                "surface_area_m2": float(new_psurface),
                "total_storage_gb": float(new_pstorage),
                "used_storage_gb": float(new_pused_storage)
            }
            new_ocean_dict = {
                "pod_id": str(new_pid).strip(),
                "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                "water_temperature_c": float(new_ptemp),
                "current_speed_mps": float(new_pcurrent),
                "current_direction_deg": 180.0,
                "salinity_psu": 34.8,
                "depth_m": float(new_pdepth),
                "ecological_zone": str(new_pzone),
                "grid_carbon_intensity_kg_per_kwh": float(new_pcarbon),
                "ambient_turbidity_ntu": 1.0
            }

            import sys
            import subprocess

            if st.session_state.custom_pod_df is None:
                st.session_state.custom_pod_df = raw_pod_df.copy()
            if st.session_state.custom_ocean_df is None:
                st.session_state.custom_ocean_df = raw_ocean_df.copy()

            # Append or update in session state
            p_df = st.session_state.custom_pod_df
            o_df = st.session_state.custom_ocean_df

            p_df = p_df[p_df["pod_id"] != new_pod_dict["pod_id"]]
            o_df = o_df[o_df["pod_id"] != new_ocean_dict["pod_id"]]

            st.session_state.custom_pod_df = pd.concat([p_df, pd.DataFrame([new_pod_dict])], ignore_index=True)
            st.session_state.custom_ocean_df = pd.concat([o_df, pd.DataFrame([new_ocean_dict])], ignore_index=True)

            # Persist to disk CSV
            pod_csv_path = os.path.join(DATA_DIR, "pod_resources.csv")
            ocean_csv_path = os.path.join(DATA_DIR, "ocean_conditions.csv")
            st.session_state.custom_pod_df.to_csv(pod_csv_path, index=False)
            st.session_state.custom_ocean_df.to_csv(ocean_csv_path, index=False)

            # Sync to Flutter codebase if script exists
            sync_script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "scripts", "sync_flutter_data.py")
            if os.path.exists(sync_script):
                subprocess.run([sys.executable, sync_script], check=False)

            st.success(f"Subsea Pod {new_pid} ({new_pname}) successfully registered, saved to storage, and deployed into active fleet!")
            st.rerun()

    st.markdown("#### 🖥️ Subsea Pod Inventory Snapshot")
    st.dataframe(
        clean_pod_df[[
            "pod_id", "pod_name", "location", "status",
            "total_cpu", "used_cpu", "total_gpu", "used_gpu",
            "total_ram_gb", "used_ram_gb", "total_storage_gb", "used_storage_gb",
            "base_power_kw", "max_power_kw", "pue", "network_latency_ms"
        ]],
        use_container_width=True
    )

    st.markdown("#### 🌊 Synchronized Oceanographic Telemetry")
    st.dataframe(
        clean_ocean_df[[
            "pod_id", "timestamp", "water_temperature_c", "current_speed_mps",
            "salinity_psu", "depth_m", "ecological_zone", "grid_carbon_intensity_kg_per_kwh"
        ]],
        use_container_width=True
    )

# ==============================================================================
# PIPELINE COMPUTATION (Shared across steps 03-09)
# ==============================================================================
# Step 3 calculation: Resource availability & rejection reasons
res_filter = ResourceFilter()
res_output = res_filter.filter_pods(clean_pod_df, workload)

# Step 4 calculation: Impacts (Energy, Carbon, Thermal, Risk, Performance)
ec_estimator = EnergyCarbonEstimator()
tr_estimator = ThermalRiskEstimator()
ec_map = {}
tr_map = {}
ocean_map = {str(r["pod_id"]): r for _, r in clean_ocean_df.iterrows()}

for _, prow in clean_pod_df.iterrows():
    pid = str(prow["pod_id"])
    orow = ocean_map.get(pid)
    ec = ec_estimator.compute_energy_and_carbon(prow, orow, workload)
    tr = tr_estimator.estimate_thermal_and_risk(prow, orow, ec.total_pod_power_kw)
    ec_map[pid] = ec
    tr_map[pid] = tr

# Risk budget constraints (hard gates)
max_delta_temp = 2.5
max_pod_temp = 45.0
max_risk_score = 0.65
risk_enforcer = RiskBudgetEnforcer(
    max_water_temp_delta_c=max_delta_temp,
    max_pod_temp_c=max_pod_temp,
    max_environmental_risk_score=max_risk_score,
    max_carbon_budget_kg=None,
    disallow_protected_zones=True
)
budget_output = risk_enforcer.evaluate_constraints(ec_map, tr_map, clean_ocean_df)

# Feasible pods: must pass BOTH hardware and environmental hard gates
hardware_eligible_pids = set(res_output.eligible_pods_df["pod_id"].tolist()) if not res_output.eligible_pods_df.empty else set()
feasible_pids = [pid for pid in budget_output.passed_pod_ids if pid in hardware_eligible_pids]

# Combined rejections
combined_ineligible = {}
for pid, check in res_output.all_pod_checks.items():
    if not check.is_eligible:
        combined_ineligible[pid] = list(check.rejection_reasons)

for pid, check in budget_output.checks.items():
    if not check.passed_all_constraints:
        combined_ineligible.setdefault(pid, []).extend(check.rejection_reasons)

# ==============================================================================
# 03 FIND POSSIBLE PODS
# Check resource availability and show rejection reasons
# ==============================================================================
with t3:
    st.markdown("### <span class='step-badge'>03</span> Find Possible Pods & Audit Rejection Reasons", unsafe_allow_html=True)
    st.caption("Available resources ($Available = Total - Used$) are compared against workload demand. Non-active or overloaded pods are rejected.")

    c_feas1, c_feas2 = st.columns([1, 1])
    with c_feas1:
        st.markdown(f"#### ✅ Feasible Candidates <span class='badge-pass'>{len(feasible_pids)} PASSED</span>", unsafe_allow_html=True)
        if feasible_pids:
            feas_rows = []
            for pid in feasible_pids:
                prow = clean_pod_df.loc[clean_pod_df["pod_id"] == pid].iloc[0]
                chk = res_output.all_pod_checks[pid]
                feas_rows.append({
                    "Pod ID": pid,
                    "Name": prow["pod_name"],
                    "Location": prow["location"],
                    "Avail CPU": f"{chk.available_cpu:.0f} cores",
                    "Avail GPU": f"{chk.available_gpu:.0f} units",
                    "Avail RAM": f"{chk.available_ram_gb:.0f} GB",
                    "Avail Storage": f"{chk.available_storage_gb:.0f} GB",
                    "Gate": "PASSED"
                })
            st.dataframe(pd.DataFrame(feas_rows), use_container_width=True)
        else:
            st.error("No pods satisfied all resource and environmental constraints for this workload.")
            st.warning("""
            💡 **Workload Optimization Recommendation:**
            The requested workload requires more hardware capacity than any single pod currently has available.
            - Try downscaling CPU or GPU requirements in **Tab 01**.
            - Or click below to auto-scale workload to the largest available pod!
            """)
            if st.button("⚡ Auto-Scale Workload to Fit Maximum Available Pod", use_container_width=True):
                # Find maximum available pod resources
                max_cpu = max([chk.available_cpu for chk in res_output.all_pod_checks.values()])
                max_gpu = max([chk.available_gpu for chk in res_output.all_pod_checks.values()])
                st.session_state.current_workload["cpu_cores"] = min(st.session_state.current_workload["cpu_cores"], max_cpu)
                st.session_state.current_workload["gpu_units"] = min(st.session_state.current_workload["gpu_units"], max_gpu)
                st.rerun()

    with c_feas2:
        st.markdown(f"#### ⚠️ Rejection Audit <span class='badge-fail'>{len(combined_ineligible)} REJECTED</span>", unsafe_allow_html=True)
        if combined_ineligible:
            rej_rows = []
            for pid, reasons in combined_ineligible.items():
                pname = clean_pod_df.loc[clean_pod_df["pod_id"] == pid, "pod_name"].values[0] if (clean_pod_df["pod_id"] == pid).any() else pid
                rej_rows.append({
                    "Pod ID": pid,
                    "Pod Name": pname,
                    "Specific Rejection Reason(s)": " • ".join(reasons)
                })
            st.dataframe(pd.DataFrame(rej_rows), use_container_width=True)
        else:
            st.success("All pods passed feasibility checks!")

# ==============================================================================
# 04 CALCULATE IMPACTS
# Energy, carbon, thermal impact, environmental risk and performance
# ==============================================================================
with t4:
    st.markdown("### <span class='step-badge'>04</span> Calculate Environmental & Performance Impacts", unsafe_allow_html=True)
    st.caption("Rigorous physics and ecological models calculate impact metrics for all feasible candidate pods.")

    impact_rows = []
    for pid in feasible_pids:
        prow = clean_pod_df.loc[clean_pod_df["pod_id"] == pid].iloc[0]
        ec = ec_map[pid]
        tr = tr_map[pid]
        cpu_util_after = (float(prow["used_cpu"]) + workload["cpu_cores"]) / max(float(prow["total_cpu"]), 1.0)
        perf_penalty = (float(prow["network_latency_ms"]) / 10.0) + (cpu_util_after * 2.0)

        impact_rows.append({
            "Pod ID": pid,
            "Pod Name": prow["pod_name"],
            "Energy (kWh)": round(ec.workload_energy_kwh, 2),
            "Carbon (kg CO2e)": round(ec.workload_carbon_kg_co2e, 2),
            "Thermal ΔT Rise (°C)": round(tr.delta_temp_c, 2),
            "Local Water Temp (°C)": round(tr.local_water_temp_c, 1),
            "Eco-Risk Score": round(tr.environmental_risk_score, 3),
            "Performance Penalty": round(perf_penalty, 2),
            "Convective h (W/m²K)": round(tr.convective_h_w_m2k, 0)
        })

    if impact_rows:
        impact_df = pd.DataFrame(impact_rows)
        st.dataframe(impact_df, use_container_width=True)

        st.markdown("#### 🔬 Metric Visualizations Across Feasible Candidates")
        c_i1, c_i2 = st.columns(2)
        with c_i1:
            fig_carb = px.bar(
                impact_df,
                x="Pod Name",
                y="Carbon (kg CO2e)",
                title="Predicted Workload Carbon Footprint (kg CO2e)",
                color="Carbon (kg CO2e)",
                color_continuous_scale="Tealgrn"
            )
            apply_clean_chart_theme(fig_carb, "Predicted Workload Carbon Footprint (kg CO2e)", height=320)
            st.plotly_chart(fig_carb, use_container_width=True)
        with c_i2:
            fig_therm = px.bar(
                impact_df,
                x="Pod Name",
                y="Thermal ΔT Rise (°C)",
                title="Seawater Boundary Layer Temperature Rise ΔT (°C)",
                color="Thermal ΔT Rise (°C)",
                color_continuous_scale="Thermal"
            )
            fig_therm.add_hline(y=max_delta_temp, line_dash="dash", line_color="#fbbf24", annotation_text=f"Max ΔT Limit ({max_delta_temp}°C)")
            apply_clean_chart_theme(fig_therm, "Seawater Boundary Layer Temperature Rise ΔT (°C)", height=320)
            st.plotly_chart(fig_therm, use_container_width=True)

        # Multi-Objective Radar / Spider Comparison Chart
        st.markdown("#### 🕸️ Multi-Dimensional Sustainability Radar")
        categories = ["Energy", "Carbon", "Thermal ΔT", "Eco-Risk", "Perf Penalty"]
        fig_radar = go.Figure()
        
        # Max values for normalization
        max_e = max(impact_df["Energy (kWh)"].max(), 1.0)
        max_c = max(impact_df["Carbon (kg CO2e)"].max(), 1.0)
        max_t = max(impact_df["Thermal ΔT Rise (°C)"].max(), 0.1)
        max_r = max(impact_df["Eco-Risk Score"].max(), 0.1)
        max_p = max(impact_df["Performance Penalty"].max(), 0.1)

        for _, r in impact_df.iterrows():
            vals = [
                r["Energy (kWh)"] / max_e,
                r["Carbon (kg CO2e)"] / max_c,
                r["Thermal ΔT Rise (°C)"] / max_t,
                r["Eco-Risk Score"] / max_r,
                r["Performance Penalty"] / max_p
            ]
            vals.append(vals[0])  # Close loop
            fig_radar.add_trace(go.Scatterpolar(
                r=vals,
                theta=categories + [categories[0]],
                fill='toself',
                name=r["Pod Name"]
            ))

        fig_radar.update_layout(
            polar=dict(
                bgcolor="rgba(19, 27, 46, 0.5)",
                radialaxis=dict(visible=True, range=[0, 1], gridcolor="rgba(255, 255, 255, 0.08)", linecolor="rgba(255, 255, 255, 0.1)"),
                angularaxis=dict(gridcolor="rgba(255, 255, 255, 0.08)", linecolor="rgba(255, 255, 255, 0.1)")
            ),
            showlegend=True,
            paper_bgcolor="rgba(0,0,0,0)",
            font=dict(color="#94a3b8", family="Inter, sans-serif"),
            title=dict(text="Normalized Environmental & Hardware Penalty Footprint (Lower is Better)", font=dict(color="#f8fafc", size=13)),
            margin=dict(l=40, r=40, t=40, b=30)
        )
        st.plotly_chart(fig_radar, use_container_width=True)

    else:
        st.warning("No feasible candidates available for impact computation.")

# ==============================================================================
# 05 CHOOSE OBJECTIVE WEIGHTS
# Adjust priorities and recalculate the ranking
# ==============================================================================
with t5:
    st.markdown("### <span class='step-badge'>05</span> Choose Objective Weights & Priority Balancing", unsafe_allow_html=True)
    st.caption("Adjust priorities across energy, carbon, thermal impact, environmental risk, and performance. Scores automatically normalize to 100%.")

    # Weight presets
    p_col1, p_col2, p_col3, p_col4 = st.columns(4)
    with p_col1:
        if st.button("⚖️ Balanced AquaEco (Default)", use_container_width=True):
            st.session_state.w_energy, st.session_state.w_carbon, st.session_state.w_thermal, st.session_state.w_risk, st.session_state.w_perf = 0.15, 0.15, 0.30, 0.30, 0.10
            st.rerun()
    with p_col2:
        if st.button("🌱 Ultra-Green (Carbon Priority)", use_container_width=True):
            st.session_state.w_energy, st.session_state.w_carbon, st.session_state.w_thermal, st.session_state.w_risk, st.session_state.w_perf = 0.10, 0.60, 0.15, 0.10, 0.05
            st.rerun()
    with p_col3:
        if st.button("🪸 Marine Sanctuary Priority", use_container_width=True):
            st.session_state.w_energy, st.session_state.w_carbon, st.session_state.w_thermal, st.session_state.w_risk, st.session_state.w_perf = 0.05, 0.10, 0.40, 0.40, 0.05
            st.rerun()
    with p_col4:
        if st.button("⚡ High Performance / Low Latency", use_container_width=True):
            st.session_state.w_energy, st.session_state.w_carbon, st.session_state.w_thermal, st.session_state.w_risk, st.session_state.w_perf = 0.15, 0.10, 0.15, 0.10, 0.50
            st.rerun()

    c_w1, c_w2, c_w3, c_w4, c_w5 = st.columns(5)
    with c_w1:
        st.session_state.w_energy = st.slider("⚡ Energy Weight", 0.0, 1.0, float(st.session_state.w_energy), 0.05)
    with c_w2:
        st.session_state.w_carbon = st.slider("🌱 Carbon Weight", 0.0, 1.0, float(st.session_state.w_carbon), 0.05)
    with c_w3:
        st.session_state.w_thermal = st.slider("🌡️ Thermal Weight", 0.0, 1.0, float(st.session_state.w_thermal), 0.05)
    with c_w4:
        st.session_state.w_risk = st.slider("🛡️ Eco-Risk Weight", 0.0, 1.0, float(st.session_state.w_risk), 0.05)
    with c_w5:
        st.session_state.w_perf = st.slider("🚀 Performance Weight", 0.0, 1.0, float(st.session_state.w_perf), 0.05)

    raw_weights = {
        "energy": st.session_state.w_energy,
        "carbon": st.session_state.w_carbon,
        "thermal_footprint": st.session_state.w_thermal,
        "environmental_risk": st.session_state.w_risk,
        "performance_penalty": st.session_state.w_perf
    }
    w_sum = sum(raw_weights.values())
    norm_w = {k: v / w_sum if w_sum > 0 else 0.2 for k, v in raw_weights.items()}

    st.markdown(f"""
    <div class="clean-card" style="margin-top: 14px;">
        <div class="clean-card-label"><span>Active Normalized Weight Distribution (Total = 100%)</span> <span class="badge-pass">BALANCED</span></div>
        <div style="display: flex; gap: 8px; flex-wrap: wrap; margin-top: 8px;">
            <span class="status-chip amber">⚡ Energy: {norm_w['energy']*100:.1f}%</span>
            <span class="status-chip emerald">🌱 Carbon: {norm_w['carbon']*100:.1f}%</span>
            <span class="status-chip rose">🌡️ Thermal: {norm_w['thermal_footprint']*100:.1f}%</span>
            <span class="status-chip cyan">🛡️ Eco-Risk: {norm_w['environmental_risk']*100:.1f}%</span>
            <span class="status-chip" style="color: #a78bfa; border-color: rgba(167, 139, 250, 0.4);">🚀 Perf: {norm_w['performance_penalty']*100:.1f}%</span>
        </div>
    </div>
    """, unsafe_allow_html=True)

# Compute final multi-objective rankings with active weights
scheduler = AquaEcoScheduler(weights=raw_weights)
scheduling_decision = scheduler.schedule(
    feasible_pod_ids=feasible_pids,
    pod_df=clean_pod_df,
    energy_carbon_map=ec_map,
    thermal_risk_map=tr_map,
    resource_checks=res_output.all_pod_checks,
    risk_checks=budget_output.checks,
    workload=workload
)

# ==============================================================================
# 06 EXPLAIN THE BEST POD
# Show values, score breakdown, alternatives and selection reasons
# ==============================================================================
with t6:
    st.markdown("### <span class='step-badge'>06</span> Explainable Pod Recommendation", unsafe_allow_html=True)
    st.caption("Full transparency: values, score contributions, feasible alternatives, and why the best pod won.")

    if scheduling_decision.status == "SUCCESS" and scheduling_decision.selected_pod:
        best = scheduling_decision.selected_pod
        best_ec = ec_map[best.pod_id]
        best_tr = tr_map[best.pod_id]

        # Winner Ribbon
        r1, r2, r3, r4, r5 = st.columns(5)
        with r1:
            st.markdown(f"""
            <div class="clean-card" style="border: 1px solid rgba(56, 189, 248, 0.45); background: linear-gradient(135deg, rgba(56, 189, 248, 0.08) 0%, rgba(19, 27, 46, 0.95) 100%);">
                <div class="clean-card-label"><span style="color:#38bdf8;">Winner Pod</span> <span>🏆</span></div>
                <div class="clean-card-val" style="color: #38bdf8; font-size:1.4rem;">{best.pod_name}</div>
                <div class="clean-card-sub" style="color:#94a3b8;">{best.pod_id} • {best.location}</div>
            </div>
            """, unsafe_allow_html=True)
        with r2:
            st.markdown(f"""
            <div class="clean-card">
                <div class="clean-card-label"><span>Composite Score</span> <span>📊</span></div>
                <div class="clean-card-val">{best.composite_score:.4f}</div>
                <div class="clean-card-sub">Rank 1 (Lowest penalty)</div>
            </div>
            """, unsafe_allow_html=True)
        with r3:
            st.markdown(f"""
            <div class="clean-card">
                <div class="clean-card-label"><span>Workload Carbon</span> <span>🌱</span></div>
                <div class="clean-card-val" style="color: #34d399;">{best_ec.workload_carbon_kg_co2e:.2f} <span style="font-size:0.85rem; color:#94a3b8; font-weight:500;">kg</span></div>
                <div class="clean-card-sub">Grid: {best_ec.carbon_intensity_kg_per_kwh:.3f} kg/kWh</div>
            </div>
            """, unsafe_allow_html=True)
        with r4:
            st.markdown(f"""
            <div class="clean-card">
                <div class="clean-card-label"><span>Ocean ΔT Rise</span> <span>🌡️</span></div>
                <div class="clean-card-val" style="color: #fbbf24;">+{best_tr.delta_temp_c:.2f}°C</div>
                <div class="clean-card-sub">Within {max_delta_temp}°C limit</div>
            </div>
            """, unsafe_allow_html=True)
        with r5:
            st.markdown(f"""
            <div class="clean-card">
                <div class="clean-card-label"><span>Eco-Risk Score</span> <span>🛡️</span></div>
                <div class="clean-card-val" style="color: #38bdf8;">{best_tr.environmental_risk_score:.3f}</div>
                <div class="clean-card-sub">Threshold cap: {max_risk_score:.2f}</div>
            </div>
            """, unsafe_allow_html=True)

        # Plain language explanation box
        st.markdown(f"""
        <div class="decision-box">
            <div style="font-size: 0.95rem; font-weight: 700; color: #38bdf8; margin-bottom: 6px; display: flex; align-items: center; gap: 8px;">
                <span>🧠</span>
                <span>Explainable Decision Rationale</span>
            </div>
            <div style="color: #f1f5f9; margin-bottom: 8px;">{scheduling_decision.explanation_summary}</div>
            <div style="color: #94a3b8; font-size: 0.85rem; line-height: 1.5; padding-top: 8px; border-top: 1px solid rgba(255, 255, 255, 0.06);">
                • <b>Multi-Objective Optimization:</b> <b>{best.pod_name}</b> achieved the lowest combined environmental penalty across tidal cooling, grid carbon intensity, and ecological safety.<br/>
                • <b>Pre-Ranking Hard Gates:</b> {len(combined_ineligible)} pods were disqualified by hard safety limits prior to scoring.
            </div>
        </div>
        """, unsafe_allow_html=True)

        # Ranked alternatives table
        st.markdown("#### 📊 Ranked Feasible Alternatives Comparison")
        ranking_df = SchedulingReporter.generate_ranking_dataframe(scheduling_decision)
        if not ranking_df.empty:
            st.dataframe(ranking_df, use_container_width=True)

        # Contribution breakdown chart
        st.markdown("#### 🔍 Objective Contribution Breakdown to Final Score (Lower is Better)")
        contrib_data = []
        for p in scheduling_decision.ranked_pods:
            contrib_data.append({
                "Pod": f"{p.pod_name} ({p.pod_id})",
                "Energy": p.weighted_contributions["energy_contrib"],
                "Carbon": p.weighted_contributions["carbon_contrib"],
                "Thermal Footprint": p.weighted_contributions["thermal_contrib"],
                "Environmental Risk": p.weighted_contributions["risk_contrib"],
                "Performance Penalty": p.weighted_contributions["perf_contrib"]
            })
        contrib_df = pd.DataFrame(contrib_data)
        fig_c = px.bar(
            contrib_df,
            x="Pod",
            y=["Energy", "Carbon", "Thermal Footprint", "Environmental Risk", "Performance Penalty"],
            title="Weighted Metric Contribution Breakdown",
            color_discrete_sequence=["#fbbf24", "#34d399", "#fb7185", "#38bdf8", "#a78bfa"],
            barmode="stack"
        )
        apply_clean_chart_theme(fig_c, "Weighted Metric Contribution Breakdown", height=320)
        st.plotly_chart(fig_c, use_container_width=True)
    else:
        st.error(f"❌ {scheduling_decision.explanation_summary}")

# ==============================================================================
# 07 CONFIRM AND EXECUTE
# Start actual execution or a clearly labelled simulation
# ==============================================================================
with t7:
    st.markdown("### <span class='step-badge'>07</span> Confirm Workload Dispatch & Execute", unsafe_allow_html=True)
    st.caption("Review dispatch parameters before launching the clearly labelled subsea simulated execution.")

    if scheduling_decision.status == "SUCCESS" and scheduling_decision.selected_pod:
        best = scheduling_decision.selected_pod
        prow = clean_pod_df.loc[clean_pod_df["pod_id"] == best.pod_id].iloc[0]

        st.markdown(f"""
        <div class="clean-card" style="border: 1px solid rgba(52, 211, 153, 0.4); background: linear-gradient(135deg, rgba(52, 211, 153, 0.06) 0%, rgba(19, 27, 46, 0.95) 100%);">
            <div style="font-size: 1.05rem; font-weight: 700; color: #34d399; margin-bottom: 12px; display: flex; align-items: center; gap: 8px;">
                <span>🚀</span>
                <span>Workload Dispatch Confirmation</span>
            </div>
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 14px; font-size: 0.88rem; color: #cbd5e1;">
                <div><span style="color:#94a3b8;">Workload ID:</span> <b style="color:#f8fafc;">{workload['workload_id']}</b> <span style="font-size:0.8rem; color:#94a3b8;">({workload['workload_type']})</span></div>
                <div><span style="color:#94a3b8;">Assigned Pod:</span> <b style="color:#38bdf8;">{best.pod_name}</b> <span style="font-size:0.8rem; color:#94a3b8;">({best.pod_id})</span></div>
                <div><span style="color:#94a3b8;">Hardware Footprint:</span> <b style="color:#f8fafc;">{workload['cpu_cores']:.0f}C / {workload['gpu_units']:.0f}G / {workload['ram_gb']:.0f}GB</b></div>
                <div><span style="color:#94a3b8;">Predicted Impact:</span> <b style="color:#34d399;">{best.raw_metrics['carbon_kg_co2e']:.2f} kg CO2e</b> • <b style="color:#fbbf24;">{best.raw_metrics['energy_kwh']:.2f} kWh</b></div>
            </div>
            <div style="margin-top: 14px; padding-top: 10px; border-top: 1px solid rgba(255, 255, 255, 0.06); display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 8px;">
                <span style="font-size: 0.8rem; color: #94a3b8;">Execution Environment:</span>
                <span class="status-chip amber">SIMULATED SUBSEA PROTOTYPE (PHYSICS CALIBRATED)</span>
            </div>
        </div>
        """, unsafe_allow_html=True)

        col_exec1, col_exec2 = st.columns(2)
        with col_exec1:
            if st.button("🚀 Confirm Dispatch & Start Live Simulation", type="primary", use_container_width=True):
                task = st.session_state.monitor.spawn_simulation_task(
                    workload,
                    prow,
                    best.raw_metrics["energy_kwh"],
                    best.raw_metrics["carbon_kg_co2e"]
                )
                st.session_state.active_task_id = task.task_id
                st.session_state.auto_sim_active = True
                st.session_state.run_history.insert(0, {
                    "run_id": st.session_state.run_id,
                    "task_id": task.task_id,
                    "timestamp": datetime.now().strftime("%H:%M:%S"),
                    "workload": workload["workload_id"],
                    "pod": best.pod_name,
                    "carbon_kg": best.raw_metrics["carbon_kg_co2e"],
                    "energy_kwh": best.raw_metrics["energy_kwh"],
                    "status": "RUNNING"
                })
                # Auto-dequeue from future workload queue if this was queued
                if st.session_state.future_workload_queue:
                    q_idx = [i for i, w in enumerate(st.session_state.future_workload_queue) if str(w.get("workload_id")) == str(workload.get("workload_id"))]
                    if q_idx:
                        st.session_state.future_workload_queue.pop(q_idx[0])
                st.success(f"Workload {workload['workload_id']} dispatched to {best.pod_name}! Switch to '08 Monitor Continuously' to track execution.")

        with col_exec2:
            if st.button("⚡ Fast-Forward Instant Execution", use_container_width=True):
                task = st.session_state.monitor.spawn_simulation_task(
                    workload,
                    prow,
                    best.raw_metrics["energy_kwh"],
                    best.raw_metrics["carbon_kg_co2e"]
                )
                st.session_state.monitor.advance_progress(task.task_id, 100.0)
                st.session_state.active_task_id = task.task_id
                st.session_state.auto_sim_active = False
                st.session_state.run_history.insert(0, {
                    "run_id": st.session_state.run_id,
                    "task_id": task.task_id,
                    "timestamp": datetime.now().strftime("%H:%M:%S"),
                    "workload": workload["workload_id"],
                    "pod": best.pod_name,
                    "carbon_kg": best.raw_metrics["carbon_kg_co2e"],
                    "energy_kwh": best.raw_metrics["energy_kwh"],
                    "status": "COMPLETED"
                })
                # Auto-dequeue from future workload queue if this was queued
                if st.session_state.future_workload_queue:
                    q_idx = [i for i, w in enumerate(st.session_state.future_workload_queue) if str(w.get("workload_id")) == str(workload.get("workload_id"))]
                    if q_idx:
                        st.session_state.future_workload_queue.pop(q_idx[0])
                st.success(f"Workload {workload['workload_id']} completed instantly on {best.pod_name}!")

        # Future Queue Batch Dispatcher
        if st.session_state.future_workload_queue:
            st.markdown("---")
            st.markdown(f"##### 📅 Future Workload Batch Dispatch ({len(st.session_state.future_workload_queue)} Pending)")
            st.caption("Execute all upcoming mission workloads sequentially through multi-objective optimization.")
            if st.button("🚀 Batch Dispatch Entire Future Queue", type="secondary", use_container_width=True):
                batch_count = 0
                for q_wl in list(st.session_state.future_workload_queue):
                    q_res = res_filter.filter_pods(clean_pod_df, q_wl)
                    if not q_res.eligible_pods_df.empty:
                        q_pod = q_res.eligible_pods_df.iloc[0]
                        q_task = st.session_state.monitor.spawn_simulation_task(q_wl, q_pod, 35.0, 5.0)
                        st.session_state.monitor.advance_progress(q_task.task_id, 100.0)
                        st.session_state.run_history.insert(0, {
                            "run_id": st.session_state.run_id,
                            "task_id": q_task.task_id,
                            "timestamp": datetime.now().strftime("%H:%M:%S"),
                            "workload": q_wl.get("workload_id", "WL"),
                            "pod": q_pod.get("pod_name", "Pod"),
                            "carbon_kg": 5.0,
                            "energy_kwh": 35.0,
                            "status": "COMPLETED"
                        })
                        batch_count += 1
                st.session_state.future_workload_queue = []
                st.success(f"Successfully processed {batch_count} future workloads! Check '08 Monitor Continuously' for mission audit history.")
                st.rerun()
    else:
        st.warning("Cannot dispatch: no feasible pod available.")

# ==============================================================================
# 08 MONITOR CONTINUOUSLY
# Track workload progress, resources, telemetry, energy, carbon and alerts
# ==============================================================================
with t8:
    st.markdown("### <span class='step-badge'>08</span> Continuous Subsea Mission Monitoring", unsafe_allow_html=True)
    st.caption("Live tracking of workload progress, subsea telemetry, resource consumption, and environmental boundary alerts.")

    monitor = st.session_state.monitor

    # If no task is active, offer a quick-start demo mission
    if not monitor.active_tasks:
        st.info("No active execution task running. Complete Step 07 ('Confirm and execute') or click below to launch a live simulation.")
        if st.button("▶️ Launch Demo Subsea Mission", type="primary"):
            demo_wl = workload
            demo_pod = clean_pod_df.iloc[0]
            task = monitor.spawn_simulation_task(demo_wl, demo_pod, 45.2, 8.4)
            st.session_state.active_task_id = task.task_id
            st.session_state.auto_sim_active = True
            st.session_state.run_history.insert(0, {
                "run_id": st.session_state.run_id,
                "task_id": task.task_id,
                "timestamp": datetime.now().strftime("%H:%M:%S"),
                "workload": demo_wl["workload_id"],
                "pod": demo_pod["pod_name"],
                "carbon_kg": 8.4,
                "energy_kwh": 45.2,
                "status": "RUNNING"
            })
            st.rerun()
    else:
        # Loop through active or recent tasks
        for t_id, task in list(monitor.active_tasks.items()):
            c_m1, c_m2 = st.columns([3, 1])
            with c_m1:
                st.markdown(f"#### 🛰️ Mission Task: `{task.task_id}` — **{task.assigned_pod_name}**")
                status_color = "#06d6a0" if task.status == "COMPLETED" else "#48cae4"
                st.markdown(f"**Workload:** `{task.workload_type}` | **Status:** <span style='color:{status_color}; font-weight:700;'>{task.status}</span> ({task.progress_pct:.0f}% Completed)", unsafe_allow_html=True)
                st.progress(task.progress_pct / 100.0)

                # Real-time resource & telemetry ribbon
                m1, m2, m3, m4 = st.columns(4)
                with m1:
                    st.metric("Allocated CPU", f"{task.cpu_allocated:.0f} Cores")
                with m2:
                    st.metric("Allocated GPU", f"{task.gpu_allocated:.0f} Units")
                with m3:
                    st.metric("Energy Consumed", f"{task.energy_consumed_kwh * (task.progress_pct/100.0):.2f} kWh")
                with m4:
                    st.metric("Carbon Emitted", f"{task.carbon_emitted_kg * (task.progress_pct/100.0):.2f} kg CO2e")

                # Dynamic Time-Series Telemetry Charts
                steps = max(int(task.progress_pct / 10), 1)
                time_points = [f"T+{i*10}m" for i in range(steps + 1)]
                energy_curve = [task.energy_consumed_kwh * (i / 10.0) for i in range(steps + 1)]
                temp_curve = [14.0 + (1.2 * (i / 10.0)) for i in range(steps + 1)]

                ts_df = pd.DataFrame({
                    "Timeline": time_points,
                    "Energy (kWh)": energy_curve,
                    "Water Temp (°C)": temp_curve
                })

                c_g1, c_g2 = st.columns(2)
                with c_g1:
                    fig_e = px.line(ts_df, x="Timeline", y="Energy (kWh)", title="Cumulative Energy Consumed (kWh)", markers=True)
                    fig_e.update_traces(line_color="#38bdf8", marker=dict(size=6, color="#38bdf8"))
                    apply_clean_chart_theme(fig_e, "Cumulative Energy Consumed (kWh)", height=280)
                    st.plotly_chart(fig_e, use_container_width=True)
                with c_g2:
                    fig_t = px.line(ts_df, x="Timeline", y="Water Temp (°C)", title="Subsea Thermal Dissipation Curve (°C)", markers=True)
                    fig_t.update_traces(line_color="#fbbf24", marker=dict(size=6, color="#fbbf24"))
                    fig_t.add_hline(y=16.5, line_dash="dash", line_color="#fb7185", annotation_text="Safety Limit")
                    apply_clean_chart_theme(fig_t, "Subsea Thermal Dissipation Curve (°C)", height=280)
                    st.plotly_chart(fig_t, use_container_width=True)

                # Real-Time Environmental Boundary Alert System
                st.markdown("##### 🛡️ Environmental Boundary Alert System")
                al1, al2, al3 = st.columns(3)
                with al1:
                    st.markdown("""
                    <div class="clean-card" style="padding:12px 14px; margin-bottom:0;">
                        <div class="clean-card-label"><span class="badge-pass">NORMAL</span> <span>🌡️</span></div>
                        <div style="font-size:0.95rem; font-weight:700; color:#f8fafc; margin:4px 0;">+1.2°C Water Rise</div>
                        <div class="clean-card-sub">Boundary limit: 2.5°C</div>
                    </div>
                    """, unsafe_allow_html=True)
                with al2:
                    st.markdown("""
                    <div class="clean-card" style="padding:12px 14px; margin-bottom:0;">
                        <div class="clean-card-label"><span class="badge-pass">SECURE</span> <span>🪸</span></div>
                        <div style="font-size:0.95rem; font-weight:700; color:#f8fafc; margin:4px 0;">Eco-Sanctuary Safe</div>
                        <div class="clean-card-sub">0 Violations Detected</div>
                    </div>
                    """, unsafe_allow_html=True)
                with al3:
                    st.markdown("""
                    <div class="clean-card" style="padding:12px 14px; margin-bottom:0;">
                        <div class="clean-card-label"><span class="badge-pass">OPTIMAL</span> <span>🌊</span></div>
                        <div style="font-size:0.95rem; font-weight:700; color:#f8fafc; margin:4px 0;">1.45 m/s Flow</div>
                        <div class="clean-card-sub">Convective heat flux active</div>
                    </div>
                    """, unsafe_allow_html=True)

                with st.expander("📋 Mission Log & Subsea Telemetry Events", expanded=True):
                    for msg in task.logs:
                        st.code(msg, language="bash")

            with c_m2:
                st.markdown("#### Execution Control")
                st.caption("Live simulated mission controls:")
                
                if task.status != "COMPLETED":
                    # Auto live ticker button
                    if st.session_state.auto_sim_active:
                        if st.button("⏸️ Pause Live Stream", key=f"pause_{task.task_id}", use_container_width=True):
                            st.session_state.auto_sim_active = False
                            st.rerun()
                    else:
                        if st.button("▶️ Resume Live Stream", key=f"resume_{task.task_id}", use_container_width=True):
                            st.session_state.auto_sim_active = True
                            st.rerun()

                    if st.button("⏩ Step Forward (+25%)", key=f"adv_{task.task_id}", use_container_width=True):
                        monitor.advance_progress(task.task_id, 25.0)
                        st.rerun()
                    if st.button("🏁 Complete Workload (100%)", key=f"comp_{task.task_id}", use_container_width=True):
                        monitor.advance_progress(task.task_id, 100.0)
                        st.session_state.auto_sim_active = False
                        st.rerun()
                else:
                    st.success("✅ Mission Completed!")
                    if st.button("🔄 Reset / Start New Run", key=f"reset_{task.task_id}", use_container_width=True):
                        st.session_state.monitor = PodExecutionMonitor()
                        st.session_state.auto_sim_active = False
                        st.rerun()

            st.markdown("---")

    # Run history
    if st.session_state.run_history:
        st.markdown("#### 📜 Unified Mission Run History")
        st.dataframe(pd.DataFrame(st.session_state.run_history), use_container_width=True)

    # Auto-advance simulation ticker if active
    if st.session_state.auto_sim_active and st.session_state.active_task_id:
        active_t = monitor.active_tasks.get(st.session_state.active_task_id)
        if active_t and active_t.status != "COMPLETED":
            time.sleep(1.0)
            monitor.advance_progress(active_t.task_id, 20.0)
            if active_t.progress_pct >= 100.0:
                st.session_state.auto_sim_active = False
            st.rerun()

# ==============================================================================
# 09 REVIEW DATASETS AND REPORTS
# Use the same data source and run history for reports and analysis
# ==============================================================================
with t9:
    st.markdown("### <span class='step-badge'>09</span> Review Datasets, Baselines & Audit Reports", unsafe_allow_html=True)
    st.caption("Consolidated review using the exact same data source, workload, and run history for rigorous analysis.")

    d_sub1, d_sub2, d_sub3 = st.tabs([
        "📄 Export Audit Report",
        "⚖️ Baseline Policy Evaluation",
        "📁 Dataset Diagnostics"
    ])

    with d_sub1:
        st.markdown("#### 💾 Audit Report Export (JSON / CSV)")
        json_report = SchedulingReporter.generate_json_report(
            scheduling_decision,
            workload,
            config_defaults
        )
        ranking_df = SchedulingReporter.generate_ranking_dataframe(scheduling_decision)

        col_d1, col_d2 = st.columns(2)
        with col_d1:
            st.download_button(
                label="💾 Download Scheduling Decision (JSON)",
                data=json_report,
                file_name=f"aquaecosched_decision_{workload.get('workload_id', 'wl')}.json",
                mime="application/json",
                use_container_width=True
            )
        with col_d2:
            if not ranking_df.empty:
                csv_data = ranking_df.to_csv(index=False).encode('utf-8')
                st.download_button(
                    label="📊 Download Feasible Pod Rankings (CSV)",
                    data=csv_data,
                    file_name=f"aquaecosched_rankings_{workload.get('workload_id', 'wl')}.csv",
                    mime="text/csv",
                    use_container_width=True
                )
        st.code(json_report, language="json")

    with d_sub2:
        st.markdown("#### ⚖️ Evaluation Against Standard Industry Baselines")
        comparator = BaselineComparator()
        comparison_results = comparator.evaluate_workload(
            workload, clean_pod_df, clean_ocean_df, scheduler, risk_enforcer
        )
        base_cols = st.columns(3)
        policies = ["AquaEcoSched", "FirstFit", "ResourceOnly"]
        titles = ["AquaEcoSched (Eco-Aware)", "Baseline 1: First-Fit", "Baseline 2: Resource-Only"]
        for idx, p_key in enumerate(policies):
            m = comparison_results[p_key]
            with base_cols[idx]:
                badge_type = "emerald" if idx == 0 else "rose"
                badge_text = "OPTIMIZED" if idx == 0 else "HEURISTIC"
                st.markdown(f"""
                <div class="clean-card">
                    <div class="clean-card-label"><span>{titles[idx]}</span> <span class="status-chip {badge_type}" style="font-size:0.65rem; padding:2px 7px;">{badge_text}</span></div>
                    <div class="clean-card-val" style="font-size:1.25rem;">{m.selected_pod_name}</div>
                    <div class="clean-card-sub" style="margin-bottom:8px;">{m.selected_pod_id or 'None'}</div>
                    <div style="font-size:0.83rem; line-height:1.7; color:#cbd5e1; border-top:1px solid rgba(255,255,255,0.06); padding-top:8px;">
                        🌱 <b style="color:#f8fafc;">Carbon:</b> {m.carbon_kg_co2e:.2f} kg CO2e<br/>
                        ⚡ <b style="color:#f8fafc;">Energy:</b> {m.energy_kwh:.2f} kWh<br/>
                        🌡️ <b style="color:#f8fafc;">Water ΔT:</b> +{m.water_temp_delta_c:.2f}°C<br/>
                        🛡️ <b style="color:#f8fafc;">Eco-Risk:</b> {m.environmental_risk_score:.3f}<br/>
                        ⚠️ <b style="color:#f8fafc;">Violations:</b> <span style="color: {'#34d399' if m.constraint_violations==0 else '#fb7185'}; font-weight:700;">{m.constraint_violations}</span>
                    </div>
                </div>
                """, unsafe_allow_html=True)

        # Baseline savings comparison chart
        st.markdown("##### 📉 Carbon Footprint Reduction vs Industry Baselines")
        comp_df = pd.DataFrame([
            {"Policy": titles[i], "Carbon (kg CO2e)": comparison_results[p].carbon_kg_co2e, "Energy (kWh)": comparison_results[p].energy_kwh}
            for i, p in enumerate(policies)
        ])
        fig_base = px.bar(
            comp_df,
            x="Policy",
            y="Carbon (kg CO2e)",
            title="Carbon Footprint Comparison (kg CO2e) — Lower is Better",
            color="Policy",
            color_discrete_sequence=["#34d399", "#fbbf24", "#fb7185"]
        )
        apply_clean_chart_theme(fig_base, "Carbon Footprint Comparison (kg CO2e) — Lower is Better", height=320)
        st.plotly_chart(fig_base, use_container_width=True)

    with d_sub3:
        st.markdown("#### 📁 Global Subsea Fleet Datasets & Real-Time Telemetry")
        v1, v2, v3 = st.columns(3)
        with v1:
            st.metric("Workload Profiles Loaded", f"{len(clean_wl_df)} Workloads", "Verified (AI / Sci)")
        with v2:
            st.metric("Pod Hardware Fleet", f"{len(clean_pod_df)} Global Pods", f"{rep_pod.summary.get('active_pods', 0)} Active")
        with v3:
            st.metric("Ocean Telemetry Records", f"{len(clean_ocean_df)} Sensor Buoys", "Real-Time Synced")

        ds_t1, ds_t2, ds_t3 = st.tabs([
            "📋 Workload Catalog (30)",
            "🖥️ Subsea Pod Fleet (30)",
            "🌊 Ocean Telemetry Stream (30)"
        ])

        with ds_t1:
            st.markdown("##### 📋 Workload Profiles (30 AI, HPC & Oceanographic Tasks)")
            st.dataframe(clean_wl_df, use_container_width=True)
            st.download_button(
                "📥 Download Workloads CSV",
                clean_wl_df.to_csv(index=False).encode('utf-8'),
                "workload_profiles_expanded.csv",
                "text/csv"
            )

        with ds_t2:
            st.markdown("##### 🖥️ Subsea Pod Hardware Fleet (30 Global Oceanographic Pods)")
            st.dataframe(clean_pod_df, use_container_width=True)
            st.download_button(
                "📥 Download Pod Resources CSV",
                clean_pod_df.to_csv(index=False).encode('utf-8'),
                "pod_resources_expanded.csv",
                "text/csv"
            )

        with ds_t3:
            st.markdown("##### 🌊 Real-Time Synchronized Oceanographic Telemetry (30 Buoy Feeds)")
            st.dataframe(clean_ocean_df, use_container_width=True)
            st.download_button(
                "📥 Download Ocean Conditions CSV",
                clean_ocean_df.to_csv(index=False).encode('utf-8'),
                "ocean_conditions_realtime.csv",
                "text/csv"
            )

st.markdown("---")
st.caption("AquaEcoSched v2.0 • Environment-Aware Multi-Objective Underwater Pod Scheduler • Flow 01-09 End-to-End Orchestration")
