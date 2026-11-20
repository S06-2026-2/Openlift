// Frequência por grupo muscular: em quantos dias cada grupo foi treinado no
// período, em barras horizontais (do mais frequente para o menos).

import 'package:flutter/material.dart';

import '../../domain/stats_model.dart';

class MuscleFrequencyChart extends StatelessWidget {
  const MuscleFrequencyChart({
    super.key,
    required this.groups,
    required this.periodDays,
  });

  final List<MuscleGroupStats> groups;
  final int periodDays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sorted = [...groups]..sort((a, b) {
        final bySessions = b.sessions.compareTo(a.sessions);
        return bySessions != 0 ? bySessions : b.volume.compareTo(a.volume);
      });
    final max = sorted.fold<int>(0, (m, g) => g.sessions > m ? g.sessions : m);

    return Column(
      children: [
        for (final group in sorted)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 104,
                  child: Text(
                    group.name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: max == 0 ? 0 : group.sessions / max,
                      minHeight: 10,
                      backgroundColor: scheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(scheme.primary),
                    ),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    group.sessions == 1 ? '1 dia' : '${group.sessions} dias',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: group.sessions > 0 ? scheme.onSurface : null,
                      fontWeight: group.sessions > 0 ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
