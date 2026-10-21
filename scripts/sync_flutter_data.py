import os
import pandas as pd

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
df_w = pd.read_csv(os.path.join(BASE_DIR, 'data', 'workload_profiles.csv'))
df_p = pd.read_csv(os.path.join(BASE_DIR, 'data', 'pod_resources.csv'))
df_o = pd.read_csv(os.path.join(BASE_DIR, 'data', 'ocean_conditions.csv'))

out = []
out.append('''import '../models/workload.dart';
import '../models/pod_resource.dart';
import '../models/ocean_condition.dart';

class DataValidationReport {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final Map<String, dynamic> summary;

  const DataValidationReport({
    required this.isValid,
    required this.errors,
    required this.warnings,
    required this.summary,
  });
}

class DataService {
  static List<Workload> getDefaultWorkloads() {
    return const [''')

for _, r in df_w.iterrows():
    desc = str(r['description']).replace('"', '\\"')
    out.append(f'''      Workload(
        id: "{r['workload_id']}",
        type: "{r['workload_type']}",
        cpuCores: {float(r['cpu_cores'])},
        gpuUnits: {float(r['gpu_units'])},
        ramGb: {float(r['ram_gb'])},
        storageGb: {float(r.get('storage_gb', 100))},
        durationHours: {float(r['duration_hours'])},
        priority: "{r['priority']}",
        description: "{desc}",
      ),''')

out.append('''    ];
  }

  static List<PodResource> getDefaultPods() {
    return const [''')

for _, r in df_p.iterrows():
    name = str(r['pod_name']).replace('"', '\\"')
    loc = str(r['location']).replace('"', '\\"')
    out.append(f'''      PodResource(
        id: "{r['pod_id']}",
        name: "{name}",
        location: "{loc}",
        totalCpu: {float(r['total_cpu'])},
        usedCpu: {float(r['used_cpu'])},
        totalGpu: {float(r['total_gpu'])},
        usedGpu: {float(r['used_gpu'])},
        totalRamGb: {float(r['total_ram_gb'])},
        usedRamGb: {float(r['used_ram_gb'])},
        totalStorageGb: {float(r['total_storage_gb'])},
        usedStorageGb: {float(r['used_storage_gb'])},
        status: "{r['status']}",
        basePowerKw: {float(r['base_power_kw'])},
        maxPowerKw: {float(r['max_power_kw'])},
        pue: {float(r['pue'])},
        networkLatencyMs: {float(r['network_latency_ms'])},
        surfaceAreaM2: {float(r['surface_area_m2'])},
      ),''')

out.append('''    ];
  }

  static List<OceanCondition> getDefaultOceanConditions() {
    final now = DateTime.now().toUtc();
    return [''')

for idx, r in df_o.iterrows():
    mins = 5 + (idx % 25)
    out.append(f'''      OceanCondition(
        podId: "{r['pod_id']}",
        timestamp: now.subtract(const Duration(minutes: {mins})),
        waterTemperatureC: {float(r['water_temperature_c'])},
        currentSpeedMps: {float(r['current_speed_mps'])},
        currentDirectionDeg: {float(r['current_direction_deg'])},
        salinityPsu: {float(r['salinity_psu'])},
        depthM: {float(r['depth_m'])},
        ecologicalZone: "{r['ecological_zone']}",
        gridCarbonIntensityKgPerKwh: {float(r['grid_carbon_intensity_kg_per_kwh'])},
        ambientTurbidityNtu: {float(r['ambient_turbidity_ntu'])},
      ),''')

out.append('''    ];
  }

  static DataValidationReport validateData(
    List<Workload> workloads,
    List<PodResource> pods,
    List<OceanCondition> oceanConditions,
  ) {
    final List<String> errors = [];
    final List<String> warnings = [];

    // Pods validation
    int activePods = 0;
    for (final p in pods) {
      if (p.isOperational) activePods++;
      if (p.usedCpu > p.totalCpu) {
        errors.add("Physical impossibility: used CPU > total CPU on ${p.id}");
      }
      if (p.usedGpu > p.totalGpu) {
        errors.add("Physical impossibility: used GPU > total GPU on ${p.id}");
      }
      if (p.usedRamGb > p.totalRamGb) {
        errors.add("Physical impossibility: used RAM > total RAM on ${p.id}");
      }
      if (p.basePowerKw <= 0) {
        errors.add("Base power must be positive on ${p.id}");
      }
    }

    // Ocean conditions validation
    final now = DateTime.now().toUtc();
    for (final o in oceanConditions) {
      if (o.waterTemperatureC < -4.0 || o.waterTemperatureC > 45.0) {
        errors.add("Water temperature out of ocean bounds on pod ${o.podId}");
      }
      if (o.currentSpeedMps < 0 || o.currentSpeedMps > 8.0) {
        errors.add("Current speed out of physical bounds on pod ${o.podId}");
      }
      if (o.depthM <= 0) {
        errors.add("Depth must be positive for subsea pod ${o.podId}");
      }
      final ageHours = now.difference(o.timestamp).inMinutes / 60.0;
      if (ageHours > 24.0) {
        warnings.add("Telemetry data is stale (> 24h old) for pod ${o.podId}");
      }
    }

    // Cross-key validation
    final podIds = pods.map((e) => e.id).toSet();
    final oceanPodIds = oceanConditions.map((e) => e.podId).toSet();
    final missingTelemetry = podIds.difference(oceanPodIds);
    if (missingTelemetry.isNotEmpty) {
      warnings.add("Pods lacking telemetry data: ${missingTelemetry.join(', ')}");
    }

    return DataValidationReport(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      summary: {
        "workloadCount": workloads.length,
        "podCount": pods.length,
        "activePods": activePods,
        "oceanRecords": oceanConditions.length,
      },
    );
  }
}
''')

target = os.path.join(BASE_DIR, 'aqua_eco_sched_flutter', 'lib', 'services', 'data_service.dart')
with open(target, 'w', encoding='utf-8') as f:
    f.write('\n'.join(out))

print(f'Successfully synced workloads, pods, and ocean conditions to {target}')
