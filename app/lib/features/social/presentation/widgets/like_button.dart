// FE-08 — Botão de curtir no card do feed (RF-32): coração + contagem.
//
// Curtido, fica marcado e desabilitado (não há descurtir; ver
// likes_controller.dart). Falha de publicação vira aviso na tela.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/published_workout.dart';
import '../likes_controller.dart';

class LikeButton extends ConsumerWidget {
  const LikeButton({super.key, required this.workout});

  final PublishedWorkout workout;

  Future<void> _like(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await ref.read(likesProvider.notifier).like(workout);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likes = ref.watch(
      likesProvider.select((state) => state[workout.eventId]),
    );
    final liked = likes?.likedByMe ?? false;
    final count = likes?.count ?? 0;
    final theme = Theme.of(context);

    return Row(
      children: [
        IconButton(
          tooltip: liked ? 'Você curtiu' : 'Curtir',
          onPressed: liked ? null : () => _like(context, ref),
          icon: Icon(
            liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 20,
            color: liked ? theme.colorScheme.primary : null,
          ),
        ),
        Text(
          count == 1 ? '1 curtida' : '$count curtidas',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
