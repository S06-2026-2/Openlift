// FE-07 — Card de um treino no feed: autor, data, exercícios e volume.
//
// O volume vem do PublishedWorkout (RN-03: sem aquecimento) e a carga está
// sempre em kg (RN-09). [footer] é o espaço das ações do card (like, FE-08).
// Com [author] (perfil da rede social, ADR-0012), o card mostra foto e nome
// de usuário no lugar do ID encurtado; tocar no autor abre o perfil.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/nostr/nip19.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/router/app_routes.dart';
import '../../domain/profile_model.dart';
import '../../domain/published_workout.dart';
import '../network_workouts_view.dart' show shortNpub;
import 'profile_avatar.dart';

class FeedWorkoutCard extends StatelessWidget {
  const FeedWorkoutCard({
    super.key,
    required this.workout,
    this.footer,
    this.author,
  });

  final PublishedWorkout workout;
  final Widget? footer;
  final SocialProfile? author;

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
                Expanded(child: _Author(workout: workout, author: author)),
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

class _Author extends StatelessWidget {
  const _Author({required this.workout, required this.author});

  final PublishedWorkout workout;
  final SocialProfile? author;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = author;
    if (profile == null) {
      return Text(
        shortNpub(Nip19.encodeNpub(workout.pubkey)),
        style: theme.textTheme.titleSmall,
      );
    }
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => GoRouter.of(context).go(AppRoutes.person(profile.username)),
      child: Row(
        children: [
          ProfileAvatar(
            name: profile.title,
            url: profile.avatarUrl,
            radius: 14,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              profile.handle,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}
