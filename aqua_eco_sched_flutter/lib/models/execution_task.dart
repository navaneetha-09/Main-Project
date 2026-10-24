import 'scheduling_result.dart';

/// Telemetry reading captured during continuous subsea monitoring.
class TelemetryDataPoint {
  final DateTime timestamp;
  final double deltaTempC;
  final double internalPodTempC;
  final double ambientTempC;
  final double convectiveHWm2k;
  final bool isThermalBreached;

  const TelemetryDataPoint({
    required this.timestamp,
    required this.deltaTempC,
    required this.internalPodTempC,
    required this.ambientTempC,
    required this.convectiveHWm2k,
    this.isThermalBreached = false,
  });
}

/// Audit log record for dynamic live workload migration.
class MigrationRecord {
  final DateTime timestamp;
  final String fromPodId;
  final String fromPodName;
  final String toPodId;
  final String toPodName;
  final String reason;
  final double tempBefore;
  final double tempAfter;
  final double deltaTempBefore;
  final double deltaTempAfter;

  const MigrationRecord({
    required this.timestamp,
    required this.fromPodId,
    required this.fromPodName,
    required this.toPodId,
    required this.toPodName,
    required this.reason,
    required this.tempBefore,
    required this.tempAfter,
    required this.deltaTempBefore,
    required this.deltaTempAfter,
  });
}

/// Model representing a simulated lifecycle execution run on a subsea pod with continuous monitoring.
class ExecutionTask {
  final String taskId;
  final String workloadId;
  final String workloadType;
  String assignedPodId;
  String assignedPodName;
  final String initialPodId;
  final String initialPodName;
  String status; // "QUEUED", "ALLOCATED", "RUNNING", "MIGRATING", "MIGRATED_RUNNING", "COMPLETED", "FAILED"
  double progressPct;
  final String startTime;
  String? completionTime;
  final double cpuAllocated;
  final double gpuAllocated;
  final double ramAllocated;
  final double durationHours;
  double energyConsumedKwh;
  double carbonEmittedKg;
  final List<String> logs;

  // Real-time continuous monitoring telemetry
  double currentWaterDeltaTempC;
  double currentPodTempC;
  double ambientWaterTempC;
  double currentConvectiveHWm2k;
  double thermalFootprintScore;
  double environmentalRiskScore;
  bool isThermalAlert;
  String? thermalAlertReason;

  // Dynamic live workload migration state
  bool isMigrated;
  String? migratedFromPodId;
  String? migratedFromPodName;
  String? migrationTimestamp;
  String? migrationReason;
  PodScoreRecord? suggestedTargetPod;
  final List<MigrationRecord> migrationHistory;
  final List<TelemetryDataPoint> telemetryHistory;

  ExecutionTask({
    required this.taskId,
    required this.workloadId,
    required this.workloadType,
    required this.assignedPodId,
    required this.assignedPodName,
    String? initialPodId,
    String? initialPodName,
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
    this.currentWaterDeltaTempC = 1.45,
    this.currentPodTempC = 31.5,
    this.ambientWaterTempC = 8.4,
    this.currentConvectiveHWm2k = 950.0,
    this.thermalFootprintScore = 0.25,
    this.environmentalRiskScore = 0.22,
    this.isThermalAlert = false,
    this.thermalAlertReason,
    this.isMigrated = false,
    this.migratedFromPodId,
    this.migratedFromPodName,
    this.migrationTimestamp,
    this.migrationReason,
    this.suggestedTargetPod,
    List<MigrationRecord>? migrationHistory,
    List<TelemetryDataPoint>? telemetryHistory,
  })  : initialPodId = initialPodId ?? assignedPodId,
        initialPodName = initialPodName ?? assignedPodName,
        migrationHistory = migrationHistory ?? [],
        telemetryHistory = telemetryHistory ?? [];
}
