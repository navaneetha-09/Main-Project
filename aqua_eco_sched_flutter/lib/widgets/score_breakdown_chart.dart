import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/scheduling_result.dart';

class ScoreBreakdownChart extends StatelessWidget {
  final List<PodScoreRecord> rankedPods;

  const ScoreBreakdownChart({
    super.key,
    required this.rankedPods,
  });

  @override
  Widget build(BuildContext context) {
    if (rankedPods.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _legendItem("⚡ Energy", AppTheme.warningAmber),
            _legendItem("🌱 Carbon", AppTheme.marineEmerald),
            _legendItem("🌡️ Thermal", AppTheme.coralAlert),
            _legendItem("🛡️ Eco-Risk", AppTheme.bioluminescentCyan),
            _legendItem("🚀 Performance", AppTheme.deepPurple),
          ],
        ),
        const SizedBox(height: 16),
        ...rankedPods.map((pod) => _buildPodBreakdownRow(pod)),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildPodBreakdownRow(PodScoreRecord pod) {
    final total = (pod.energyContrib + pod.carbonContrib + pod.thermalContrib + pod.riskContrib + pod.perfContrib);
    final safeTotal = total > 0 ? total : 1.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Rank ${pod.rank} • ${pod.podName}",
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "Score: ${pod.compositeScore.toStringAsFixed(4)}",
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.brightTeal),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  _barSegment(pod.energyContrib / safeTotal, AppTheme.warningAmber),
                  _barSegment(pod.carbonContrib / safeTotal, AppTheme.marineEmerald),
                  _barSegment(pod.thermalContrib / safeTotal, AppTheme.coralAlert),
                  _barSegment(pod.riskContrib / safeTotal, AppTheme.bioluminescentCyan),
                  _barSegment(pod.perfContrib / safeTotal, AppTheme.deepPurple),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barSegment(double fraction, Color color) {
    if (fraction <= 0) return const SizedBox.shrink();
    return Expanded(
      flex: (fraction * 1000).toInt().clamp(1, 1000),
      child: Container(color: color),
    );
  }
}
