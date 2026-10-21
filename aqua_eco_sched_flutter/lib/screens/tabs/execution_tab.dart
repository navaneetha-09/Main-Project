import 'package:flutter/material.dart';
import '../../models/execution_task.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_container.dart';

class ExecutionTab extends StatelessWidget {
  final List<ExecutionTask> activeTasks;
  final Function(String, double) onAdvanceProgress;

  const ExecutionTab({
    super.key,
    required this.activeTasks,
    required this.onAdvanceProgress,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 14 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "🚀 Subsea Mission Execution & Telemetry Stream",
            style: TextStyle(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            "Live tracking of simulated workload execution on submerged pod pressure hulls and ocean cooling dynamics.",
            style: TextStyle(fontSize: isMobile ? 11.5 : 13, color: AppTheme.textSecondary.withOpacity(0.9)),
          ),
          const SizedBox(height: 18),

          if (activeTasks.isEmpty) ...[
            GlassContainer(
              padding: EdgeInsets.all(isMobile ? 20 : 32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.sensors_off_rounded, size: 48, color: AppTheme.textSecondary.withOpacity(0.5)),
                    const SizedBox(height: 12),
                    const Text(
                      "No active subsea execution task",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Navigate to '🎯 Scheduler & Decision' tab and click 'Launch Simulation' on the recommended pod to deploy a workload.",
                      style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary.withOpacity(0.8)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            ...activeTasks.map((task) => _buildTaskExecutionCard(task, isMobile)),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskExecutionCard(ExecutionTask task, bool isMobile) {
    final isDone = task.status == "COMPLETED";
    final statusColor = isDone ? AppTheme.marineEmerald : AppTheme.bioluminescentCyan;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18.0),
      child: GlassContainer(
        padding: EdgeInsets.all(isMobile ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isMobile) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withOpacity(0.5)),
                    ),
                    child: Text(
                      task.status,
                      style: TextStyle(color: statusColor, fontSize: 10.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    task.taskId,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                "Assigned Pod: ${task.assignedPodName} (${task.assignedPodId})",
                style: const TextStyle(color: AppTheme.brightTeal, fontWeight: FontWeight.w600, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: statusColor.withOpacity(0.5)),
                        ),
                        child: Text(
                          task.status,
                          style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        task.taskId,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  Text(
                    "Assigned Pod: ${task.assignedPodName} (${task.assignedPodId})",
                    style: const TextStyle(color: AppTheme.brightTeal, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              "${task.workloadType} • ${task.workloadId}",
              style: TextStyle(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(height: 12),

            // Progress Bar
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (task.progressPct / 100.0).clamp(0.0, 1.0),
                      backgroundColor: const Color(0xFF1B2F4C),
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      minHeight: 9,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "${task.progressPct.toInt()}%",
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Hardware & Energy Footprint Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.oceanCardLight.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: isMobile
                  ? Wrap(
                      spacing: 14,
                      runSpacing: 10,
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
            const SizedBox(height: 14),

            // Interactive Controls
            if (!isDone) ...[
              if (isMobile) ...[
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => onAdvanceProgress(task.taskId, 25.0),
                        icon: const Icon(Icons.fast_forward_rounded, size: 16, color: Colors.white),
                        label: const Text("Advance Progress (+25%)", style: TextStyle(color: Colors.white, fontSize: 12.5)),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.bioluminescentCyan),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => onAdvanceProgress(task.taskId, 100.0),
                        icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
                        label: const Text("Complete Workload (100%)", style: TextStyle(color: Colors.white, fontSize: 12.5)),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.marineEmerald),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => onAdvanceProgress(task.taskId, 25.0),
                      icon: const Icon(Icons.fast_forward_rounded, size: 16, color: Colors.white),
                      label: const Text("Advance Progress (+25%)", style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.bioluminescentCyan),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () => onAdvanceProgress(task.taskId, 100.0),
                      icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
                      label: const Text("Complete Workload (100%)", style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.marineEmerald),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
            ],

            // Terminal Telemetry Logs
            const Text(
              "📋 Telemetry Event Stream:",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF040A14),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: task.logs.map((log) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text(
                      log,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppTheme.brightTeal),
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

  Widget _statItem(String title, String val) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary)),
        const SizedBox(height: 2),
        Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }
}
