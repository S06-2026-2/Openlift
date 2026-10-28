// FE-05 — Peças de UI da publicação: avisos antes de publicar (RNF-12,
// RF-21) e status por treino com o resultado de cada relay (RF-22, RF-25).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../workouts/domain/workout_model.dart';
import '../publication_controller.dart';

/// Confirma a publicação de um treino privado. Na 1ª vez da conta mostra o
/// consentimento completo e o registra; depois, só o aviso de que é só ida.
/// Sem confirmação, nada é publicado.
Future<bool> confirmPublication(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(publicationControllerProvider.notifier);
  final bool firstTime;
  try {
    firstTime = !await controller.hasConsent();
  } on Object {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Não foi possível preparar a publicação. Tente de novo.'),
      ));
    }
    return false;
  }
  if (!context.mounted) return false;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(firstTime ? 'Publicar treinos no NOSTR' : 'Publicar treino?'),
      content: Text(
        firstTime
            ? 'Um treino publicado fica público: qualquer pessoa pode vê-lo, '
                'aqui e em outros apps compatíveis com NOSTR.\n\n'
                'É permanente. Não dá para voltar a privado, e excluir o '
                'treino no OpenLift não o apaga dos relays.'
            : 'Ele fica público e permanente: não dá para voltar a privado.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Agora não'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(firstTime ? 'Entendi, publicar' : 'Publicar'),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  if (firstTime) {
    try {
      await controller.saveConsent();
    } on Object {
      // Sem registro, a próxima publicação pede o consentimento de novo.
    }
  }
  return true;
}

/// RN-08: depois de editar um treino publicado, pergunta se publica a versão
/// nova (com o mesmo `d`).
Future<bool> confirmRepublication(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Publicar a nova versão?'),
      content: const Text(
        'Este treino já está publicado. A nova versão substitui a anterior '
        'nos apps NOSTR, mas a antiga pode continuar em alguns relays.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Agora não'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Publicar'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Linha de status do treino no histórico: privado / publicando / publicado /
/// falhou, o resultado de cada relay e "Tentar novamente".
class PublicationStatusView extends ConsumerWidget {
  const PublicationStatusView({super.key, required this.workout});

  final WorkoutModel workout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final id = workout.id;
    final session =
        id == null ? null : ref.watch(publicationControllerProvider)[id];
    final publishing = session?.isPublishing ?? false;
    final relays = session?.relays ?? const [];
    final muted = theme.colorScheme.onSurfaceVariant;

    final (IconData icon, String label, Color color) = publishing
        ? (Icons.sync_rounded, 'Publicando...', muted)
        : switch (workout.publishStatus) {
            PublishStatus.published => (
                Icons.public_rounded,
                relays.isEmpty
                    ? 'Publicado'
                    : 'Publicado (${session!.acceptedCount}/${relays.length} '
                        'relays)',
                AppTheme.successColor,
              ),
            PublishStatus.failed => (
                Icons.error_outline_rounded,
                'Falha ao publicar',
                theme.colorScheme.error,
              ),
            PublishStatus.local => (
                Icons.lock_outline_rounded,
                'Privado',
                muted
              ),
          };

    final canRetry = id != null &&
        !publishing &&
        (workout.publishStatus == PublishStatus.failed ||
            (session?.hasFailedRelay ?? false) ||
            session?.errorMessage != null);
    final small = theme.textTheme.bodySmall;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label, style: small?.copyWith(color: color)),
            ),
          ],
        ),
        if (relays.isNotEmpty) ...[
          const SizedBox(height: 2),
          Wrap(
            spacing: 10,
            children: [
              for (final relay in relays)
                Text(
                  '${relay.accepted ? '✓' : '✗'} ${relay.host}',
                  style: small?.copyWith(
                    color: relay.accepted ? muted : theme.colorScheme.error,
                  ),
                ),
            ],
          ),
        ],
        if (session?.errorMessage != null) ...[
          const SizedBox(height: 2),
          Text(
            session!.errorMessage!,
            style: small?.copyWith(color: theme.colorScheme.error),
          ),
        ],
        if (canRetry)
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => ref
                .read(publicationControllerProvider.notifier)
                .publish(workout),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Tentar novamente'),
          ),
      ],
    );
  }
}
