/// Model representing a simulated lifecycle execution run on a subsea pod.
class ExecutionTask {
  final String taskId;
  final String workloadId;
  final String workloadType;
  final String assignedPodId;
  final String assignedPodName;
  String status; // "QUEUED", "ALLOCATED", "RUNNING", "COMPLETED", "FAILED"
  double progressPct;
  final String startTime;
  String? completionTime;
  final double cpuAllocated;
  final double gpuAllocated;
  final double ramAllocated;
  final double durationHours;
  final double energyConsumedKwh;
  final double carbonEmittedKg;
  final List<String> logs;

  ExecutionTask({
    required this.taskId,
    required this.workloadId,
    required this.workloadType,
    required this.assignedPodId,
    required this.assignedPodName,
    required this.status,
    required this.progressPct,
    required this.startTime,
    this.completionTime,
    required this.cpuAllocated,
    required this.gpuAllocated,
    required this.ramAllocated,
    required this.durationHours,
    required this.energyConsumedKwh,
    required this.carbonEmittedKg,
    required this.logs,
  });
}
