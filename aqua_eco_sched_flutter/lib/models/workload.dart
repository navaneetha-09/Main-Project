/// Model representing a computational workload for underwater computing pods.
class Workload {
  final String id;
  final String type;
  final double cpuCores;
  final double gpuUnits;
  final double ramGb;
  final double storageGb;
  final double durationHours;
  final String priority;
  final String description;

  const Workload({
    required this.id,
    required this.type,
    required this.cpuCores,
    required this.gpuUnits,
    required this.ramGb,
    this.storageGb = 100.0,
    required this.durationHours,
    required this.priority,
    required this.description,
  });

  Workload copyWith({
    String? id,
    String? type,
    double? cpuCores,
    double? gpuUnits,
    double? ramGb,
    double? storageGb,
    double? durationHours,
    String? priority,
    String? description,
  }) {
    return Workload(
      id: id ?? this.id,
      type: type ?? this.type,
      cpuCores: cpuCores ?? this.cpuCores,
      gpuUnits: gpuUnits ?? this.gpuUnits,
      ramGb: ramGb ?? this.ramGb,
      storageGb: storageGb ?? this.storageGb,
      durationHours: durationHours ?? this.durationHours,
      priority: priority ?? this.priority,
      description: description ?? this.description,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Workload &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
