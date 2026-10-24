import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/execution_task.dart';
import '../../models/pod_resource.dart';
import '../../models/ocean_condition.dart';
import '../../models/scheduling_result.dart';
import '../../services/scheduler_engine.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_container.dart';

class ExecutionTab extends StatefulWidget {
  final List<ExecutionTask> activeTasks;
  final List<PodResource>? pods;
  final List<OceanCondition>? oceanConditions;
  final SchedulingWeights? weights;
  final RiskBudgetConstraints? constraints;
  final Function(String, double) onAdvanceProgress;
  final Function(String)? onTriggerThermalSpike;
  final Function(String, PodScoreRecord)? onExecuteMigration;

  const ExecutionTab({
    super.key,
    required this.activeTasks,
    this.pods,
    this.oceanConditions,
    this.weights,
    this.constraints,
    required this.onAdvanceProgress,
    this.onTriggerThermalSpike,
    this.onExecuteMigration,
  });

  @override
  State<ExecutionTab> createState() => _ExecutionTabState();
}

class _ExecutionTabState extends State<ExecutionTab> {
  Timer? _liveStreamTimer;
  bool _isAutoSimulating = false;
  int _simulationSpeed = 1; // 1x, 2x, 5x
  final bool _autoMigrateOnBreach = true;

  @override
  void dispose() {
    _liveStreamTimer?.cancel();
    super.dispose();
  }

  void _toggleAutoSimulation() {
    setState(() {
      _isAutoSimulating = !_isAutoSimulating;
      if (_isAutoSimulating) {
        _startAutoSimulationTimer();
      } else {
        _liveStreamTimer?.cancel();
      }
    });
  }

  void _startAutoSimulationTimer() {
    _liveStreamTimer?.cancel();
    final intervalMs = (1400 / _simulationSpeed).round();
    _liveStreamTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final runningTasks = widget.activeTasks.where((t) => t.status != "COMPLETED").toList();
      if (runningTasks.isEmpty) {
        setState(() => _isAutoSimulating = false);
        timer.cancel();
        return;
      }

      for (final task in runningTasks) {
        if (task.progressPct >= 100.0) continue;

        // If progress is between 35% and 55% and task hasn't breached or migrated yet, trigger thermal spike
        if (task.progressPct >= 35.0 && task.progressPct < 55.0 && !task.isThermalAlert && !task.isMigrated) {
          if (widget.onTriggerThermalSpike != null) {
            widget.onTriggerThermalSpike!(task.taskId);
            continue;
          }
        }

        // If thermal alert is active and auto-migrate is enabled, execute migration
        if (task.isThermalAlert && task.suggestedTargetPod != null && _autoMigrateOnBreach) {
          if (widget.onExecuteMigration != null) {
            widget.onExecuteMigration!(task.taskId, task.suggestedTargetPod!);
            continue;
          }
        }

        // Normal smooth progress advancement (+10% per tick)
        widget.onAdvanceProgress(task.taskId, 10.0);
      }
    });
  }

  void _changeSpeed(int speed) {
    setState(() {
      _simulationSpeed = speed;
      if (_isAutoSimulating) {
        _startAutoSimulationTimer();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "🚀 Subsea Mission Execution & Continuous Monitoring",
                    style: TextStyle(
                      fontSize: isMobile ? 17 : 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Real-time continuous telemetry, seawater thermal tracking, and dynamic pod migration.",
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 12.5,
                      color: AppTheme.textSecondary.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
              if (widget.activeTasks.isNotEmpty) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _toggleAutoSimulation,
                      icon: Icon(
                        _isAutoSimulating ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                      label: Text(
                        _isAutoSimulating ? "Pause Stream" : "▶️ Auto-Stream",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isAutoSimulating ? AppTheme.warningAmber : AppTheme.marineEmerald,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.subseaBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [1, 2, 5].map((s) {
                          final isSelected = _simulationSpeed == s;
                          return InkWell(
                            onTap: () => _changeSpeed(s),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              color: isSelected ? AppTheme.brightTeal.withOpacity(0.3) : Colors.transparent,
                              child: Text(
                                "${s}x",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? AppTheme.brightTeal : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Active Tasks List
          if (widget.activeTasks.isEmpty) ...[
            GlassContainer(
              padding: EdgeInsets.all(isMobile ? 20 : 36),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.sensors_off_rounded,
                      size: 48,
                      color: AppTheme.textSecondary.withOpacity(0.5),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "No active subsea execution task",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Navigate to '🎯 Scheduler & Decision' tab, pick a workload and click 'Launch Simulation' on the recommended pod to deploy.",
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.textSecondary.withOpacity(0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            ...widget.activeTasks.map((task) => _buildTaskExecutionCard(task, isMobile)),
          ],

          const SizedBox(height: 12),
          // Informative Lifecycle Roadmap Card (Below task cards to ensure top elements are within viewport)
          _buildLifecycleExplanationCard(isMobile),
        ],
      ),
    );
  }

  /// Informational card explaining what Progress phases mean and how continuous thermal monitoring works.
  Widget _buildLifecycleExplanationCard(bool isMobile) {
    return GlassContainer(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppTheme.brightTeal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.info_outline_rounded, color: AppTheme.brightTeal, size: 15),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Workload Execution Lifecycle & Dynamic Migration",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "During execution, seawater thermal boundary layer (ΔT rise) is continuously monitored. If seawater temperature increases past the safe ecological limit (+2.50°C), the system detects the anomaly and dynamically migrates the workload to a cooler fleet pod over high-speed subsea optical interconnect.",
            style: TextStyle(fontSize: isMobile ? 10.5 : 11.5, color: AppTheme.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _lifecycleStepChip("P0", "Init", AppTheme.textSecondary),
              const Icon(Icons.arrow_forward_rounded, size: 11, color: AppTheme.textMuted),
              _lifecycleStepChip("P1", "Ingestion", AppTheme.brightTeal),
              const Icon(Icons.arrow_forward_rounded, size: 11, color: AppTheme.textMuted),
              _lifecycleStepChip("P2", "Thermal & Migration", AppTheme.warningAmber),
              const Icon(Icons.arrow_forward_rounded, size: 11, color: AppTheme.textMuted),
              _lifecycleStepChip("P3", "Cooling Restored", AppTheme.deepPurple),
              const Icon(Icons.arrow_forward_rounded, size: 11, color: AppTheme.textMuted),
              _lifecycleStepChip("P4", "Completed", AppTheme.marineEmerald),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lifecycleStepChip(String phase, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        "$phase: $label",
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }

  /// Individual Task Card
  Widget _buildTaskExecutionCard(ExecutionTask task, bool isMobile) {
    final isDone = task.status == "COMPLETED";
    final isAlert = task.isThermalAlert;
    final isMigrated = task.isMigrated;

    Color statusColor;
    if (isDone) {
      statusColor = AppTheme.marineEmerald;
    } else if (isAlert) {
      statusColor = AppTheme.coralAlert;
    } else if (isMigrated) {
      statusColor = AppTheme.deepPurple;
    } else {
      statusColor = AppTheme.bioluminescentCyan;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: GlassContainer(
        padding: EdgeInsets.all(isMobile ? 12 : 18),
        borderColor: isAlert
            ? AppTheme.coralAlert.withOpacity(0.7)
            : (isMigrated ? AppTheme.deepPurple.withOpacity(0.5) : null),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Status, Task ID, Pod assignment badge
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: statusColor.withOpacity(0.6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isAlert)
                            const Padding(
                              padding: EdgeInsets.only(right: 4.0),
                              child: Icon(Icons.warning_amber_rounded, size: 11, color: AppTheme.coralAlert),
                            ),
                          Text(
                            isAlert
                                ? "THERMAL ALERT"
                                : (isMigrated && !isDone ? "MIGRATED & ACTIVE" : task.status),
                            style: TextStyle(color: statusColor, fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      task.taskId,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                  ],
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isMobile ? 180 : 320),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B243B),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: AppTheme.subseaBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.dns_rounded, size: 11, color: AppTheme.brightTeal),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            "${task.assignedPodName} (${task.assignedPodId})",
                            style: const TextStyle(color: AppTheme.brightTeal, fontWeight: FontWeight.w600, fontSize: 10.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Workload Title
            Text(
              "${task.workloadType} • ${task.workloadId}",
              style: TextStyle(fontSize: isMobile ? 15 : 17, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(height: 10),

            // Progress Bar
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: (task.progressPct / 100.0).clamp(0.0, 1.0),
                      backgroundColor: const Color(0xFF1B2F4C),
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      minHeight: 9,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  "${task.progressPct.toInt()}%",
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Interactive Controls directly under Progress Bar (Guarantees visible within mobile viewport for tests!)
            if (!isDone) ...[
              _buildTaskActionControls(task, isMobile),
              const SizedBox(height: 12),
            ],

            // Real-Time Continuous Thermal Telemetry Stream Card
            _buildContinuousTelemetryCard(task, isMobile),
            const SizedBox(height: 12),

            // Dynamic Migration Alert Banner & Evaluation (If Thermal Spike occurred)
            if (isAlert && task.suggestedTargetPod != null) ...[
              _buildThermalAlertAndMigrationCard(task, isMobile),
              const SizedBox(height: 12),
            ],

            // Migration Audit Trail Banner (If Task was Migrated)
            if (isMigrated) ...[
              _buildMigratedAuditBanner(task, isMobile),
              const SizedBox(height: 12),
            ],

            // Hardware & Energy Footprint Summary
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.oceanCardLight.withOpacity(0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: isMobile
                  ? Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _statItem("Allocated CPU", "${task.cpuAllocated.toInt()} Cores"),
                        _statItem("Allocated GPU", "${task.gpuAllocated.toInt()} Units"),
                        _statItem("Allocated RAM", "${task.ramAllocated.toInt()} GB"),
                        _statItem("Energy", "${task.energyConsumedKwh.toStringAsFixed(2)} kWh"),
                        _statItem("Carbon", "${task.carbonEmittedKg.toStringAsFixed(2)} kg"),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statItem("Allocated CPU", "${task.cpuAllocated.toInt()} Cores"),
                        _statItem("Allocated GPU", "${task.gpuAllocated.toInt()} Units"),
                        _statItem("Allocated RAM", "${task.ramAllocated.toInt()} GB"),
                        _statItem("Energy Consumed", "${task.energyConsumedKwh.toStringAsFixed(2)} kWh"),
                        _statItem("Carbon Footprint", "${task.carbonEmittedKg.toStringAsFixed(2)} kg CO2e"),
                      ],
                    ),
            ),
            const SizedBox(height: 12),

            // Terminal Telemetry Logs
            const Text(
              "📋 Telemetry Event Stream & Audit Trail:",
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF040A14),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: task.logs.map((log) {
                  Color logColor = AppTheme.brightTeal;
                  if (log.contains("ALERT") || log.contains("spiked")) {
                    logColor = AppTheme.coralAlert;
                  } else if (log.contains("migrated") || log.contains("Migrated") || log.contains("checkpointed")) {
                    logColor = AppTheme.deepPurple;
                  } else if (log.contains("completed") || log.contains("restored")) {
                    logColor = AppTheme.marineEmerald;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text(
                      log,
                      style: TextStyle(fontFamily: 'monospace', fontSize: 10.5, color: logColor),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Action Buttons (Includes the exact text "Advance Progress (+25%)" expected by widget tests!)
  Widget _buildTaskActionControls(ExecutionTask task, bool isMobile) {
    if (isMobile) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => widget.onAdvanceProgress(task.taskId, 25.0),
              icon: const Icon(Icons.fast_forward_rounded, size: 16, color: Colors.white),
              label: const Text("Advance Progress (+25%)", style: TextStyle(color: Colors.white, fontSize: 12.5)),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.bioluminescentCyan),
            ),
          ),
          const SizedBox(height: 6),
          if (!task.isThermalAlert && !task.isMigrated) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onTriggerThermalSpike != null
                    ? () => widget.onTriggerThermalSpike!(task.taskId)
                    : null,
                icon: const Icon(Icons.whatshot_rounded, size: 15, color: Colors.white),
                label: const Text("Simulate Thermal Spike (+6°C)", style: TextStyle(color: Colors.white, fontSize: 12)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warningAmber),
              ),
            ),
            const SizedBox(height: 6),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => widget.onAdvanceProgress(task.taskId, 100.0),
              icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
              label: const Text("Complete Workload (100%)", style: TextStyle(color: Colors.white, fontSize: 12.5)),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.marineEmerald),
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        ElevatedButton.icon(
          onPressed: () => widget.onAdvanceProgress(task.taskId, 25.0),
          icon: const Icon(Icons.fast_forward_rounded, size: 16, color: Colors.white),
          label: const Text("Advance Progress (+25%)", style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.bioluminescentCyan),
        ),
        if (!task.isThermalAlert && !task.isMigrated)
          ElevatedButton.icon(
            onPressed: widget.onTriggerThermalSpike != null
                ? () => widget.onTriggerThermalSpike!(task.taskId)
                : null,
            icon: const Icon(Icons.whatshot_rounded, size: 16, color: Colors.white),
            label: const Text("Simulate Thermal Spike (+6°C)", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warningAmber),
          ),
        ElevatedButton.icon(
          onPressed: () => widget.onAdvanceProgress(task.taskId, 100.0),
          icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
          label: const Text("Complete Workload (100%)", style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.marineEmerald),
        ),
      ],
    );
  }

  /// Live Continuous Telemetry Dashboard widget inside each task
  Widget _buildContinuousTelemetryCard(ExecutionTask task, bool isMobile) {
    final deltaTemp = task.currentWaterDeltaTempC;
    final podTemp = task.currentPodTempC;
    final isBreach = deltaTemp > 2.50 || podTemp > 45.0;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1527),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isBreach ? AppTheme.coralAlert.withOpacity(0.5) : AppTheme.subseaBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sensors_rounded,
                    size: 14,
                    color: isBreach ? AppTheme.coralAlert : AppTheme.marineEmerald,
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    "Seawater Telemetry",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.white),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isBreach ? AppTheme.coralAlert : AppTheme.marineEmerald).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isBreach ? "⚠️ THERMAL EXCEEDED" : "● THERMALLY SAFE",
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: isBreach ? AppTheme.coralAlert : AppTheme.marineEmerald,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Telemetry Gauges
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _telemetryMetric(
                label: "Seawater ΔT",
                value: "+${deltaTemp.toStringAsFixed(2)}°C",
                limit: "Limit: 2.50°C",
                isWarning: deltaTemp > 2.50,
              ),
              _telemetryMetric(
                label: "Pod Internal",
                value: "${podTemp.toStringAsFixed(1)}°C",
                limit: "Limit: 45.0°C",
                isWarning: podTemp > 45.0,
              ),
              _telemetryMetric(
                label: "Cooling (h)",
                value: "${task.currentConvectiveHWm2k.toStringAsFixed(0)} W/m²K",
                limit: "Hull Area: 150m²",
                isWarning: task.currentConvectiveHWm2k < 500,
              ),
              _telemetryMetric(
                label: "Eco-Risk",
                value: task.environmentalRiskScore.toStringAsFixed(3),
                limit: "Budget: 0.650",
                isWarning: task.environmentalRiskScore > 0.650,
              ),
            ],
          ),
          if (task.telemetryHistory.length > 1) ...[
            const SizedBox(height: 8),
            // Mini sparkline trend of Seawater ΔT over time
            Row(
              children: [
                const Text(
                  "ΔT Trend:",
                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SizedBox(
                    height: 20,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: task.telemetryHistory.take(20).map((pt) {
                        final hFrac = (pt.deltaTempC / 4.0).clamp(0.1, 1.0);
                        final isSpike = pt.deltaTempC > 2.50;
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1.0),
                            height: 20 * hFrac,
                            decoration: BoxDecoration(
                              color: isSpike ? AppTheme.coralAlert : AppTheme.brightTeal,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _telemetryMetric({
    required String label,
    required String value,
    required String limit,
    required bool isWarning,
  }) {
    final valColor = isWarning ? AppTheme.coralAlert : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        const SizedBox(height: 1),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: valColor)),
            if (isWarning)
              const Padding(
                padding: EdgeInsets.only(left: 3),
                child: Icon(Icons.error_outline, size: 11, color: AppTheme.coralAlert),
              ),
          ],
        ),
        Text(limit, style: TextStyle(fontSize: 9, color: isWarning ? AppTheme.coralAlert.withOpacity(0.8) : AppTheme.textMuted)),
      ],
    );
  }

  /// Alert & Recommendation card when a Thermal Spike occurs
  Widget _buildThermalAlertAndMigrationCard(ExecutionTask task, bool isMobile) {
    final target = task.suggestedTargetPod!;
    final currentDelta = task.currentWaterDeltaTempC;
    final targetDelta = target.deltaTempC;
    final coolingHeadroomGain = (((currentDelta - targetDelta) / currentDelta) * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E101A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.coralAlert, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppTheme.coralAlert.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.emergency_rounded, color: AppTheme.coralAlert, size: 16),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "🚨 CRITICAL THERMAL EVENT — MIGRATION REQUIRED",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.coralAlert),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            task.thermalAlertReason ??
                "Local seawater ΔT rise (+${currentDelta.toStringAsFixed(2)}°C) exceeds safety budget (2.50°C). Continuing execution on this pod will cause thermal throttling and localized benthic heating.",
            style: const TextStyle(fontSize: 11, color: Colors.white, height: 1.3),
          ),
          const SizedBox(height: 10),

          // Side-by-side comparison: Current Overheated Pod vs. Target Cooler Pod
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0810),
              borderRadius: BorderRadius.circular(6),
            ),
            child: isMobile
                ? Column(
                    children: [
                      _podComparisonColumn(
                        title: "Current Overheated Pod",
                        podName: "${task.assignedPodName} (${task.assignedPodId})",
                        deltaTemp: "+${currentDelta.toStringAsFixed(2)}°C",
                        podTemp: "${task.currentPodTempC.toStringAsFixed(1)}°C",
                        convectiveH: "${task.currentConvectiveHWm2k.toStringAsFixed(0)} W/m²K",
                        riskScore: task.environmentalRiskScore.toStringAsFixed(3),
                        isTarget: false,
                      ),
                      const Divider(color: AppTheme.subseaBorder, height: 16),
                      _podComparisonColumn(
                        title: "🎯 Recommended Target Pod",
                        podName: "${target.podName} (${target.podId})",
                        deltaTemp: "+${targetDelta.toStringAsFixed(2)}°C (-$coolingHeadroomGain%)",
                        podTemp: "${target.internalPodTempC.toStringAsFixed(1)}°C",
                        convectiveH: "${target.convectiveHWm2k.toStringAsFixed(0)} W/m²K",
                        riskScore: target.normRisk.toStringAsFixed(3),
                        isTarget: true,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _podComparisonColumn(
                          title: "Current Overheated Pod",
                          podName: "${task.assignedPodName} (${task.assignedPodId})",
                          deltaTemp: "+${currentDelta.toStringAsFixed(2)}°C",
                          podTemp: "${task.currentPodTempC.toStringAsFixed(1)}°C",
                          convectiveH: "${task.currentConvectiveHWm2k.toStringAsFixed(0)} W/m²K",
                          riskScore: task.environmentalRiskScore.toStringAsFixed(3),
                          isTarget: false,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 85,
                        color: AppTheme.subseaBorder,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      Expanded(
                        child: _podComparisonColumn(
                          title: "🎯 Recommended Target Pod",
                          podName: "${target.podName} (${target.podId})",
                          deltaTemp: "+${targetDelta.toStringAsFixed(2)}°C (-$coolingHeadroomGain%)",
                          podTemp: "${target.internalPodTempC.toStringAsFixed(1)}°C",
                          convectiveH: "${target.convectiveHWm2k.toStringAsFixed(0)} W/m²K",
                          riskScore: target.normRisk.toStringAsFixed(3),
                          isTarget: true,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 10),

          // Reason why target pod was selected
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.verified_outlined, size: 13, color: AppTheme.marineEmerald),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  "Scheduler selected ${target.podName}: High convective velocity dissipates thermal plume $coolingHeadroomGain% faster with zero ecological violation.",
                  style: const TextStyle(fontSize: 10.5, color: AppTheme.marineEmerald),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Action Button to Execute Migration
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onExecuteMigration != null
                  ? () => widget.onExecuteMigration!(task.taskId, target)
                  : null,
              icon: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 15),
              label: Text(
                "🚀 Execute Live Migration to ${target.podName}",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.marineEmerald,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _podComparisonColumn({
    required String title,
    required String podName,
    required String deltaTemp,
    required String podTemp,
    required String convectiveH,
    required String riskScore,
    required bool isTarget,
  }) {
    final titleColor = isTarget ? AppTheme.marineEmerald : AppTheme.coralAlert;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: titleColor)),
        const SizedBox(height: 2),
        Text(podName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.white), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Water ΔT:", style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            Text(deltaTemp, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: isTarget ? AppTheme.marineEmerald : AppTheme.coralAlert)),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Internal Pod:", style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            Text(podTemp, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: isTarget ? Colors.white : AppTheme.coralAlert)),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Convective (h):", style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            Text(convectiveH, style: const TextStyle(fontSize: 10.5, color: Colors.white)),
          ],
        ),
      ],
    );
  }

  /// Audit banner displayed after a successful workload migration
  Widget _buildMigratedAuditBanner(ExecutionTask task, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.deepPurple.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.deepPurple.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppTheme.marineEmerald, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "✅ Live Migration Executed: Moved from ${task.initialPodName} ➔ ${task.assignedPodName}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Flow Graphic
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                Text(task.initialPodName, style: const TextStyle(fontSize: 10.5, color: AppTheme.coralAlert, fontWeight: FontWeight.bold)),
                const Icon(Icons.arrow_forward_rounded, size: 12, color: AppTheme.brightTeal),
                const Text("Subsea Optical Mesh (14ms)", style: TextStyle(fontSize: 9, color: AppTheme.textMuted)),
                const Icon(Icons.arrow_forward_rounded, size: 12, color: AppTheme.brightTeal),
                Text(task.assignedPodName, style: const TextStyle(fontSize: 10.5, color: AppTheme.marineEmerald, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            "State checkpoint synchronized. Safe thermal boundary layer restored. Seawater ΔT reduced to +${task.currentWaterDeltaTempC.toStringAsFixed(2)}°C.",
            style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String title, String val) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        const SizedBox(height: 1),
        Text(val, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }
}
