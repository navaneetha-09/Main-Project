/// Model representing subsea computing pod hardware capacity & specifications.
class PodResource {
  final String id;
  final String name;
  final String location;
  final double totalCpu;
  final double usedCpu;
  final double totalGpu;
  final double usedGpu;
  final double totalRamGb;
  final double usedRamGb;
  final double totalStorageGb;
  final double usedStorageGb;
  final String status; // "ACTIVE", "MAINTENANCE", "DEGRADED", "OFFLINE"
  final double basePowerKw;
  final double maxPowerKw;
  final double pue;
  final double networkLatencyMs;
  final double surfaceAreaM2;

  const PodResource({
    required this.id,
    required this.name,
    required this.location,
    required this.totalCpu,
    required this.usedCpu,
    required this.totalGpu,
    required this.usedGpu,
    required this.totalRamGb,
    required this.usedRamGb,
    this.totalStorageGb = 2000.0,
    this.usedStorageGb = 400.0,
    required this.status,
    required this.basePowerKw,
    required this.maxPowerKw,
    required this.pue,
    required this.networkLatencyMs,
    required this.surfaceAreaM2,
  });

  double get availableCpu => totalCpu - usedCpu;
  double get availableGpu => totalGpu - usedGpu;
  double get availableRamGb => totalRamGb - usedRamGb;
  double get availableStorageGb => totalStorageGb - usedStorageGb;

  double get cpuUtilization => totalCpu > 0 ? (usedCpu / totalCpu) : 0.0;
  double get gpuUtilization => totalGpu > 0 ? (usedGpu / totalGpu) : 0.0;
  double get ramUtilization => totalRamGb > 0 ? (usedRamGb / totalRamGb) : 0.0;
  double get storageUtilization => totalStorageGb > 0 ? (usedStorageGb / totalStorageGb) : 0.0;

  bool get isOperational => status.toUpperCase() == "ACTIVE" || status.toUpperCase() == "ONLINE";

  PodResource copyWith({
    String? id,
    String? name,
    String? location,
    double? totalCpu,
    double? usedCpu,
    double? totalGpu,
    double? usedGpu,
    double? totalRamGb,
    double? usedRamGb,
    String? status,
    double? basePowerKw,
    double? maxPowerKw,
    double? pue,
    double? networkLatencyMs,
    double? surfaceAreaM2,
  }) {
    return PodResource(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      totalCpu: totalCpu ?? this.totalCpu,
      usedCpu: usedCpu ?? this.usedCpu,
      totalGpu: totalGpu ?? this.totalGpu,
      usedGpu: usedGpu ?? this.usedGpu,
      totalRamGb: totalRamGb ?? this.totalRamGb,
      usedRamGb: usedRamGb ?? this.usedRamGb,
      status: status ?? this.status,
      basePowerKw: basePowerKw ?? this.basePowerKw,
      maxPowerKw: maxPowerKw ?? this.maxPowerKw,
      pue: pue ?? this.pue,
      networkLatencyMs: networkLatencyMs ?? this.networkLatencyMs,
      surfaceAreaM2: surfaceAreaM2 ?? this.surfaceAreaM2,
    );
  }
}
