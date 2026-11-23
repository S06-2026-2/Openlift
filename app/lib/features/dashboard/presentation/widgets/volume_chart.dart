// Gráfico de barras do volume por semana ou por mês (RF-42), com fl_chart.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/stats_model.dart';

const _months = [
  'jan', 'fev', 'mar', 'abr', 'mai', 'jun', //
  'jul', 'ago', 'set', 'out', 'nov', 'dez',
];

/// "16/11" para semana, "nov" para mês.
String periodLabel(DateTime start, StatsScale scale) =>
    scale == StatsScale.month
        ? _months[start.month - 1]
        : '${start.day.toString().padLeft(2, '0')}/'
            '${start.month.toString().padLeft(2, '0')}';

class VolumeChart extends StatelessWidget {
  const VolumeChart({super.key, required this.stats});

  final VolumeStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final periods = stats.periods;
    final max = periods.fold<double>(0, (m, p) => p.volume > m ? p.volume : m);
    final top = max <= 0 ? 1.0 : max * 1.15;

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          maxY: top,
          minY: 0,
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: top / 4,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: scheme.outline, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= periods.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      periodLabel(periods[i].periodStart, stats.scale),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(letterSpacing: 0, fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                '${formatKg(rod.toY)}\n'
                '${periods[group.x].workouts} treino(s)',
                TextStyle(color: scheme.onInverseSurface, fontSize: 12),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < periods.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: periods[i].volume,
                    width: stats.scale == StatsScale.month ? 26 : 18,
                    color: i == periods.length - 1
                        ? scheme.primary
                        : scheme.primary.withValues(alpha: 0.45),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(5),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
