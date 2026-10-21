import 'package:flutter/material.dart';
import '../../models/pod_resource.dart';
import '../../models/ocean_condition.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/cooling_profile_chart.dart';

class PodsTelemetryTab extends StatefulWidget {
  final List<PodResource> pods;
  final List<OceanCondition> oceanConditions;
  final double maxDeltaTempLimit;
  final double envTempShift;
  final double envCurrentMult;
  final double envCarbonMult;
  final bool isLiveTelemetry;
  final Function(double, double, double) onUpdateModifiers;
  final VoidCallback onSyncLiveTelemetry;
  final Function(PodResource, OceanCondition)? onCreatePod;

  const PodsTelemetryTab({
    super.key,
    required this.pods,
    required this.oceanConditions,
    required this.maxDeltaTempLimit,
    this.envTempShift = 0.0,
    this.envCurrentMult = 1.0,
    this.envCarbonMult = 1.0,
    this.isLiveTelemetry = false,
    required this.onUpdateModifiers,
    required this.onSyncLiveTelemetry,
    this.onCreatePod,
  });

  @override
  State<PodsTelemetryTab> createState() => _PodsTelemetryTabState();
}

class _PodsTelemetryTabState extends State<PodsTelemetryTab> {
  bool _isSimulatorExpanded = false;
  bool _showCreatePod = false;

  final TextEditingController _podIdController = TextEditingController();
  final TextEditingController _podNameController = TextEditingController(text: "AquaVent-Pod-Beta");
  final TextEditingController _podLocController = TextEditingController(text: "Kermadec Trench (Pacific Ocean)");
  double _newCpu = 128.0;
  double _newUsedCpu = 16.0;
  double _newGpu = 16.0;
  double _newUsedGpu = 2.0;
  double _newRam = 512.0;
  final double _newUsedRam = 64.0;
  double _newStorage = 4000.0;
  final double _newUsedStorage = 600.0;
  double _newLatency = 14.5;
  double _newTemp = 4.5;
  double _newCurrent = 1.1;
  double _newCarbon = 0.045;

  @override
  void initState() {
    super.initState();
    _podIdController.text = "POD-CUSTOM-${(widget.pods.length + 1).toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _podIdController.dispose();
    _podNameController.dispose();
    _podLocController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final oceanMap = {for (var o in widget.oceanConditions) o.podId: o};

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "🌊 Subsea Fleet Hardware & Ocean Telemetry",
            style: TextStyle(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            "Real-time monitoring of underwater pod compute capacity, convective heat dissipation, and oceanographic context.",
            style: TextStyle(fontSize: isMobile ? 11.5 : 13, color: AppTheme.textSecondary.withOpacity(0.9)),
          ),
          const SizedBox(height: 14),

          // Real-Time Oceanic Telemetry Engine Panel
          _buildRealtimeEngineCard(context, isMobile),
          const SizedBox(height: 12),

          // Dynamic Ocean Conditions Simulator (Custom clean expander, no ListTile)
          _buildSimulatorExpander(context, isMobile),
          const SizedBox(height: 14),

          // Convective Seawater Cooling Profile Chart
          GlassContainer(
            padding: EdgeInsets.all(isMobile ? 14 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "🌡️ Seawater Boundary Layer Thermal Elevation (ΔT)",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _legendDot(const Color(0xFF0077B6), "Ambient Ocean Temp"),
                    _legendDot(AppTheme.coralAlert, "Water Rise ΔT"),
                    _legendDot(AppTheme.warningAmber, "Max Budget Limit (${widget.maxDeltaTempLimit.toStringAsFixed(1)}°C)"),
                  ],
                ),
                const SizedBox(height: 16),
                CoolingProfileChart(
                  pods: widget.pods,
                  oceanConditions: widget.oceanConditions,
                  maxDeltaTempLimit: widget.maxDeltaTempLimit,
                ),
              ],
            ),
          ),
          // Pod Fleet Grid (Exact text must match widget tests!)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                "🖥️ Subsea Datacenter Fleet Status",
                style: TextStyle(fontSize: isMobile ? 15 : 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              ElevatedButton.icon(
                onPressed: () => setState(() => _showCreatePod = !_showCreatePod),
                icon: Icon(_showCreatePod ? Icons.close_rounded : Icons.add_circle_outline_rounded, size: 14, color: Colors.white),
                label: Text(_showCreatePod ? "Close Form" : "➕ Deploy New Pod", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _showCreatePod ? Colors.white.withOpacity(0.12) : AppTheme.marineEmerald,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
          if (_showCreatePod) ...[
            const SizedBox(height: 12),
            _buildCreatePodPanel(isMobile),
          ],
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 1100 ? 3 : (constraints.maxWidth > 650 ? 2 : 1);
              final aspectRatio = isMobile ? 1.38 : 1.45;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: aspectRatio,
                ),
                itemCount: widget.pods.length,
                itemBuilder: (context, idx) {
                  final pod = widget.pods[idx];
                  final ocean = oceanMap[pod.id];
                  return _buildPodCard(pod, ocean);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRealtimeEngineCard(BuildContext context, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.bioluminescentCyan.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.bioluminescentCyan.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.sensors_rounded, color: AppTheme.bioluminescentCyan, size: 18),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "📡 Live Ocean Buoy Telemetry Feed",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "Real-time water temperature, current speeds & clean grid carbon",
                      style: TextStyle(fontSize: 10.5, color: AppTheme.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: (widget.isLiveTelemetry ? AppTheme.marineEmerald : AppTheme.brightTeal).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: (widget.isLiveTelemetry ? AppTheme.marineEmerald : AppTheme.brightTeal).withOpacity(0.5)),
                ),
                child: Text(
                  widget.isLiveTelemetry ? "● STREAMING" : "● FEED READY",
                  style: TextStyle(
                    color: widget.isLiveTelemetry ? AppTheme.marineEmerald : AppTheme.brightTeal,
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isMobile) ...[
            const Text(
              "Synchronize live oceanographic telemetry from sensor buoys across 30 global subsea locations.",
              style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onSyncLiveTelemetry,
                icon: const Icon(Icons.bolt_rounded, size: 15, color: Colors.white),
                label: const Text("⚡ Ingest Live Real-Time Feed", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.bioluminescentCyan,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Synchronize live oceanographic telemetry from sensor buoys across 30 global subsea locations.",
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: widget.onSyncLiveTelemetry,
                  icon: const Icon(Icons.bolt_rounded, size: 16, color: Colors.white),
                  label: const Text("⚡ Ingest Live Real-Time Feed", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.bioluminescentCyan,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSimulatorExpander(BuildContext context, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _isSimulatorExpanded = !_isSimulatorExpanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded, color: AppTheme.warningAmber, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "🌊 Dynamic Ocean Conditions Simulator",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          "Adjust ocean currents, marine heatwaves, or power grid stress",
                          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isSimulatorExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.textSecondary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (_isSimulatorExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                children: [
                  const Divider(color: AppTheme.subseaBorder, height: 12),
                  if (isMobile) ...[
                    _sliderRow("🌡️ Seawater Temp Shift", "${widget.envTempShift >= 0 ? '+' : ''}${widget.envTempShift.toStringAsFixed(1)}°C", widget.envTempShift, -3.0, 5.0, 16, AppTheme.warningAmber, (v) => widget.onUpdateModifiers(v, widget.envCurrentMult, widget.envCarbonMult)),
                    const SizedBox(height: 6),
                    _sliderRow("🌊 Tidal Current Velocity", "${widget.envCurrentMult.toStringAsFixed(1)}x", widget.envCurrentMult, 0.2, 2.5, 23, AppTheme.bioluminescentCyan, (v) => widget.onUpdateModifiers(widget.envTempShift, v, widget.envCarbonMult)),
                    const SizedBox(height: 6),
                    _sliderRow("⚡ Grid Carbon Multiplier", "${widget.envCarbonMult.toStringAsFixed(1)}x", widget.envCarbonMult, 0.5, 2.0, 15, AppTheme.marineEmerald, (v) => widget.onUpdateModifiers(widget.envTempShift, widget.envCurrentMult, v)),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(child: _sliderRow("🌡️ Seawater Temp Shift", "${widget.envTempShift >= 0 ? '+' : ''}${widget.envTempShift.toStringAsFixed(1)}°C", widget.envTempShift, -3.0, 5.0, 16, AppTheme.warningAmber, (v) => widget.onUpdateModifiers(v, widget.envCurrentMult, widget.envCarbonMult))),
                        const SizedBox(width: 12),
                        Expanded(child: _sliderRow("🌊 Tidal Current Velocity", "${widget.envCurrentMult.toStringAsFixed(1)}x", widget.envCurrentMult, 0.2, 2.5, 23, AppTheme.bioluminescentCyan, (v) => widget.onUpdateModifiers(widget.envTempShift, v, widget.envCarbonMult))),
                        const SizedBox(width: 12),
                        Expanded(child: _sliderRow("⚡ Grid Carbon Multiplier", "${widget.envCarbonMult.toStringAsFixed(1)}x", widget.envCarbonMult, 0.5, 2.0, 15, AppTheme.marineEmerald, (v) => widget.onUpdateModifiers(widget.envTempShift, widget.envCurrentMult, v))),
                      ],
                    ),
                  ],
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => widget.onUpdateModifiers(0.0, 1.0, 1.0),
                      icon: const Icon(Icons.restart_alt_rounded, size: 13, color: AppTheme.textSecondary),
                      label: const Text("Reset Modifiers", style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _sliderRow(String label, String displayVal, double val, double min, double max, int divisions, Color color, Function(double) onChanged) {
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
            activeTrackColor: color,
            inactiveTrackColor: const Color(0xFF1E293B),
            thumbColor: Colors.white,
          ),
          child: Slider(
            value: val.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildPodCard(PodResource pod, OceanCondition? ocean) {
    final isOperational = pod.isOperational;
    final statusColor = isOperational ? AppTheme.marineEmerald : AppTheme.coralAlert;

    return GlassContainer(
      padding: const EdgeInsets.all(14),
      borderColor: isOperational ? AppTheme.subseaBorder : AppTheme.coralAlert.withOpacity(0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  pod.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Text(
                  pod.status,
                  style: TextStyle(color: statusColor, fontSize: 9.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          Text("${pod.id} • ${pod.location}", style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted.withOpacity(0.8)), overflow: TextOverflow.ellipsis),
          const Spacer(),

          // Resource gauges
          _buildGaugeRow("CPU", pod.usedCpu.toInt(), pod.totalCpu.toInt(), "cores", pod.cpuUtilization),
          const SizedBox(height: 5),
          _buildGaugeRow("GPU", pod.usedGpu.toInt(), pod.totalGpu.toInt(), "units", pod.gpuUtilization),
          const SizedBox(height: 5),
          _buildGaugeRow("RAM", pod.usedRamGb.toInt(), pod.totalRamGb.toInt(), "GB", pod.ramUtilization),
          const Spacer(),

          const Divider(color: AppTheme.subseaBorder, height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Text("🌊 ${ocean?.waterTemperatureC.toStringAsFixed(1) ?? '10.0'}°C", style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
              Text("⚡ ${ocean?.currentSpeedMps.toStringAsFixed(2) ?? '0.50'} m/s", style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
              Text("🌱 ${ocean?.gridCarbonIntensityKgPerKwh.toStringAsFixed(3) ?? '0.20'} kg/kWh", style: const TextStyle(fontSize: 10, color: AppTheme.marineEmerald)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGaugeRow(String label, int used, int total, String unit, double fraction) {
    return Row(
      children: [
        SizedBox(width: 30, child: Text(label, style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary, fontWeight: FontWeight.bold))),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              backgroundColor: const Color(0xFF1B2F4C),
              valueColor: AlwaysStoppedAnimation<Color>(
                fraction > 0.85 ? AppTheme.coralAlert : (fraction > 0.65 ? AppTheme.warningAmber : AppTheme.bioluminescentCyan),
              ),
              minHeight: 5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          "$used/$total $unit",
          style: const TextStyle(fontSize: 9.5, color: Colors.white70, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildCreatePodPanel(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.marineEmerald.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.add_box_rounded, color: AppTheme.marineEmerald, size: 16),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Deploy & Register New Subsea Pod",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: () => setState(() => _showCreatePod = false),
                child: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            "Hardware capacity, thermal boundaries, and real-time sensor metrics for the newly commissioned pod.",
            style: TextStyle(fontSize: 10.5, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(flex: 2, child: _panelTextField("Pod ID", _podIdController)),
              const SizedBox(width: 8),
              Expanded(flex: 3, child: _panelTextField("Pod Name", _podNameController)),
            ],
          ),
          const SizedBox(height: 8),
          _panelTextField("Oceanographic Location", _podLocController),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _sliderRow("Total CPU", "${_newCpu.toInt()} Cores", _newCpu, 16.0, 256.0, 15, AppTheme.brightTeal, (v) => setState(() => _newCpu = v))),
              const SizedBox(width: 12),
              Expanded(child: _sliderRow("Used CPU", "${_newUsedCpu.toInt()} Used", _newUsedCpu, 0.0, _newCpu, 15, AppTheme.warningAmber, (v) => setState(() => _newUsedCpu = v))),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _sliderRow("Total GPU", "${_newGpu.toInt()} GPUs", _newGpu, 0.0, 64.0, 16, AppTheme.brightTeal, (v) => setState(() => _newGpu = v))),
              const SizedBox(width: 12),
              Expanded(child: _sliderRow("Used GPU", "${_newUsedGpu.toInt()} Used", _newUsedGpu, 0.0, _newGpu, 16, AppTheme.warningAmber, (v) => setState(() => _newUsedGpu = v))),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _sliderRow("Total RAM", "${_newRam.toInt()} GB", _newRam, 32.0, 1024.0, 31, AppTheme.bioluminescentCyan, (v) => setState(() => _newRam = v))),
              const SizedBox(width: 12),
              Expanded(child: _sliderRow("Total Storage", "${_newStorage.toInt()} GB", _newStorage, 500.0, 10000.0, 19, AppTheme.marineEmerald, (v) => setState(() => _newStorage = v))),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _sliderRow("Water Temp", "${_newTemp.toStringAsFixed(1)}°C", _newTemp, -2.0, 30.0, 32, AppTheme.warningAmber, (v) => setState(() => _newTemp = v))),
              const SizedBox(width: 12),
              Expanded(child: _sliderRow("Current Speed", "${_newCurrent.toStringAsFixed(2)} m/s", _newCurrent, 0.1, 4.0, 39, AppTheme.bioluminescentCyan, (v) => setState(() => _newCurrent = v))),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _sliderRow("Network Latency", "${_newLatency.toStringAsFixed(1)} ms", _newLatency, 4.0, 60.0, 28, AppTheme.textSecondary, (v) => setState(() => _newLatency = v))),
              const SizedBox(width: 12),
              Expanded(child: _sliderRow("Grid Carbon", "${_newCarbon.toStringAsFixed(3)} kg/kWh", _newCarbon, 0.01, 0.50, 49, AppTheme.marineEmerald, (v) => setState(() => _newCarbon = v))),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                final pid = _podIdController.text.trim().isEmpty ? "POD-CUSTOM-${widget.pods.length + 1}" : _podIdController.text.trim();
                final pname = _podNameController.text.trim().isEmpty ? "AquaVent-Pod-${widget.pods.length + 1}" : _podNameController.text.trim();
                final ploc = _podLocController.text.trim().isEmpty ? "Deep Sea Trench" : _podLocController.text.trim();

                final newPod = PodResource(
                  id: pid,
                  name: pname,
                  location: ploc,
                  totalCpu: _newCpu,
                  usedCpu: _newUsedCpu.clamp(0.0, _newCpu),
                  totalGpu: _newGpu,
                  usedGpu: _newUsedGpu.clamp(0.0, _newGpu),
                  totalRamGb: _newRam,
                  usedRamGb: _newUsedRam.clamp(0.0, _newRam),
                  totalStorageGb: _newStorage,
                  usedStorageGb: _newUsedStorage.clamp(0.0, _newStorage),
                  status: "ACTIVE",
                  basePowerKw: 22.0,
                  maxPowerKw: 115.0,
                  pue: 1.05,
                  networkLatencyMs: _newLatency,
                  surfaceAreaM2: 140.0,
                );

                final newOcean = OceanCondition(
                  podId: pid,
                  timestamp: DateTime.now().toUtc(),
                  waterTemperatureC: _newTemp,
                  currentSpeedMps: _newCurrent,
                  currentDirectionDeg: 180.0,
                  salinityPsu: 34.8,
                  depthM: 150.0,
                  ecologicalZone: "LOW_IMPACT",
                  gridCarbonIntensityKgPerKwh: _newCarbon,
                  ambientTurbidityNtu: 1.0,
                );

                widget.onCreatePod?.call(newPod, newOcean);
                setState(() => _showCreatePod = false);
              },
              icon: const Icon(Icons.rocket_launch_rounded, size: 14, color: Colors.white),
              label: const Text("Deploy Pod to Active Global Fleet", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.marineEmerald,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelTextField(String label, TextEditingController controller) {
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
            focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(6)), borderSide: BorderSide(color: AppTheme.marineEmerald)),
          ),
        ),
      ],
    );
  }
}
