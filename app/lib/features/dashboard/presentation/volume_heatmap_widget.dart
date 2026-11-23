// Mapa de calor de volume (RF-41): grupo muscular × semana ou mês, cor por
// intensidade de volume. O grupo mais treinado fica no topo, destacado.

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../domain/stats_model.dart';
import 'widgets/volume_chart.dart' show periodLabel;

/// Cor da célula: vazio sem volume; senão um dos 4 níveis de [AppTheme.heatScale]
/// proporcional ao maior volume do mapa.
Color heatColor(double volume, double max, Color empty) {
  if (volume <= 0 || max <= 0) return empty;
  const scale = AppTheme.heatScale;
  final level = ((volume / max) * scale.length).ceil().clamp(1, scale.length);
  return scale[level - 1];
}

class VolumeHeatmap extends StatelessWidget {
  const VolumeHeatmap({
    super.key,
    required this.rows,
    required this.columns,
    required this.scale,
  });

  final List<HeatmapRow> rows;

  /// Início de cada coluna (semana ou mês).
  final List<DateTime> columns;
  final StatsScale scale;

  static const double _cell = 22;
  static const double _gap = 4;
  static const double _labelWidth = 104;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final empty = theme.colorScheme.surfaceContainerHighest;
    final max = rows.fold<double>(
      0,
      (m, row) => row.values.fold(m, (n, v) => v > n ? v : n),
    );
    final topId = rows.isNotEmpty && rows.first.total > 0
        ? rows.first.muscleGroupId
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: _gap),
                  child: Row(
                    children: [
                      SizedBox(
                        width: _labelWidth,
                        child: Row(
                          children: [
                            if (row.muscleGroupId == topId) ...[
                              Icon(
                                Icons.local_fire_department_rounded,
                                size: 14,
                                color: AppTheme.heatScale.last,
                              ),
                              const SizedBox(width: 2),
                            ],
                            Flexible(
                              child: Text(
                                row.name,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: row.muscleGroupId == topId
                                      ? theme.colorScheme.onSurface
                                      : null,
                                  fontWeight: row.muscleGroupId == topId
                                      ? FontWeight.w600
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (var i = 0; i < row.values.length; i++) ...[
                        if (i > 0) const SizedBox(width: _gap),
                        Tooltip(
                          message: '${row.name} · '
                              '${scale == StatsScale.month ? 'mês de' : 'semana de'} '
                              '${periodLabel(columns[i], scale)}: '
                              '${formatKg(row.values[i])}',
                          child: Container(
                            key: ValueKey(
                              'heat-${row.muscleGroupId}-$i',
                            ),
                            width: _cell,
                            height: _cell,
                            decoration: BoxDecoration(
                              color: heatColor(row.values[i], max, empty),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              Row(
                children: [
                  const SizedBox(width: _labelWidth),
                  for (var i = 0; i < columns.length; i++) ...[
                    if (i > 0) const SizedBox(width: _gap),
                    SizedBox(
                      width: _cell,
                      child: scale == StatsScale.month ||
                              i.isEven ||
                              i == columns.length - 1
                          ? Text(
                              scale == StatsScale.month
                                  ? periodLabel(columns[i], scale)
                                  : periodLabel(columns[i], scale)
                                      .substring(0, 2),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(letterSpacing: 0, fontSize: 10),
                            )
                          : null,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('Menos', style: theme.textTheme.bodySmall),
            const SizedBox(width: 6),
            for (final color in [empty, ...AppTheme.heatScale]) ...[
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 3),
            ],
            const SizedBox(width: 3),
            Text('Mais', style: theme.textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}
