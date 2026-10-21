import 'package:flutter/material.dart';
import '../../services/scheduler_engine.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_container.dart';

class SensitivityTab extends StatelessWidget {
  final SchedulingWeights weights;
  final Function(SchedulingWeights) onWeightsChanged;
  final VoidCallback? onNavigateToScheduler;

  const SensitivityTab({
    super.key,
    required this.weights,
    required this.onWeightsChanged,
    this.onNavigateToScheduler,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final norm = weights.toNormalizedMap();

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 14 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "🔬 Objective Weight Sensitivity & Trade-Offs",
            style: TextStyle(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            "Test alternatives and analyze how changing objective priorities affects pod selection and environmental trade-offs.",
            style: TextStyle(fontSize: isMobile ? 11.5 : 13, color: AppTheme.textSecondary.withOpacity(0.9)),
          ),
          const SizedBox(height: 18),

          // Presets row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPresetButton(
                "🌱 Ultra-Green (Carbon Focused)",
                const SchedulingWeights(energy: 0.10, carbon: 0.60, thermalFootprint: 0.15, environmentalRisk: 0.10, performancePenalty: 0.05),
              ),
              _buildPresetButton(
                "🪸 Marine Ecology First",
                const SchedulingWeights(energy: 0.05, carbon: 0.10, thermalFootprint: 0.40, environmentalRisk: 0.40, performancePenalty: 0.05),
              ),
              _buildPresetButton(
                "⚡ Low Latency / Perf",
                const SchedulingWeights(energy: 0.15, carbon: 0.10, thermalFootprint: 0.15, environmentalRisk: 0.10, performancePenalty: 0.50),
              ),
              _buildPresetButton(
                "⚖️ Balanced AquaEco",
                const SchedulingWeights(energy: 0.20, carbon: 0.20, thermalFootprint: 0.20, environmentalRisk: 0.20, performancePenalty: 0.20),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Sliders in GlassContainer
          GlassContainer(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Tune Objective Priority Weights (Normalized to sum = 1.0)",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                ),
                const SizedBox(height: 16),
                _buildWeightSlider(
                  "⚡ Facility Energy Consumption",
                  weights.energy,
                  norm["energy"]!,
                  AppTheme.warningAmber,
                  (v) => onWeightsChanged(SchedulingWeights(
                    energy: v,
                    carbon: weights.carbon,
                    thermalFootprint: weights.thermalFootprint,
                    environmentalRisk: weights.environmentalRisk,
                    performancePenalty: weights.performancePenalty,
                  )),
                ),
                _buildWeightSlider(
                  "🌱 Carbon Emissions Intensity",
                  weights.carbon,
                  norm["carbon"]!,
                  AppTheme.marineEmerald,
                  (v) => onWeightsChanged(SchedulingWeights(
                    energy: weights.energy,
                    carbon: v,
                    thermalFootprint: weights.thermalFootprint,
                    environmentalRisk: weights.environmentalRisk,
                    performancePenalty: weights.performancePenalty,
                  )),
                ),
                _buildWeightSlider(
                  "🌡️ Hydrodynamic Thermal Plume",
                  weights.thermalFootprint,
                  norm["thermal_footprint"]!,
                  AppTheme.coralAlert,
                  (v) => onWeightsChanged(SchedulingWeights(
                    energy: weights.energy,
                    carbon: weights.carbon,
                    thermalFootprint: v,
                    environmentalRisk: weights.environmentalRisk,
                    performancePenalty: weights.performancePenalty,
                  )),
                ),
                _buildWeightSlider(
                  "🛡️ Marine Environmental Risk Index",
                  weights.environmentalRisk,
                  norm["environmental_risk"]!,
                  AppTheme.bioluminescentCyan,
                  (v) => onWeightsChanged(SchedulingWeights(
                    energy: weights.energy,
                    carbon: weights.carbon,
                    thermalFootprint: weights.thermalFootprint,
                    environmentalRisk: v,
                    performancePenalty: weights.performancePenalty,
                  )),
                ),
                _buildWeightSlider(
                  "🚀 Performance & Network Latency",
                  weights.performancePenalty,
                  norm["performance_penalty"]!,
                  AppTheme.deepPurple,
                  (v) => onWeightsChanged(SchedulingWeights(
                    energy: weights.energy,
                    carbon: weights.carbon,
                    thermalFootprint: weights.thermalFootprint,
                    environmentalRisk: weights.environmentalRisk,
                    performancePenalty: v,
                  )),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Apply and launch button
          if (onNavigateToScheduler != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onNavigateToScheduler,
                icon: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 18),
                label: const Text(
                  "Apply Weights & View in Scheduler",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.bioluminescentCyan,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPresetButton(String title, SchedulingWeights preset) {
    return ElevatedButton(
      onPressed: () => onWeightsChanged(preset),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.oceanCardLight,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppTheme.subseaBorder),
        ),
      ),
      child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildWeightSlider(
    String label,
    double rawVal,
    double normVal,
    Color color,
    Function(double) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "w: ${rawVal.toStringAsFixed(2)} (${(normVal * 100).toStringAsFixed(0)}%)",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          Slider(
            value: rawVal,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            activeColor: color,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
