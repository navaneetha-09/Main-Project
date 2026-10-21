import 'package:flutter/material.dart';
import '../../models/workload.dart';
import '../../models/pod_resource.dart';
import '../../models/ocean_condition.dart';
import '../../models/scheduling_result.dart';
import '../../services/scheduler_engine.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_container.dart';

class BaselineTab extends StatelessWidget {
  final Workload currentWorkload;
  final List<PodResource> pods;
  final List<OceanCondition> oceanConditions;
  final SchedulingWeights weights;
  final RiskBudgetConstraints constraints;

  const BaselineTab({
    super.key,
    required this.currentWorkload,
    required this.pods,
    required this.oceanConditions,
    required this.weights,
    required this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    final comparison = SchedulerEngine.evaluateBaselines(
      workload: currentWorkload,
      pods: pods,
      oceanConditions: oceanConditions,
      weights: weights,
      constraints: constraints,
    );

    final aqua = comparison["AquaEcoSched"]!;
    final ff = comparison["FirstFit"]!;
    final ro = comparison["ResourceOnly"]!;

    double carbonSavingsPct = 0;
    if (ro.carbonKgCo2e > 0 && aqua.carbonKgCo2e > 0) {
      carbonSavingsPct = ((ro.carbonKgCo2e - aqua.carbonKgCo2e) / ro.carbonKgCo2e * 100).clamp(0, 99.9);
    }

    final isMobile = MediaQuery.of(context).size.width < 768;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 14 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "⚖️ Policy Baseline Comparison",
            style: TextStyle(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            "Comparing AquaEcoSched eco-aware optimization against First-Fit and Resource-Only heuristics for workload ${currentWorkload.id} (${currentWorkload.type}).",
            style: TextStyle(fontSize: isMobile ? 11.5 : 13, color: AppTheme.textSecondary.withOpacity(0.9)),
          ),
          const SizedBox(height: 16),

          // Carbon savings callout banner
          Container(
            padding: EdgeInsets.all(isMobile ? 14 : 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF044736), Color(0xFF02684F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.marineEmerald.withOpacity(0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.eco_rounded, color: AppTheme.marineEmerald, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "🌱 AquaEcoSched Carbon Reduction: -${carbonSavingsPct.toStringAsFixed(1)}%",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isMobile ? 13.5 : 15),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        "Achieves up to ${carbonSavingsPct.toStringAsFixed(0)}% lower emissions compared to Resource-Only packing, while eliminating all marine sanctuary and thermal budget violations.",
                        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: isMobile ? 11 : 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3 Policy Cards
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SizedBox(width: isMobile ? 280 : 300, child: _buildPolicyCard(aqua, isRecommended: true)),
                const SizedBox(width: 12),
                SizedBox(width: isMobile ? 280 : 300, child: _buildPolicyCard(ff)),
                const SizedBox(width: 12),
                SizedBox(width: isMobile ? 280 : 300, child: _buildPolicyCard(ro)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Comparison Table Header
          Row(
            children: [
              Expanded(
                child: Text(
                  "📈 Quantitative Benchmark Summary",
                  style: TextStyle(fontSize: isMobile ? 15 : 18, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isMobile) ...[
                const SizedBox(width: 8),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swipe_outlined, size: 14, color: AppTheme.brightTeal),
                    SizedBox(width: 4),
                    Text("Swipe", style: TextStyle(fontSize: 10, color: AppTheme.brightTeal)),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          GlassContainer(
            padding: EdgeInsets.all(isMobile ? 12 : 18),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: isMobile ? 620 : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTableRow("POLICY", "ALLOCATED POD", "CARBON (KG)", "SEAWATER ΔT", "ECO-RISK", "VIOLATIONS", isHeader: true),
                    const Divider(color: AppTheme.subseaBorder),
                    _buildMetricRow(aqua),
                    const Divider(color: AppTheme.subseaBorder, height: 12),
                    _buildMetricRow(ff),
                    const Divider(color: AppTheme.subseaBorder, height: 12),
                    _buildMetricRow(ro),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyCard(BaselinePolicyMetric m, {bool isRecommended = false}) {
    final borderColor = isRecommended ? AppTheme.bioluminescentCyan : AppTheme.subseaBorder;
    final violationsTag = m.constraintViolations == 0
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppTheme.marineEmerald.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
            child: const Text("0 VIOLATIONS", style: TextStyle(color: AppTheme.marineEmerald, fontSize: 10, fontWeight: FontWeight.bold)),
          )
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppTheme.coralAlert.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
            child: Text("${m.constraintViolations} VIOLATION", style: const TextStyle(color: AppTheme.coralAlert, fontSize: 10, fontWeight: FontWeight.bold)),
          );

    return GlassContainer(
      borderColor: borderColor,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  m.policyName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isRecommended ? AppTheme.brightTeal : Colors.white,
                  ),
                ),
              ),
              violationsTag,
            ],
          ),
          const SizedBox(height: 10),
          Text(
            m.selectedPodName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          Text(
            m.selectedPodId ?? "None",
            style: TextStyle(fontSize: 11, color: AppTheme.textMuted.withOpacity(0.8)),
          ),
          const SizedBox(height: 14),
          const Divider(color: AppTheme.subseaBorder),
          const SizedBox(height: 8),

          _buildStatLine("🌱 Carbon Emitted:", "${m.carbonKgCo2e.toStringAsFixed(2)} kg CO2e", AppTheme.marineEmerald),
          const SizedBox(height: 6),
          _buildStatLine("⚡ Facility Energy:", "${m.energyKwh.toStringAsFixed(2)} kWh", AppTheme.warningAmber),
          const SizedBox(height: 6),
          _buildStatLine("🌡️ Water Rise ΔT:", "+${m.waterTempDeltaC.toStringAsFixed(2)}°C", AppTheme.coralAlert),
          const SizedBox(height: 6),
          _buildStatLine("🛡️ Eco-Risk Index:", m.environmentalRiskScore.toStringAsFixed(3), AppTheme.brightTeal),

          if (m.violationDetails.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.coralAlert.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "⚠️ ${m.violationDetails.first}",
                style: const TextStyle(color: AppTheme.coralAlert, fontSize: 10.5, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatLine(String label, String value, Color valueColor) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        Text(value, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }

  Widget _buildTableRow(String p, String pod, String carb, String dt, String risk, String viol, {bool isHeader = false}) {
    final style = TextStyle(
      fontSize: isHeader ? 11 : 12,
      fontWeight: isHeader ? FontWeight.bold : FontWeight.w500,
      color: isHeader ? AppTheme.textSecondary : Colors.white,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(p, style: style)),
          Expanded(flex: 2, child: Text(pod, style: style)),
          Expanded(child: Text(carb, style: style)),
          Expanded(child: Text(dt, style: style)),
          Expanded(child: Text(risk, style: style)),
          Expanded(child: Text(viol, style: style)),
        ],
      ),
    );
  }

  Widget _buildMetricRow(BaselinePolicyMetric m) {
    return _buildTableRow(
      m.policyName,
      m.selectedPodName,
      "${m.carbonKgCo2e.toStringAsFixed(2)} kg",
      "+${m.waterTempDeltaC.toStringAsFixed(2)}°C",
      m.environmentalRiskScore.toStringAsFixed(3),
      m.constraintViolations == 0 ? "0 (Safe)" : "${m.constraintViolations} (Breach)",
    );
  }
}
