import 'package:flutter/material.dart';
import '../../models/workload.dart';
import '../../models/pod_resource.dart';
import '../../models/ocean_condition.dart';
import '../../models/scheduling_result.dart';
import '../../services/scheduler_engine.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/score_breakdown_chart.dart';

class SchedulerTab extends StatefulWidget {
  final Workload currentWorkload;
  final List<Workload> allWorkloads;
  final List<PodResource> pods;
  final List<OceanCondition> oceanConditions;
  final SchedulingWeights weights;
  final RiskBudgetConstraints constraints;
  final List<Workload> futureWorkloadQueue;
  final Function(Workload) onWorkloadChanged;
  final Function(SchedulingWeights) onWeightsChanged;
  final Function(PodScoreRecord) onDispatchWorkload;
  final Function(Workload) onEnqueueWorkload;
  final Function(String) onDequeueWorkload;
  final VoidCallback onClearQueue;
  final Function(Workload) onCreateCustomWorkload;
  final Function(PodResource, OceanCondition)? onCreatePod;

  const SchedulerTab({
    super.key,
    required this.currentWorkload,
    required this.allWorkloads,
    required this.pods,
    required this.oceanConditions,
    required this.weights,
    required this.constraints,
    required this.futureWorkloadQueue,
    required this.onWorkloadChanged,
    required this.onWeightsChanged,
    required this.onDispatchWorkload,
    required this.onEnqueueWorkload,
    required this.onDequeueWorkload,
    required this.onClearQueue,
    required this.onCreateCustomWorkload,
    this.onCreatePod,
  });

  @override
  State<SchedulerTab> createState() => _SchedulerTabState();
}

class _SchedulerTabState extends State<SchedulerTab> {
  bool _showFineTuner = false;
  bool _showCreateForm = false;
  bool _showQueue = false;
  bool _showWeightsPanel = false;
  bool _showCreatePodForm = false;

  // New Workload Form Controllers
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _typeController = TextEditingController(text: "Benthic Hydrothermal Genomics");
  final TextEditingController _descController = TextEditingController(text: "High-throughput metagenomic marine pipeline");
  double _newCpu = 32.0;
  double _newGpu = 4.0;
  double _newRam = 128.0;
  double _newStorage = 500.0;
  double _newRuntime = 6.0;
  String _newPriority = "HIGH";

  // New Pod Form Controllers & State
  final TextEditingController _podIdController = TextEditingController();
  final TextEditingController _podNameController = TextEditingController(text: "AquaVent-Pod-Alpha");
  final TextEditingController _podLocController = TextEditingController(text: "Mariana Deep Trench (Pacific)");
  double _newPodCpu = 128.0;
  double _newPodUsedCpu = 16.0;
  double _newPodGpu = 16.0;
  double _newPodUsedGpu = 2.0;
  double _newPodRam = 512.0;
  final double _newPodUsedRam = 64.0;
  double _newPodStorage = 4000.0;
  final double _newPodUsedStorage = 600.0;
  double _newPodLatency = 14.5;
  final double _newPodBasePower = 22.0;
  final double _newPodMaxPower = 115.0;
  final double _newPodPue = 1.05;
  double _newPodTemp = 4.5;
  double _newPodCurrent = 1.1;
  final double _newPodDepth = 150.0;
  final String _newPodZone = "LOW_IMPACT";
  double _newPodCarbon = 0.045;
  final String _newPodStatus = "ACTIVE";

  @override
  void initState() {
    super.initState();
    _idController.text = "WL-CUSTOM-${(widget.allWorkloads.length + 1).toString().padLeft(2, '0')}";
    _podIdController.text = "POD-CUSTOM-${(widget.pods.length + 1).toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _idController.dispose();
    _typeController.dispose();
    _descController.dispose();
    _podIdController.dispose();
    _podNameController.dispose();
    _podLocController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final decision = SchedulerEngine.schedule(
      workload: widget.currentWorkload,
      pods: widget.pods,
      oceanConditions: widget.oceanConditions,
      weights: widget.weights,
      constraints: widget.constraints,
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Workload Profile Selector Bar with Quick Actions
          _buildWorkloadSelector(context, isMobile),
          const SizedBox(height: 10),

          // Quick Objective Presets Bar (Always visible for instant feedback!)
          _buildQuickPresetsBar(isMobile),
          const SizedBox(height: 12),

          // Collapsible Panels (Weights Fine-Tuning, Create Workload, Fine-Tuner, Future Queue, Create Pod)
          if (_showWeightsPanel) ...[
            _buildWeightsPanel(isMobile),
            const SizedBox(height: 12),
          ],
          if (_showCreateForm) ...[
            _buildCreateWorkloadForm(isMobile),
            const SizedBox(height: 12),
          ],
          if (_showCreatePodForm) ...[
            _buildCreatePodForm(isMobile),
            const SizedBox(height: 12),
          ],
          if (_showFineTuner) ...[
            _buildFineTunerSliders(isMobile),
            const SizedBox(height: 12),
          ],
          if (_showQueue) ...[
            _buildFutureWorkloadQueue(isMobile),
            const SizedBox(height: 12),
          ],

          // Top Recommendation Hero Card (Kept immediately visible for tests and usability)
          if (decision.isSuccess) ...[
            _buildTopRecommendationHero(context, decision.selectedPod!, isMobile),
            const SizedBox(height: 14),
            _buildWorkloadSpecRibbon(widget.currentWorkload, isMobile),
            const SizedBox(height: 14),
            _buildMetricRibbon(decision.selectedPod!),
            const SizedBox(height: 16),
            _buildExplainableDecisionBox(decision),
            const SizedBox(height: 18),
            _buildRankedPodsSection(context, decision, isMobile),
          ] else ...[
            _buildInfeasibleBanner(decision),
          ],

          if (decision.ineligiblePods.isNotEmpty) ...[
            const SizedBox(height: 18),
            _buildRejectionsAudit(decision),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkloadSelector(BuildContext context, bool isMobile) {
    return GlassContainer(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 18, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, color: AppTheme.bioluminescentCyan, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Workload Profile (${widget.allWorkloads.length} Verified):",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Enqueue Quick Action Button
              InkWell(
                onTap: () => widget.onEnqueueWorkload(widget.currentWorkload),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.marineEmerald.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.marineEmerald.withOpacity(0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_task_rounded, size: 12, color: AppTheme.marineEmerald),
                      SizedBox(width: 4),
                      Text("Enqueue", style: TextStyle(color: AppTheme.marineEmerald, fontSize: 10.5, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Workload>(
                value: widget.allWorkloads.firstWhere(
                  (w) => w.id == widget.currentWorkload.id,
                  orElse: () => widget.currentWorkload,
                ),
                dropdownColor: const Color(0xFF131B2E),
                isExpanded: true,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                items: widget.allWorkloads.map((w) {
                  return DropdownMenuItem<Workload>(
                    value: w,
                    child: Text(
                      "${w.id}: ${w.type} (${w.cpuCores.toInt()}C/${w.gpuUnits.toInt()}G, ${w.ramGb.toInt()}GB RAM, ${w.durationHours}h)",
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (newVal) {
                  if (newVal != null) widget.onWorkloadChanged(newVal);
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Tool ribbon buttons
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _actionChip(
                label: "⚖️ Weights Sliders",
                isActive: _showWeightsPanel,
                onTap: () => setState(() {
                  _showWeightsPanel = !_showWeightsPanel;
                  _showFineTuner = false;
                  _showCreateForm = false;
                  _showCreatePodForm = false;
                  _showQueue = false;
                }),
              ),
              _actionChip(
                label: "⚙️ Fine-Tune Specs",
                isActive: _showFineTuner,
                onTap: () => setState(() {
                  _showFineTuner = !_showFineTuner;
                  _showWeightsPanel = false;
                  _showCreateForm = false;
                  _showCreatePodForm = false;
                  _showQueue = false;
                }),
              ),
              _actionChip(
                label: "➕ New Workload",
                isActive: _showCreateForm,
                onTap: () => setState(() {
                  _showCreateForm = !_showCreateForm;
                  _showWeightsPanel = false;
                  _showFineTuner = false;
                  _showCreatePodForm = false;
                  _showQueue = false;
                }),
              ),
              _actionChip(
                label: "🖥️ Add Pod",
                isActive: _showCreatePodForm,
                onTap: () => setState(() {
                  _showCreatePodForm = !_showCreatePodForm;
                  _showWeightsPanel = false;
                  _showFineTuner = false;
                  _showCreateForm = false;
                  _showQueue = false;
                }),
              ),
              _actionChip(
                label: "📅 Future Queue (${widget.futureWorkloadQueue.length})",
                isActive: _showQueue,
                badgeCount: widget.futureWorkloadQueue.length,
                onTap: () => setState(() {
                  _showQueue = !_showQueue;
                  _showWeightsPanel = false;
                  _showFineTuner = false;
                  _showCreateForm = false;
                  _showCreatePodForm = false;
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionChip({required String label, required bool isActive, required VoidCallback onTap, int badgeCount = 0}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.bioluminescentCyan.withOpacity(0.2) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? AppTheme.bioluminescentCyan : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? AppTheme.bioluminescentCyan : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildTopRecommendationHero(BuildContext context, PodScoreRecord best, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: AppTheme.deepSeaCard,
        gradient: const LinearGradient(
          colors: [Color(0xFF131B2E), Color(0xFF18233C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.bioluminescentCyan.withOpacity(0.35), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.marineEmerald.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.marineEmerald.withOpacity(0.5)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, color: AppTheme.marineEmerald, size: 11),
                          SizedBox(width: 4),
                          Text(
                            "RANK 1 POD",
                            style: TextStyle(color: AppTheme.marineEmerald, fontSize: 9.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        best.location,
                        style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.8), fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isMobile)
                ElevatedButton.icon(
                  onPressed: () => widget.onDispatchWorkload(best),
                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                  label: const Text("Launch Simulation", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.bioluminescentCyan,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            best.podName,
            style: TextStyle(
              fontSize: isMobile ? 20 : 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            "Optimal subsea compute vessel balancing clean grid power, convective heat flux, and local benthic safety.",
            style: TextStyle(fontSize: isMobile ? 11.5 : 12.5, color: AppTheme.textSecondary.withOpacity(0.9)),
          ),
          if (isMobile) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => widget.onDispatchWorkload(best),
                icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                label: const Text("Launch Simulation", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.bioluminescentCyan,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkloadSpecRibbon(Workload w, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "📋 Active Workload Resource Specification",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.white),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = isMobile ? (constraints.maxWidth - 12) / 3 : (constraints.maxWidth - 40) / 6;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(width: cardWidth, child: _specCard("CPU", "${w.cpuCores.toInt()} C", "🖥️")),
                SizedBox(width: cardWidth, child: _specCard("GPU", "${w.gpuUnits.toInt()} G", "⚡")),
                SizedBox(width: cardWidth, child: _specCard("RAM", "${w.ramGb.toInt()} GB", "💾")),
                SizedBox(width: cardWidth, child: _specCard("Storage", "${w.storageGb.toInt()} GB", "🗄️")),
                SizedBox(width: cardWidth, child: _specCard("Runtime", "${w.durationHours.toStringAsFixed(1)}h", "⏱️")),
                SizedBox(width: cardWidth, child: _prioCard(w.priority)),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _specCard(String title, String val, String emoji) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 9.5, color: AppTheme.textSecondary)),
              Text(emoji, style: const TextStyle(fontSize: 10)),
            ],
          ),
          const SizedBox(height: 2),
          Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _prioCard(String priority) {
    final color = priority == "HIGH" ? AppTheme.coralAlert : (priority == "MEDIUM" ? AppTheme.warningAmber : AppTheme.marineEmerald);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Priority", style: TextStyle(fontSize: 9.5, color: AppTheme.textSecondary)),
              Text("🏷️", style: TextStyle(fontSize: 10)),
            ],
          ),
          const SizedBox(height: 2),
          Text(priority, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildQuickPresetsBar(bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF101726),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.tune_rounded, size: 14, color: AppTheme.bioluminescentCyan),
          const SizedBox(width: 6),
          const Text(
            "Priority:",
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _presetChip("🌱 Ultra-Green", const SchedulingWeights(energy: 0.10, carbon: 0.60, thermalFootprint: 0.15, environmentalRisk: 0.10, performancePenalty: 0.05)),
                  const SizedBox(width: 6),
                  _presetChip("⚖️ Balanced", const SchedulingWeights(energy: 0.20, carbon: 0.20, thermalFootprint: 0.20, environmentalRisk: 0.20, performancePenalty: 0.20)),
                  const SizedBox(width: 6),
                  _presetChip("🪸 Ecology-First", const SchedulingWeights(energy: 0.05, carbon: 0.10, thermalFootprint: 0.40, environmentalRisk: 0.40, performancePenalty: 0.05)),
                  const SizedBox(width: 6),
                  _presetChip("⚡ Low-Latency", const SchedulingWeights(energy: 0.15, carbon: 0.10, thermalFootprint: 0.15, environmentalRisk: 0.10, performancePenalty: 0.50)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _presetChip(String label, SchedulingWeights preset) {
    final isSelected = widget.weights.energy == preset.energy &&
        widget.weights.carbon == preset.carbon &&
        widget.weights.thermalFootprint == preset.thermalFootprint &&
        widget.weights.environmentalRisk == preset.environmentalRisk &&
        widget.weights.performancePenalty == preset.performancePenalty;

    return GestureDetector(
      onTap: () => widget.onWeightsChanged(preset),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.bioluminescentCyan.withOpacity(0.25) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppTheme.bioluminescentCyan : Colors.white.withOpacity(0.12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppTheme.bioluminescentCyan : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildWeightsPanel(bool isMobile) {
    final norm = widget.weights.toNormalizedMap();
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.bioluminescentCyan.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune_rounded, color: AppTheme.bioluminescentCyan, size: 16),
                  SizedBox(width: 6),
                  Text(
                    "⚖️ Fine-Tune Multi-Objective Weights",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textSecondary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => setState(() => _showWeightsPanel = false),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "Slide weights to re-prioritize. The recommended pod updates in real-time.",
            style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 12),
          _weightSliderRow("⚡ Energy Consumption", widget.weights.energy, norm["energy"]!, AppTheme.warningAmber, (v) => widget.onWeightsChanged(SchedulingWeights(energy: v, carbon: widget.weights.carbon, thermalFootprint: widget.weights.thermalFootprint, environmentalRisk: widget.weights.environmentalRisk, performancePenalty: widget.weights.performancePenalty))),
          _weightSliderRow("🌱 Carbon Intensity", widget.weights.carbon, norm["carbon"]!, AppTheme.marineEmerald, (v) => widget.onWeightsChanged(SchedulingWeights(energy: widget.weights.energy, carbon: v, thermalFootprint: widget.weights.thermalFootprint, environmentalRisk: widget.weights.environmentalRisk, performancePenalty: widget.weights.performancePenalty))),
          _weightSliderRow("🌡️ Thermal Plume", widget.weights.thermalFootprint, norm["thermal_footprint"]!, AppTheme.coralAlert, (v) => widget.onWeightsChanged(SchedulingWeights(energy: widget.weights.energy, carbon: widget.weights.carbon, thermalFootprint: v, environmentalRisk: widget.weights.environmentalRisk, performancePenalty: widget.weights.performancePenalty))),
          _weightSliderRow("🛡️ Marine Eco-Risk", widget.weights.environmentalRisk, norm["environmental_risk"]!, AppTheme.bioluminescentCyan, (v) => widget.onWeightsChanged(SchedulingWeights(energy: widget.weights.energy, carbon: widget.weights.carbon, thermalFootprint: widget.weights.thermalFootprint, environmentalRisk: v, performancePenalty: widget.weights.performancePenalty))),
          _weightSliderRow("🚀 Performance & Latency", widget.weights.performancePenalty, norm["performance_penalty"]!, AppTheme.deepPurple, (v) => widget.onWeightsChanged(SchedulingWeights(energy: widget.weights.energy, carbon: widget.weights.carbon, thermalFootprint: widget.weights.thermalFootprint, environmentalRisk: widget.weights.environmentalRisk, performancePenalty: v))),
        ],
      ),
    );
  }

  Widget _weightSliderRow(String label, double rawVal, double normVal, Color color, Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              Text("w: ${rawVal.toStringAsFixed(2)} (${(normVal * 100).toStringAsFixed(0)}%)", style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 2.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              activeTrackColor: color,
              inactiveTrackColor: const Color(0xFF1E293B),
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: rawVal,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFineTunerSliders(bool isMobile) {
    final w = widget.currentWorkload;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.bioluminescentCyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("⚙️ Live Workload Resource Tuner", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.white)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _sliderInput("CPU Cores", w.cpuCores, 1.0, 256.0, 2.0, (v) => widget.onWorkloadChanged(w.copyWith(cpuCores: v)), "${w.cpuCores.toInt()} Cores"),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _sliderInput("GPU Units", w.gpuUnits, 0.0, 64.0, 1.0, (v) => widget.onWorkloadChanged(w.copyWith(gpuUnits: v)), "${w.gpuUnits.toInt()} Units"),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _sliderInput("RAM Memory", w.ramGb, 4.0, 1024.0, 8.0, (v) => widget.onWorkloadChanged(w.copyWith(ramGb: v)), "${w.ramGb.toInt()} GB"),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _sliderInput("Storage Disk", w.storageGb, 10.0, 5000.0, 50.0, (v) => widget.onWorkloadChanged(w.copyWith(storageGb: v)), "${w.storageGb.toInt()} GB"),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _sliderInput("Runtime (Hours)", w.durationHours, 0.5, 72.0, 0.5, (v) => widget.onWorkloadChanged(w.copyWith(durationHours: v)), "${w.durationHours.toStringAsFixed(1)} hrs"),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Priority", style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    const SizedBox(height: 3),
                    Row(
                      children: ["HIGH", "MEDIUM", "LOW"].map((p) {
                        final isSel = w.priority == p;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () => widget.onWorkloadChanged(w.copyWith(priority: p)),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: isSel ? (p == "HIGH" ? AppTheme.coralAlert : AppTheme.marineEmerald) : const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(p, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: isSel ? Colors.white : AppTheme.textSecondary)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sliderInput(String label, double val, double min, double max, double step, Function(double) onChanged, String displayVal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 4),
            Text(displayVal, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 2.5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            activeTrackColor: AppTheme.bioluminescentCyan,
            inactiveTrackColor: const Color(0xFF1E293B),
            thumbColor: Colors.white,
            overlayColor: AppTheme.bioluminescentCyan.withOpacity(0.2),
          ),
          child: Slider(
            value: val.clamp(min, max),
            min: min,
            max: max,
            divisions: ((max - min) / step).round(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildCreateWorkloadForm(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.marineEmerald.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.add_box_rounded, color: AppTheme.marineEmerald, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Register New Computational Workload",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(flex: 2, child: _formField("Workload ID", _idController)),
              const SizedBox(width: 8),
              Expanded(flex: 3, child: _formField("Workload Type", _typeController)),
            ],
          ),
          const SizedBox(height: 8),
          _formField("Mission Objective Description", _descController),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _sliderInput("CPU Cores", _newCpu, 1.0, 256.0, 2.0, (v) => setState(() => _newCpu = v), "${_newCpu.toInt()} Cores")),
              const SizedBox(width: 12),
              Expanded(child: _sliderInput("GPU Units", _newGpu, 0.0, 64.0, 1.0, (v) => setState(() => _newGpu = v), "${_newGpu.toInt()} Units")),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _sliderInput("RAM Memory", _newRam, 4.0, 1024.0, 8.0, (v) => setState(() => _newRam = v), "${_newRam.toInt()} GB")),
              const SizedBox(width: 12),
              Expanded(child: _sliderInput("Storage", _newStorage, 10.0, 5000.0, 50.0, (v) => setState(() => _newStorage = v), "${_newStorage.toInt()} GB")),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _sliderInput("Runtime (Hours)", _newRuntime, 0.5, 72.0, 0.5, (v) => setState(() => _newRuntime = v), "${_newRuntime.toStringAsFixed(1)} hrs")),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Priority", style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    const SizedBox(height: 3),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ["HIGH", "MEDIUM", "LOW"].map((p) {
                          final isSel = _newPriority == p;
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: InkWell(
                              onTap: () => setState(() => _newPriority = p),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isSel ? (p == "HIGH" ? AppTheme.coralAlert : AppTheme.marineEmerald) : const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(p, style: TextStyle(fontSize: 9.0, fontWeight: FontWeight.bold, color: isSel ? Colors.white : AppTheme.textSecondary)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                final newWl = Workload(
                  id: _idController.text.trim().isEmpty ? "WL-CUSTOM-${widget.allWorkloads.length + 1}" : _idController.text.trim(),
                  type: _typeController.text.trim().isEmpty ? "Custom Compute Task" : _typeController.text.trim(),
                  cpuCores: _newCpu,
                  gpuUnits: _newGpu,
                  ramGb: _newRam,
                  storageGb: _newStorage,
                  durationHours: _newRuntime,
                  priority: _newPriority,
                  description: _descController.text.trim(),
                );
                widget.onCreateCustomWorkload(newWl);
                setState(() {
                  _showCreateForm = false;
                  _idController.text = "WL-CUSTOM-${(widget.allWorkloads.length + 2).toString().padLeft(2, '0')}";
                });
              },
              icon: const Icon(Icons.save_rounded, size: 14, color: Colors.white),
              label: const Text("Save Workload to Active Catalog", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.bioluminescentCyan,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatePodForm(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.brightTeal.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dns_rounded, color: AppTheme.brightTeal, size: 16),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Deploy New Subsea Compute Pod",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: () => setState(() => _showCreatePodForm = false),
                child: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            "Configure hardware capacity and environmental telemetry. The pod immediately becomes active for multi-objective scoring.",
            style: TextStyle(fontSize: 10.5, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(flex: 2, child: _formField("Pod ID", _podIdController)),
              const SizedBox(width: 8),
              Expanded(flex: 3, child: _formField("Pod Name", _podNameController)),
            ],
          ),
          const SizedBox(height: 8),
          _formField("Oceanographic Location", _podLocController),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _sliderInput("Total CPU Cores", _newPodCpu, 16.0, 256.0, 16.0, (v) => setState(() => _newPodCpu = v), "${_newPodCpu.toInt()} Cores")),
              const SizedBox(width: 12),
              Expanded(child: _sliderInput("Used CPU Cores", _newPodUsedCpu, 0.0, _newPodCpu, 4.0, (v) => setState(() => _newPodUsedCpu = v), "${_newPodUsedCpu.toInt()} Used")),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _sliderInput("Total GPU Units", _newPodGpu, 0.0, 64.0, 2.0, (v) => setState(() => _newPodGpu = v), "${_newPodGpu.toInt()} GPUs")),
              const SizedBox(width: 12),
              Expanded(child: _sliderInput("Used GPU Units", _newPodUsedGpu, 0.0, _newPodGpu, 1.0, (v) => setState(() => _newPodUsedGpu = v), "${_newPodUsedGpu.toInt()} Used")),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _sliderInput("RAM Memory", _newPodRam, 32.0, 1024.0, 32.0, (v) => setState(() => _newPodRam = v), "${_newPodRam.toInt()} GB")),
              const SizedBox(width: 12),
              Expanded(child: _sliderInput("Storage", _newPodStorage, 500.0, 10000.0, 500.0, (v) => setState(() => _newPodStorage = v), "${_newPodStorage.toInt()} GB")),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _sliderInput("Network Latency", _newPodLatency, 4.0, 60.0, 1.0, (v) => setState(() => _newPodLatency = v), "${_newPodLatency.toStringAsFixed(1)} ms")),
              const SizedBox(width: 12),
              Expanded(child: _sliderInput("Ambient Water Temp", _newPodTemp, -2.0, 30.0, 0.5, (v) => setState(() => _newPodTemp = v), "${_newPodTemp.toStringAsFixed(1)}°C")),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _sliderInput("Tidal Current Speed", _newPodCurrent, 0.1, 4.0, 0.1, (v) => setState(() => _newPodCurrent = v), "${_newPodCurrent.toStringAsFixed(2)} m/s")),
              const SizedBox(width: 12),
              Expanded(child: _sliderInput("Grid Carbon Intensity", _newPodCarbon, 0.01, 0.50, 0.01, (v) => setState(() => _newPodCarbon = v), "${_newPodCarbon.toStringAsFixed(3)} kg/kWh")),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                final podId = _podIdController.text.trim().isEmpty ? "POD-CUSTOM-${widget.pods.length + 1}" : _podIdController.text.trim();
                final podName = _podNameController.text.trim().isEmpty ? "AquaVent-Pod-${widget.pods.length + 1}" : _podNameController.text.trim();
                final podLoc = _podLocController.text.trim().isEmpty ? "Deep Sea Trench" : _podLocController.text.trim();

                final newPod = PodResource(
                  id: podId,
                  name: podName,
                  location: podLoc,
                  totalCpu: _newPodCpu,
                  usedCpu: _newPodUsedCpu.clamp(0.0, _newPodCpu),
                  totalGpu: _newPodGpu,
                  usedGpu: _newPodUsedGpu.clamp(0.0, _newPodGpu),
                  totalRamGb: _newPodRam,
                  usedRamGb: _newPodUsedRam.clamp(0.0, _newPodRam),
                  totalStorageGb: _newPodStorage,
                  usedStorageGb: _newPodUsedStorage.clamp(0.0, _newPodStorage),
                  status: _newPodStatus,
                  basePowerKw: _newPodBasePower,
                  maxPowerKw: _newPodMaxPower,
                  pue: _newPodPue,
                  networkLatencyMs: _newPodLatency,
                  surfaceAreaM2: 140.0,
                );

                final newOcean = OceanCondition(
                  podId: podId,
                  timestamp: DateTime.now().toUtc(),
                  waterTemperatureC: _newPodTemp,
                  currentSpeedMps: _newPodCurrent,
                  currentDirectionDeg: 180.0,
                  salinityPsu: 34.8,
                  depthM: _newPodDepth,
                  ecologicalZone: _newPodZone,
                  gridCarbonIntensityKgPerKwh: _newPodCarbon,
                  ambientTurbidityNtu: 1.0,
                );

                widget.onCreatePod?.call(newPod, newOcean);
                setState(() => _showCreatePodForm = false);
              },
              icon: const Icon(Icons.rocket_launch_rounded, size: 14, color: Colors.white),
              label: const Text("Deploy Pod to Active Global Fleet", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brightTeal,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        const SizedBox(height: 3),
        TextField(
          controller: controller,
          style: const TextStyle(fontSize: 11.5, color: Colors.white),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: const Color(0xFF0F172A),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
          ),
        ),
      ],
    );
  }

  Widget _buildFutureWorkloadQueue(bool isMobile) {
    final queue = widget.futureWorkloadQueue;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.warningAmber.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.schedule_rounded, color: AppTheme.warningAmber, size: 16),
                  const SizedBox(width: 6),
                  Text("Future Mission Queue (${queue.length})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.white)),
                ],
              ),
              if (queue.isNotEmpty)
                InkWell(
                  onTap: widget.onClearQueue,
                  child: const Text("Clear All", style: TextStyle(color: AppTheme.coralAlert, fontSize: 10.5, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text("Upcoming workloads to be scheduled sequentially in upcoming mission dispatches.", style: TextStyle(fontSize: 10.5, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),

          if (queue.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppTheme.bioluminescentCyan.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.bioluminescentCyan.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.arrow_forward_rounded, color: AppTheme.bioluminescentCyan, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Targeting head: ${queue.first.id} — ${queue.first.type}",
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () => widget.onWorkloadChanged(queue.first),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.bioluminescentCyan,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text("Select Head", style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: queue.length,
              itemBuilder: (context, idx) {
                final item = queue[idx];
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Text("${idx + 1}.", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "${item.id} — ${item.type} (${item.cpuCores.toInt()}C/${item.gpuUnits.toInt()}G, ${item.ramGb.toInt()}GB, ${item.durationHours}h)",
                          style: const TextStyle(fontSize: 10.5, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () => widget.onDequeueWorkload(item.id),
                        child: const Icon(Icons.close_rounded, size: 14, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                );
              },
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              child: const Text("Future Queue is currently empty.", style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricRibbon(PodScoreRecord best) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final cardWidth = isMobile ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 36) / 4;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: MetricCard(
                title: "Energy",
                value: "${best.energyKwh.toStringAsFixed(1)} kWh",
                icon: Icons.bolt_rounded,
                accentColor: AppTheme.bioluminescentCyan,
                subtitle: "Total consumption",
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: MetricCard(
                title: "Carbon",
                value: "${best.carbonKgCo2e.toStringAsFixed(2)} kg",
                icon: Icons.eco_rounded,
                accentColor: AppTheme.marineEmerald,
                subtitle: "CO2 equivalent",
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: MetricCard(
                title: "Thermal ΔT",
                value: "+${best.deltaTempC.toStringAsFixed(2)}°C",
                icon: Icons.thermostat_rounded,
                accentColor: AppTheme.warningAmber,
                subtitle: "Seawater rise",
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: MetricCard(
                title: "Heat Flux",
                value: "${best.convectiveHWm2k.toStringAsFixed(0)} W/m²K",
                icon: Icons.waves_rounded,
                accentColor: AppTheme.brightTeal,
                subtitle: "Convective cooling",
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildExplainableDecisionBox(SchedulingDecisionResult decision) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.brightTeal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.psychology_rounded, color: AppTheme.brightTeal, size: 18),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Explainable Decision Rationale",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            decision.explanationSummary,
            style: const TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 14),
          const Text(
            "Objective Weighted Breakdown:",
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 10),
          ScoreBreakdownChart(rankedPods: decision.rankedPods.take(3).toList()),
        ],
      ),
    );
  }

  Widget _buildRankedPodsSection(BuildContext context, SchedulingDecisionResult decision, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                "Eligible Pod Alternatives (${decision.rankedPods.length})",
                style: TextStyle(fontSize: isMobile ? 13 : 16, fontWeight: FontWeight.bold, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "Ranked by Score",
              style: TextStyle(fontSize: 10, color: AppTheme.textMuted.withOpacity(0.8)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: decision.rankedPods.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, idx) {
            final pod = decision.rankedPods[idx];
            final isFirst = idx == 0;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isFirst ? const Color(0xFF131B2E) : const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isFirst ? AppTheme.bioluminescentCyan.withOpacity(0.4) : Colors.white.withOpacity(0.06),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isFirst ? AppTheme.bioluminescentCyan : const Color(0xFF1E293B),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      "${idx + 1}",
                      style: TextStyle(color: isFirst ? Colors.white : AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 10.5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pod.podName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.white)),
                        Text("${pod.location} • Score: ${pod.compositeScore.toStringAsFixed(3)}", style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "${pod.carbonKgCo2e.toStringAsFixed(1)} kg CO2e",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppTheme.marineEmerald),
                      ),
                      Text(
                        "ΔT: +${pod.deltaTempC.toStringAsFixed(2)}°C",
                        style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => widget.onDispatchWorkload(pod),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFirst ? AppTheme.bioluminescentCyan : const Color(0xFF1E293B),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      elevation: 0,
                    ),
                    child: Text(
                      isFirst ? "Select" : "Switch",
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: isFirst ? Colors.white : AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildInfeasibleBanner(SchedulingDecisionResult decision) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.coralAlert.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.coralAlert.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.coralAlert, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Scheduling Infeasible: No Suitable Pod Available",
                  style: TextStyle(color: AppTheme.coralAlert, fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            decision.explanationSummary,
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectionsAudit(SchedulingDecisionResult decision) {
    final ineligList = decision.ineligiblePods.entries.toList();
    return GlassContainer(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.block_rounded, color: AppTheme.coralAlert, size: 15),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Ineligible Pods & Rejection Reasons Audit",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: ineligList.length,
            separatorBuilder: (_, _) => const Divider(color: AppTheme.subseaBorder, height: 12),
            itemBuilder: (context, idx) {
              final entry = ineligList[idx];
              final podId = entry.key;
              final reasons = entry.value;
              final pod = widget.pods.firstWhere((p) => p.id == podId, orElse: () => widget.pods.first);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.coralAlert.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      podId,
                      style: const TextStyle(color: AppTheme.coralAlert, fontSize: 9.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pod.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.white)),
                        Text(reasons.join(" • "), style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
