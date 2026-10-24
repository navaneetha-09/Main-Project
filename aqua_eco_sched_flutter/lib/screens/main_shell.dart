
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/workload.dart';
import '../models/pod_resource.dart';
import '../models/ocean_condition.dart';
import '../models/execution_task.dart';
import '../models/scheduling_result.dart';
import '../services/data_service.dart';
import '../services/scheduler_engine.dart';
import '../theme/app_theme.dart';
import 'tabs/scheduler_tab.dart';
import 'tabs/pods_telemetry_tab.dart';
import 'tabs/sensitivity_tab.dart';
import 'tabs/baseline_tab.dart';
import 'tabs/execution_tab.dart';
import 'tabs/data_quality_tab.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentTabIndex = 0;

  late List<Workload> _workloads;
  late List<PodResource> _pods;
  late List<OceanCondition> _oceanConditions;
  late DataValidationReport _validationReport;

  late Workload _selectedWorkload;
  SchedulingWeights _weights = const SchedulingWeights();
  final RiskBudgetConstraints _constraints = const RiskBudgetConstraints();

  final List<ExecutionTask> _activeTasks = [];
  final List<Workload> _futureWorkloadQueue = [];
  int _taskCounter = 1;

  // Real-time environmental simulator state
  double _envTempShift = 0.0;
  double _envCurrentMult = 1.0;
  double _envCarbonMult = 1.0;
  bool _isLiveTelemetry = false;
  late String _runId;
  final List<Workload> _customWorkloads = [];
  final List<PodResource> _customPods = [];
  final List<OceanCondition> _customOceanConditions = [];

  @override
  void initState() {
    super.initState();
    _workloads = [...DataService.getDefaultWorkloads(), ..._customWorkloads];
    _pods = [...DataService.getDefaultPods(), ..._customPods];
    _oceanConditions = [...DataService.getDefaultOceanConditions(), ..._customOceanConditions];
    _validationReport = DataService.validateData(_workloads, _pods, _oceanConditions);
    _selectedWorkload = _workloads.first;
    _runId = "RUN-${DateTime.now().toUtc().toIso8601String().substring(0, 19).replaceAll(':', '').replaceAll('-', '')}";
  }

  void _recomputeOceanConditions() {
    final now = DateTime.now().toUtc();
    final secondsOfDay = now.hour * 3600 + now.minute * 60 + now.second;
    final tidalPhase = (2 * math.pi * secondsOfDay) / 44712.0;
    final solarPhase = (2 * math.pi * secondsOfDay) / 86400.0;

    final base = [...DataService.getDefaultOceanConditions(), ..._customOceanConditions];
    setState(() {
      _oceanConditions = base.map((o) {
        final tidalFactor = _isLiveTelemetry ? (1.0 + 0.15 * math.sin(tidalPhase)) : 1.0;
        final solarDrift = _isLiveTelemetry ? (0.35 * math.sin(solarPhase - math.pi / 2)) : 0.0;
        final carbonFactor = _isLiveTelemetry ? (1.0 + 0.12 * math.sin(solarPhase)) : 1.0;

        final t = (o.waterTemperatureC + solarDrift + _envTempShift).clamp(-2.0, 35.0);
        final c = (o.currentSpeedMps * tidalFactor * _envCurrentMult).clamp(0.05, 5.0);
        final g = (o.gridCarbonIntensityKgPerKwh * carbonFactor * _envCarbonMult).clamp(0.01, 1.5);

        return OceanCondition(
          podId: o.podId,
          timestamp: _isLiveTelemetry ? now : o.timestamp,
          waterTemperatureC: double.parse(t.toStringAsFixed(2)),
          currentSpeedMps: double.parse(c.toStringAsFixed(2)),
          currentDirectionDeg: o.currentDirectionDeg,
          salinityPsu: o.salinityPsu,
          depthM: o.depthM,
          ecologicalZone: o.ecologicalZone,
          gridCarbonIntensityKgPerKwh: double.parse(g.toStringAsFixed(4)),
          ambientTurbidityNtu: o.ambientTurbidityNtu,
        );
      }).toList();
    });
  }

  void _syncLiveRealtimeTelemetry() {
    setState(() {
      _isLiveTelemetry = true;
    });
    _recomputeOceanConditions();
  }

  void _dispatchWorkload(PodScoreRecord bestPod) {
    final now = DateTime.now().toUtc();
    final taskId = "MISSION-${_taskCounter.toString().padLeft(4, '0')}";
    _taskCounter++;

    final ambientTemp = (bestPod.localWaterTempC - bestPod.deltaTempC).clamp(0.0, 35.0);
    final newTask = ExecutionTask(
      taskId: taskId,
      workloadId: _selectedWorkload.id,
      workloadType: _selectedWorkload.type,
      assignedPodId: bestPod.podId,
      assignedPodName: bestPod.podName,
      initialPodId: bestPod.podId,
      initialPodName: bestPod.podName,
      status: "RUNNING",
      progressPct: 0.0,
      startTime: "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} UTC",
      cpuAllocated: _selectedWorkload.cpuCores,
      gpuAllocated: _selectedWorkload.gpuUnits,
      ramAllocated: _selectedWorkload.ramGb,
      durationHours: _selectedWorkload.durationHours,
      energyConsumedKwh: bestPod.energyKwh,
      carbonEmittedKg: bestPod.carbonKgCo2e,
      currentWaterDeltaTempC: bestPod.deltaTempC,
      currentPodTempC: bestPod.internalPodTempC,
      ambientWaterTempC: ambientTemp,
      currentConvectiveHWm2k: bestPod.convectiveHWm2k,
      thermalFootprintScore: bestPod.normThermal,
      environmentalRiskScore: bestPod.normRisk,
      isThermalAlert: false,
      telemetryHistory: [
        TelemetryDataPoint(
          timestamp: now,
          deltaTempC: bestPod.deltaTempC,
          internalPodTempC: bestPod.internalPodTempC,
          ambientTempC: ambientTemp,
          convectiveHWm2k: bestPod.convectiveHWm2k,
          isThermalBreached: false,
        ),
      ],
      logs: [
        "[${now.toIso8601String()}] Workload ${_selectedWorkload.id} dispatched to ${bestPod.podName}.",
        "[${now.toIso8601String()}] Subsea hull convective cooling active (h = ${bestPod.convectiveHWm2k.toStringAsFixed(0)} W/m²K).",
        "[${now.toIso8601String()}] Seawater ΔT rise: +${bestPod.deltaTempC.toStringAsFixed(2)}°C (Within budget).",
      ],
    );

    // If active workload was in the future workload queue, auto-dequeue it
    final queueIndex = _futureWorkloadQueue.indexWhere((w) => w.id == _selectedWorkload.id);
    if (queueIndex != -1) {
      _futureWorkloadQueue.removeAt(queueIndex);
    }

    setState(() {
      _activeTasks.insert(0, newTask);
      _currentTabIndex = 4; // Switch to execution tab

      // If future queue still has workloads, pre-select the head for next dispatch
      if (_futureWorkloadQueue.isNotEmpty) {
        _selectedWorkload = _futureWorkloadQueue.first;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.bioluminescentCyan,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Text(
          "🚀 Workload ${newTask.workloadId} allocated to ${bestPod.podName}! Switched to Mission Execution.",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _registerNewPod(PodResource newPod, OceanCondition newCondition) {
    setState(() {
      _customPods.removeWhere((p) => p.id == newPod.id);
      _customPods.add(newPod);
      _customOceanConditions.removeWhere((o) => o.podId == newCondition.podId);
      _customOceanConditions.add(newCondition);

      final podMap = {for (var p in DataService.getDefaultPods()) p.id: p};
      for (var cp in _customPods) {
        podMap[cp.id] = cp;
      }
      _pods = podMap.values.toList();

      final oceanMap = {for (var o in _oceanConditions) o.podId: o};
      oceanMap[newCondition.podId] = newCondition;
      _oceanConditions = oceanMap.values.toList();

      _validationReport = DataService.validateData(_workloads, _pods, _oceanConditions);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Subsea Pod ${newPod.name} (${newPod.id}) deployed into active fleet!"),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.marineEmerald,
      ),
    );
  }

  void _registerNewWorkload(Workload newWorkload) {
    setState(() {
      _customWorkloads.removeWhere((w) => w.id == newWorkload.id);
      _customWorkloads.add(newWorkload);

      final wlMap = {for (var w in DataService.getDefaultWorkloads()) w.id: w};
      for (var cw in _customWorkloads) {
        wlMap[cw.id] = cw;
      }
      _workloads = wlMap.values.toList();
      _selectedWorkload = newWorkload;
      _validationReport = DataService.validateData(_workloads, _pods, _oceanConditions);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Workload ${newWorkload.id} (${newWorkload.type}) registered and selected!"),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.marineEmerald,
      ),
    );
  }

  void _advanceTaskProgress(String taskId, double deltaPct) {
    setState(() {
      final task = _activeTasks.firstWhere((t) => t.taskId == taskId);
      task.progressPct = (task.progressPct + deltaPct).clamp(0.0, 100.0);
      final now = DateTime.now().toUtc();

      // Telemetry update: slight natural fluctuation based on progress
      final slightFluct = (math.sin(task.progressPct / 15.0) * 0.08);
      final currentDelta = (task.currentWaterDeltaTempC + slightFluct).clamp(0.1, 4.0);
      task.telemetryHistory.add(
        TelemetryDataPoint(
          timestamp: now,
          deltaTempC: currentDelta,
          internalPodTempC: task.currentPodTempC + (slightFluct * 1.5),
          ambientTempC: task.ambientWaterTempC,
          convectiveHWm2k: task.currentConvectiveHWm2k,
          isThermalBreached: task.isThermalAlert,
        ),
      );

      if (task.progressPct >= 100.0) {
        task.status = "COMPLETED";
        task.completionTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} UTC";
        task.logs.add("[${now.toIso8601String()}] Workload completed successfully. Subsea compute resources deallocated.");
      } else {
        task.logs.add("[${now.toIso8601String()}] Execution checkpoint: ${task.progressPct.toInt()}% completed.");
      }
    });
  }

  void _triggerTaskThermalSpike(String taskId) {
    setState(() {
      final task = _activeTasks.firstWhere((t) => t.taskId == taskId);
      final now = DateTime.now().toUtc();

      task.currentWaterDeltaTempC = 2.88; // Exceeds 2.50°C budget limit!
      task.currentPodTempC = 47.4; // Exceeds 45.0°C limit!
      task.ambientWaterTempC += 4.5;
      task.currentConvectiveHWm2k = 380.0;
      task.thermalFootprintScore = 0.88;
      task.environmentalRiskScore = 0.76;
      task.isThermalAlert = true;
      task.thermalAlertReason = "Seawater ΔT rise (+2.88°C) exceeds safety budget (2.50°C). Local ocean cooling boundary layer saturated.";

      final wl = _workloads.firstWhere(
        (w) => w.id == task.workloadId,
        orElse: () => _selectedWorkload,
      );

      final targetPod = SchedulerEngine.findMigrationTarget(
        workload: wl,
        currentPodId: task.assignedPodId,
        pods: _pods,
        oceanConditions: _oceanConditions,
        weights: _weights,
        constraints: _constraints,
      );

      task.suggestedTargetPod = targetPod;

      task.telemetryHistory.add(
        TelemetryDataPoint(
          timestamp: now,
          deltaTempC: task.currentWaterDeltaTempC,
          internalPodTempC: task.currentPodTempC,
          ambientTempC: task.ambientWaterTempC,
          convectiveHWm2k: task.currentConvectiveHWm2k,
          isThermalBreached: true,
        ),
      );

      task.logs.add("[${now.toIso8601String()}] 🚨 THERMAL ALERT: Seawater ΔT spiked to +2.88°C (Limit: 2.50°C). Internal temp: 47.4°C.");
      if (targetPod != null) {
        task.logs.add("[${now.toIso8601String()}] 🔍 Dynamic Migration Evaluator selected target: ${targetPod.podName} (${targetPod.podId}) with ΔT = +${targetPod.deltaTempC.toStringAsFixed(2)}°C.");
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppTheme.coralAlert,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
        content: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "🚨 Seawater Thermal Spike Detected (+2.88°C)! Workload migration evaluated.",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _migrateTask(String taskId, PodScoreRecord targetPod) {
    setState(() {
      final task = _activeTasks.firstWhere((t) => t.taskId == taskId);
      final now = DateTime.now().toUtc();
      final oldPodId = task.assignedPodId;
      final oldPodName = task.assignedPodName;

      final tempBefore = task.currentPodTempC;
      final deltaTempBefore = task.currentWaterDeltaTempC;

      task.status = "MIGRATED_RUNNING";
      task.isMigrated = true;
      task.migratedFromPodId = oldPodId;
      task.migratedFromPodName = oldPodName;
      task.assignedPodId = targetPod.podId;
      task.assignedPodName = targetPod.podName;
      task.migrationTimestamp = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} UTC";
      task.migrationReason = "Thermal surge & Seawater ΔT budget breach on $oldPodName (+${deltaTempBefore.toStringAsFixed(2)}°C). Migrated to high-flow convective pod.";

      // Restore safe thermal metrics on target pod
      task.currentWaterDeltaTempC = targetPod.deltaTempC;
      task.currentPodTempC = targetPod.internalPodTempC;
      task.ambientWaterTempC = (targetPod.localWaterTempC - targetPod.deltaTempC).clamp(0.0, 35.0);
      task.currentConvectiveHWm2k = targetPod.convectiveHWm2k;
      task.thermalFootprintScore = targetPod.normThermal;
      task.environmentalRiskScore = targetPod.normRisk;
      task.isThermalAlert = false;
      task.thermalAlertReason = null;
      task.suggestedTargetPod = null;

      task.migrationHistory.add(
        MigrationRecord(
          timestamp: now,
          fromPodId: oldPodId,
          fromPodName: oldPodName,
          toPodId: targetPod.podId,
          toPodName: targetPod.podName,
          reason: task.migrationReason!,
          tempBefore: tempBefore,
          tempAfter: targetPod.internalPodTempC,
          deltaTempBefore: deltaTempBefore,
          deltaTempAfter: targetPod.deltaTempC,
        ),
      );

      task.telemetryHistory.add(
        TelemetryDataPoint(
          timestamp: now,
          deltaTempC: targetPod.deltaTempC,
          internalPodTempC: targetPod.internalPodTempC,
          ambientTempC: task.ambientWaterTempC,
          convectiveHWm2k: targetPod.convectiveHWm2k,
          isThermalBreached: false,
        ),
      );

      final dropPct = (((deltaTempBefore - targetPod.deltaTempC) / deltaTempBefore) * 100).toInt();
      task.logs.add("[${now.toIso8601String()}] 🔄 Live container state checkpointed (RAM: ${task.ramAllocated.toInt()} GB). Transmitting over optical mesh...");
      task.logs.add("[${now.toIso8601String()}] 🚀 Workload successfully migrated to ${targetPod.podName} (${targetPod.podId}).");
      task.logs.add("[${now.toIso8601String()}] ❄️ Seawater ΔT dropped from +${deltaTempBefore.toStringAsFixed(2)}°C to +${targetPod.deltaTempC.toStringAsFixed(2)}°C (-$dropPct% cooler).");
      task.logs.add("[${now.toIso8601String()}] 🌿 Thermal compliance restored. Workload resuming execution seamlessly at ${task.progressPct.toInt()}%.");
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.marineEmerald,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "✅ Live Migration Complete: Resumed on ${targetPod.podName}!",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: AppTheme.abyssNavy,
      appBar: _buildTopAppBar(isMobile),
      drawer: isMobile ? _buildMobileDrawer() : null,
      body: isMobile
          ? SafeArea(child: _buildCurrentTab())
          : Row(
              children: [
                _buildNavigationRail(),
                Expanded(child: _buildCurrentTab()),
              ],
            ),
      bottomNavigationBar: isMobile ? _buildMobileBottomBar() : null,
    );
  }

  PreferredSizeWidget _buildTopAppBar(bool isMobile) {
    return AppBar(
      backgroundColor: AppTheme.deepSeaCard,
      elevation: 0,
      titleSpacing: isMobile ? 8 : 20,
      leading: isMobile
          ? Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu_rounded, color: AppTheme.brightTeal),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            )
          : null,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.bioluminescentCyan, AppTheme.marineEmerald]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.waves_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          const Flexible(
            child: Text(
              "AquaEcoSched",
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -0.5, color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!isMobile) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Text(
                _runId,
                style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (_isLiveTelemetry ? AppTheme.marineEmerald : AppTheme.bioluminescentCyan).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: (_isLiveTelemetry ? AppTheme.marineEmerald : AppTheme.bioluminescentCyan).withOpacity(0.4)),
              ),
              child: Text(
                _isLiveTelemetry ? "● REAL-TIME STREAM" : "● 30 POD FLEET",
                style: TextStyle(fontSize: 9.5, color: _isLiveTelemetry ? AppTheme.marineEmerald : AppTheme.bioluminescentCyan, fontWeight: FontWeight.bold),
              ),
            ),
            if (_futureWorkloadQueue.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.warningAmber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.warningAmber.withOpacity(0.4)),
                ),
                child: Text(
                  "Queue: ${_futureWorkloadQueue.length} Pending",
                  style: const TextStyle(fontSize: 9.5, color: AppTheme.warningAmber, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ],
      ),
      actions: [
        if (isMobile)
          IconButton(
            icon: const Icon(Icons.fact_check_outlined, color: AppTheme.brightTeal, size: 20),
            tooltip: "Dataset Quality",
            onPressed: () => setState(() => _currentTabIndex = 5),
          ),
        const SizedBox(width: 6),
      ],
    );
  }

  Widget _buildMobileBottomBar() {
    final activeCount = _activeTasks.where((t) => t.status != "COMPLETED").length;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.deepSeaCard,
        border: Border(top: BorderSide(color: AppTheme.subseaBorder, width: 0.8)),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentTabIndex > 4 ? 0 : _currentTabIndex,
        onTap: (idx) => setState(() => _currentTabIndex = idx),
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.brightTeal,
        unselectedItemColor: AppTheme.textSecondary.withOpacity(0.6),
        selectedFontSize: 10.5,
        unselectedFontSize: 10,
        items: [
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: _futureWorkloadQueue.isNotEmpty,
              label: Text("${_futureWorkloadQueue.length}", style: const TextStyle(fontSize: 8)),
              backgroundColor: AppTheme.warningAmber,
              textColor: Colors.black,
              child: const Icon(Icons.recommend_rounded),
            ),
            label: "Scheduler",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.dns_rounded),
            label: "Pods",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.tune_rounded),
            label: "Weights",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.balance_rounded),
            label: "Baselines",
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: activeCount > 0,
              label: Text("$activeCount", style: const TextStyle(fontSize: 9)),
              backgroundColor: AppTheme.marineEmerald,
              textColor: Colors.black,
              child: const Icon(Icons.rocket_launch_rounded),
            ),
            label: "Missions",
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDrawer() {
    return Drawer(
      backgroundColor: AppTheme.deepSeaCard,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.subseaBorder)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppTheme.bioluminescentCyan, AppTheme.marineEmerald]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.waves_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("AquaEcoSched", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                      Text("Subsea Orchestration", style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                children: [
                  _drawerItem(0, Icons.recommend_rounded, "Scheduler & Decision", badge: _futureWorkloadQueue.length),
                  _drawerItem(1, Icons.dns_rounded, "Fleet Resources & Telemetry"),
                  _drawerItem(2, Icons.tune_rounded, "Sensitivity Analysis"),
                  _drawerItem(3, Icons.balance_rounded, "Baseline Policy Evaluation"),
                  _drawerItem(4, Icons.rocket_launch_rounded, "Mission Execution", badge: _activeTasks.where((t) => t.status != "COMPLETED").length),
                  _drawerItem(5, Icons.fact_check_rounded, "Dataset Diagnostics"),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.oceanCardLight.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.subseaBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: AppTheme.marineEmerald, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Risk Policy Enforced", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white)),
                        Text("Max Seawater ΔT: ${_constraints.maxWaterTempDeltaC}°C", style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(int index, IconData icon, String title, {int badge = 0}) {
    final isSelected = _currentTabIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppTheme.brightTeal : AppTheme.textSecondary, size: 20),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : AppTheme.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontSize: 13,
        ),
      ),
      trailing: badge > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: AppTheme.marineEmerald, borderRadius: BorderRadius.circular(10)),
              child: Text("$badge", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
            )
          : null,
      selected: isSelected,
      selectedTileColor: AppTheme.bioluminescentCyan.withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: () {
        Navigator.pop(context); // Close drawer
        setState(() => _currentTabIndex = index);
      },
    );
  }

  Widget _buildNavigationRail() {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: AppTheme.deepSeaCard,
        border: Border(right: BorderSide(color: AppTheme.subseaBorder)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _navItem(0, Icons.recommend_rounded, "Scheduler & Decision", badgeCount: _futureWorkloadQueue.length),
          _navItem(1, Icons.dns_rounded, "Fleet Resources & Telemetry"),
          _navItem(2, Icons.tune_rounded, "Sensitivity Analysis"),
          _navItem(3, Icons.balance_rounded, "Baseline Policy Evaluation"),
          _navItem(4, Icons.rocket_launch_rounded, "Mission Execution", badgeCount: _activeTasks.where((t) => t.status != "COMPLETED").length),
          _navItem(5, Icons.fact_check_rounded, "Dataset Diagnostics"),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.oceanCardLight.withOpacity(0.4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.subseaBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: AppTheme.marineEmerald, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Risk Policy Active", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white)),
                      Text("Max ΔT: ${_constraints.maxWaterTempDeltaC}°C", style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String title, {int badgeCount = 0}) {
    final isSelected = _currentTabIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: InkWell(
        onTap: () => setState(() => _currentTabIndex = index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.bioluminescentCyan.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.bioluminescentCyan.withOpacity(0.5) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: isSelected ? AppTheme.brightTeal : AppTheme.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
              ),
              if (badgeCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.marineEmerald,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "$badgeCount",
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentTabIndex) {
      case 0:
        return SchedulerTab(
          currentWorkload: _selectedWorkload,
          allWorkloads: _workloads,
          pods: _pods,
          oceanConditions: _oceanConditions,
          weights: _weights,
          constraints: _constraints,
          futureWorkloadQueue: _futureWorkloadQueue,
          onWorkloadChanged: (w) => setState(() {
            _selectedWorkload = w;
            final idx = _workloads.indexWhere((item) => item.id == w.id);
            if (idx != -1) {
              _workloads = List.from(_workloads)..[idx] = w;
            }
          }),
          onWeightsChanged: (w) => setState(() => _weights = w),
          onDispatchWorkload: _dispatchWorkload,
          onEnqueueWorkload: (w) {
            setState(() => _futureWorkloadQueue.add(w));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Workload ${w.id} queued for future mission!"),
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppTheme.marineEmerald,
              ),
            );
          },
          onDequeueWorkload: (id) => setState(() => _futureWorkloadQueue.removeWhere((w) => w.id == id)),
          onClearQueue: () => setState(() => _futureWorkloadQueue.clear()),
          onCreateCustomWorkload: _registerNewWorkload,
          onCreatePod: _registerNewPod,
        );
      case 1:
        return PodsTelemetryTab(
          pods: _pods,
          oceanConditions: _oceanConditions,
          maxDeltaTempLimit: _constraints.maxWaterTempDeltaC,
          envTempShift: _envTempShift,
          envCurrentMult: _envCurrentMult,
          envCarbonMult: _envCarbonMult,
          isLiveTelemetry: _isLiveTelemetry,
          onCreatePod: _registerNewPod,
          onUpdateModifiers: (t, c, g) {
            setState(() {
              _envTempShift = t;
              _envCurrentMult = c;
              _envCarbonMult = g;
            });
            _recomputeOceanConditions();
          },
          onSyncLiveTelemetry: () {
            _syncLiveRealtimeTelemetry();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("⚡ Synchronized live real-time ocean telemetry across 30 buoys!"),
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppTheme.bioluminescentCyan,
              ),
            );
          },
        );
      case 2:
        return SensitivityTab(
          weights: _weights,
          onWeightsChanged: (w) => setState(() => _weights = w),
          onNavigateToScheduler: () => setState(() => _currentTabIndex = 0),
        );
      case 3:
        return BaselineTab(
          currentWorkload: _selectedWorkload,
          pods: _pods,
          oceanConditions: _oceanConditions,
          weights: _weights,
          constraints: _constraints,
        );
      case 4:
        return ExecutionTab(
          activeTasks: _activeTasks,
          pods: _pods,
          oceanConditions: _oceanConditions,
          weights: _weights,
          constraints: _constraints,
          onAdvanceProgress: _advanceTaskProgress,
          onTriggerThermalSpike: _triggerTaskThermalSpike,
          onExecuteMigration: _migrateTask,
        );
      case 5:
        return DataQualityTab(
          report: _validationReport,
          workloads: _workloads,
          pods: _pods,
          oceanConditions: _oceanConditions,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
