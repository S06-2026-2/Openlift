// FE-07 — Card de um treino no feed: autor, data, exercícios e volume.
//
// O volume vem do PublishedWorkout (RN-03: sem aquecimento) e a carga está
// sempre em kg (RN-09). [footer] é o espaço das ações do card (like, FE-08).

import 'package:flutter/material.dart';

import '../../../../core/nostr/nip19.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/published_workout.dart';
import '../network_workouts_view.dart' show shortNpub;

class FeedWorkoutCard extends StatelessWidget {
  const FeedWorkoutCard({super.key, required this.workout, this.footer});

  final PublishedWorkout workout;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final names = workout.exerciseNames;
    final setsCount = workout.sets.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    shortNpub(Nip19.encodeNpub(workout.pubkey)),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(
                  formatDateBr(workout.date),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              names.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 2),
            Text(
              '$setsCount ${setsCount == 1 ? 'série' : 'séries'}'
              ' · ${formatKg(workout.volumeKg)}',
              style: theme.textTheme.bodySmall,
            ),
            if (!workout.isPlausible) ...[
              const SizedBox(height: 2),
              Text(
                'Valores acima dos limites do OpenLift (RN-07): fora de '
                'rankings.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (footer != null) ...[
              const SizedBox(height: 8),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}
