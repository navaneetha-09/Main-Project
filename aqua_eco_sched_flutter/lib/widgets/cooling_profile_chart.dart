import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/pod_resource.dart';
import '../models/ocean_condition.dart';

enum ChartFilter { all, top10, violations }

class CoolingProfileChart extends StatefulWidget {
  final List<PodResource> pods;
  final List<OceanCondition> oceanConditions;
  final double maxDeltaTempLimit;

  const CoolingProfileChart({
    super.key,
    required this.pods,
    required this.oceanConditions,
    required this.maxDeltaTempLimit,
  });
  

  @override
  State<CoolingProfileChart> createState() => _CoolingProfileChartState();
}

class _CoolingProfileChartState extends State<CoolingProfileChart> {
  ChartFilter _filter = ChartFilter.all;
  int? _selectedPodIndex;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  double _calculateDeltaT(PodResource pod, OceanCondition? ocean) {
    final currentSpeed = math.max(ocean?.currentSpeedMps ?? 0.5, 0.05);
    final convectiveH = 350.0 + 850.0 * math.pow(currentSpeed, 0.8);
    final dynamicSpan = math.max(pod.maxPowerKw - pod.basePowerKw, 5.0);
    final cpuFrac = (pod.usedCpu / math.max(pod.totalCpu, 1.0)).clamp(0.0, 1.0);
    final gpuFrac = (pod.usedGpu / math.max(pod.totalGpu, 1.0)).clamp(0.0, 1.0);
    final dynamicUtil = (0.50 * cpuFrac) + (0.50 * gpuFrac);
    final totalPowerKw = (pod.basePowerKw + (dynamicSpan * dynamicUtil)) * pod.pue;
    return ((totalPowerKw * 1000.0) / (convectiveH * pod.surfaceAreaM2)).clamp(0.2, 3.8);
  }

  String _getPodShortLabel(PodResource pod) {
    final idParts = pod.id.split("-");
    if (idParts.length >= 2 && idParts[1].isNotEmpty) {
      final site = idParts[1].toLowerCase();
      return site[0].toUpperCase() + site.substring(1);
    }
    return pod.name.split("-").first;
  }

  String _getPodCode(PodResource pod, int fallbackIndex) {
    final idParts = pod.id.split("-");
    if (idParts.length >= 3) {
      return "P-${idParts[2]}";
    }
    return "P-${(fallbackIndex + 1).toString().padLeft(2, '0')}";
  }

  List<PodResource> _getFilteredPods(Map<String, OceanCondition> oceanMap) {
    if (widget.pods.isEmpty) return [];

    switch (_filter) {
      case ChartFilter.top10:
        final sorted = List<PodResource>.from(widget.pods);
        sorted.sort((a, b) {
          final dtA = _calculateDeltaT(a, oceanMap[a.id]);
          final dtB = _calculateDeltaT(b, oceanMap[b.id]);
          return dtB.compareTo(dtA);
        });
        return sorted.take(10).toList();

      case ChartFilter.violations:
        final violations = widget.pods.where((p) {
          final dt = _calculateDeltaT(p, oceanMap[p.id]);
          return dt > widget.maxDeltaTempLimit;
        }).toList();
        if (violations.isEmpty) {
          // If no violations exist, show top 5 nearest to budget limit
          final sorted = List<PodResource>.from(widget.pods);
          sorted.sort((a, b) {
            final dtA = _calculateDeltaT(a, oceanMap[a.id]);
            final dtB = _calculateDeltaT(b, oceanMap[b.id]);
            return dtB.compareTo(dtA);
          });
          return sorted.take(5).toList();
        }
        return violations;

      case ChartFilter.all:
        return widget.pods;
    }
  }

  @override
  Widget build(BuildContext context) {
    final oceanMap = {for (var o in widget.oceanConditions) o.podId: o};
    final displayPods = _getFilteredPods(oceanMap);

    // Reset selection if out of bounds
    if (_selectedPodIndex != null && _selectedPodIndex! >= displayPods.length) {
      _selectedPodIndex = null;
    }

    final selectedPod = _selectedPodIndex != null ? displayPods[_selectedPodIndex!] : null;
    final selectedOcean = selectedPod != null ? oceanMap[selectedPod.id] : null;
    final selectedAmbient = selectedOcean?.waterTemperatureC ?? 10.0;
    final selectedDeltaT = selectedPod != null ? _calculateDeltaT(selectedPod, selectedOcean) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter toolbar & scroll hint
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildFilterButton("All (${widget.pods.length})", ChartFilter.all),
            _buildFilterButton("Top 10 ΔT", ChartFilter.top10),
            _buildFilterButton("Near Limit", ChartFilter.violations),
            if (displayPods.length > 8)
              Padding(
                padding: const EdgeInsets.only(left: 4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.swap_horiz_rounded, size: 13, color: AppTheme.textMuted),
                    SizedBox(width: 3),
                    Text(
                      "Swipe to scroll",
                      style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        // Selected Pod Detail Card (Appears when tapping any bar)
        if (selectedPod != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF131D33),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selectedDeltaT > widget.maxDeltaTempLimit
                    ? AppTheme.coralAlert
                    : AppTheme.bioluminescentCyan.withOpacity(0.7),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      selectedDeltaT > widget.maxDeltaTempLimit
                          ? Icons.warning_amber_rounded
                          : Icons.insights_rounded,
                      color: selectedDeltaT > widget.maxDeltaTempLimit
                          ? AppTheme.coralAlert
                          : AppTheme.bioluminescentCyan,
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "${selectedPod.name}  •  ${selectedPod.location}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _selectedPodIndex = null),
                      child: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _metricSnippet("Ambient Temp", "${selectedAmbient.toStringAsFixed(1)}°C", const Color(0xFF0077B6)),
                    _metricSnippet("Water Rise ΔT", "+${selectedDeltaT.toStringAsFixed(2)}°C", AppTheme.coralAlert),
                    _metricSnippet("Total Temp", "${(selectedAmbient + selectedDeltaT).toStringAsFixed(1)}°C", AppTheme.brightTeal),
                    _metricSnippet(
                      "Status",
                      selectedDeltaT <= widget.maxDeltaTempLimit
                          ? "SAFE (-${(widget.maxDeltaTempLimit - selectedDeltaT).toStringAsFixed(2)}°C margin)"
                          : "ALERT (+${(selectedDeltaT - widget.maxDeltaTempLimit).toStringAsFixed(2)}°C over)",
                      selectedDeltaT <= widget.maxDeltaTempLimit ? AppTheme.marineEmerald : AppTheme.coralAlert,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Main Chart Row: Fixed Y-Axis + Horizontally Scrollable Bars
        SizedBox(
          height: 240,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const double yAxisWidth = 36.0;
              final double availableBarWidth = constraints.maxWidth - yAxisWidth;

              // Ensure each pod has at least 52.0px so words NEVER collide/merge!
              const double minColumnWidth = 52.0;
              final double contentWidth = math.max(
                availableBarWidth,
                displayPods.length * minColumnWidth,
              );
              final double barColumnWidth = contentWidth / math.max(displayPods.length, 1);

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Fixed Y-Axis on the left
                  SizedBox(
                    width: yAxisWidth,
                    child: CustomPaint(
                      painter: _YAxisPainter(),
                    ),
                  ),

                  // Horizontally scrollable chart content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: GestureDetector(
                        onTapUp: (details) {
                          final tapX = details.localPosition.dx;
                          final index = (tapX / barColumnWidth).floor();
                          if (index >= 0 && index < displayPods.length) {
                            setState(() {
                              _selectedPodIndex = _selectedPodIndex == index ? null : index;
                            });
                          }
                        },
                        child: CustomPaint(
                          size: Size(contentWidth, 240),
                          painter: _CoolingBarsPainter(
                            pods: displayPods,
                            oceanMap: oceanMap,
                            maxLimit: widget.maxDeltaTempLimit,
                            barColumnWidth: barColumnWidth,
                            selectedIndex: _selectedPodIndex,
                            deltaTMap: {
                              for (var p in displayPods) p.id: _calculateDeltaT(p, oceanMap[p.id]),
                            },
                            shortLabels: {
                              for (var p in displayPods) p.id: _getPodShortLabel(p),
                            },
                            podCodes: {
                              for (int i = 0; i < displayPods.length; i++)
                                displayPods[i].id: _getPodCode(displayPods[i], i),
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterButton(String text, ChartFilter filter) {
    final isSelected = _filter == filter;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filter = filter;
          _selectedPodIndex = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.bioluminescentCyan.withOpacity(0.2) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppTheme.bioluminescentCyan : Colors.white.withOpacity(0.12),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppTheme.bioluminescentCyan : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _metricSnippet(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("$label: ", style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary)),
        Text(value, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

/// Paints the left Y-Axis with temperature ticks (30°C, 20°C, 10°C, 0°C) and boundary line.
class _YAxisPainter extends CustomPainter {
  static const double topPadding = 20.0;
  static const double bottomPadding = 56.0;
  static const double maxScaleTemp = 30.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paintAxisLine = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 1;

    final chartHeight = size.height - bottomPadding - topPadding;
    final yBase = size.height - bottomPadding;

    // Draw vertical axis line on right edge of Y-axis box
    canvas.drawLine(Offset(size.width - 1, topPadding - 4), Offset(size.width - 1, yBase), paintAxisLine);

    // Draw temperature tick labels
    for (int t = 0; t <= 30; t += 10) {
      final y = yBase - (t / maxScaleTemp) * chartHeight;

      // Small tick mark
      canvas.drawLine(Offset(size.width - 5, y), Offset(size.width - 1, y), paintAxisLine);

      final textSpan = TextSpan(
        text: "$t°",
        style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 9.5, fontWeight: FontWeight.w500),
      );
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      textPainter.paint(canvas, Offset(size.width - 7 - textPainter.width, y - 6));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Paints the horizontal grid lines, limit threshold, and non-overlapping pod bars and labels.
class _CoolingBarsPainter extends CustomPainter {
  final List<PodResource> pods;
  final Map<String, OceanCondition> oceanMap;
  final double maxLimit;
  final double barColumnWidth;
  final int? selectedIndex;
  final Map<String, double> deltaTMap;
  final Map<String, String> shortLabels;
  final Map<String, String> podCodes;

  static const double topPadding = 20.0;
  static const double bottomPadding = 56.0;
  static const double maxScaleTemp = 30.0;

  _CoolingBarsPainter({
    required this.pods,
    required this.oceanMap,
    required this.maxLimit,
    required this.barColumnWidth,
    required this.selectedIndex,
    required this.deltaTMap,
    required this.shortLabels,
    required this.podCodes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintGrid = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 1;

    final paintAmbient = Paint()..color = const Color(0xFF0077B6);
    final paintDelta = Paint()..color = AppTheme.coralAlert;
    final paintLimit = Paint()
      ..color = AppTheme.warningAmber
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final chartHeight = size.height - bottomPadding - topPadding;
    final yBase = size.height - bottomPadding;

    // Draw horizontal grid lines across entire chart width
    for (int t = 0; t <= 30; t += 10) {
      final y = yBase - (t / maxScaleTemp) * chartHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
    }

    // Draw budget threshold line across entire chart width
    final limitY = yBase - (maxLimit / maxScaleTemp) * chartHeight;
    canvas.drawLine(Offset(0, limitY), Offset(size.width, limitY), paintLimit);

    if (pods.isEmpty) return;

    final barWidth = (barColumnWidth * 0.44).clamp(14.0, 26.0);

    for (int i = 0; i < pods.length; i++) {
      final pod = pods[i];
      final ocean = oceanMap[pod.id];
      final ambient = ocean?.waterTemperatureC ?? 10.0;
      final deltaT = deltaTMap[pod.id] ?? 0.5;
      final isSelected = selectedIndex == i;

      final centerX = (i * barColumnWidth) + (barColumnWidth / 2);
      final leftX = centerX - (barWidth / 2);

      // Ambient bar
      final ambientH = (ambient / maxScaleTemp) * chartHeight;
      final ambientY = yBase - ambientH;
      final ambientRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(leftX, ambientY, barWidth, ambientH),
        const Radius.circular(2),
      );
      canvas.drawRRect(ambientRect, paintAmbient);

      // Delta T stacked bar
      final deltaH = (deltaT / maxScaleTemp) * chartHeight;
      final deltaY = ambientY - deltaH;
      final deltaRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(leftX, deltaY, barWidth, deltaH),
        topLeft: const Radius.circular(3),
        topRight: const Radius.circular(3),
      );
      canvas.drawRRect(deltaRect, paintDelta);

      // Selected pod highlight halo
      if (isSelected) {
        final highlightPaint = Paint()
          ..color = AppTheme.bioluminescentCyan
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        final totalH = ambientH + deltaH;
        final highlightRRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(leftX - 3, deltaY - 3, barWidth + 6, totalH + 3),
          const Radius.circular(5),
        );
        canvas.drawRRect(highlightRRect, highlightPaint);

        // Small indicator triangle above bar
        final path = Path()
          ..moveTo(centerX, deltaY - 5)
          ..lineTo(centerX - 4, deltaY - 10)
          ..lineTo(centerX + 4, deltaY - 10)
          ..close();
        canvas.drawPath(path, Paint()..color = AppTheme.bioluminescentCyan);
      }

      // Pod Code (P-01, P-02, etc.) centered directly below baseline
      final podCode = podCodes[pod.id] ?? "P-${i + 1}";
      final codeSpan = TextSpan(
        text: podCode,
        style: TextStyle(
          color: isSelected ? AppTheme.bioluminescentCyan : AppTheme.textSecondary,
          fontSize: 8.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
        ),
      );
      final codePainter = TextPainter(text: codeSpan, textDirection: TextDirection.ltr)..layout();
      codePainter.paint(canvas, Offset(centerX - (codePainter.width / 2), yBase + 4));

      // Angled Location / Name label rotated at +38 degrees:
      // Because barColumnWidth >= 52px, distance between parallel rays is > 32px,
      // which completely eliminates label collisions and prevents text merging!
      final label = shortLabels[pod.id] ?? pod.name.split("-").first;
      final labelSpan = TextSpan(
        text: label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.75),
          fontSize: 8.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      );
      final labelPainter = TextPainter(text: labelSpan, textDirection: TextDirection.ltr)..layout();

      canvas.save();
      // Translate to start just below the pod code tag
      canvas.translate(centerX - 2, yBase + 16);
      canvas.rotate(0.66); // ~38 degrees rotation slanting downward-right
      labelPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CoolingBarsPainter oldDelegate) {
    return oldDelegate.pods != pods ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.barColumnWidth != barColumnWidth ||
        oldDelegate.maxLimit != maxLimit;
  }
}
