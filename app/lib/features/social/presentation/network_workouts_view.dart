// FE-06 — Aba provisória "Da rede" do histórico: treinos lidos dos relays
// NOSTR, já com a assinatura verificada (RF-51, RNF-02).
//
// Mostra o `npub` deste aparelho (identificador público, para outra pessoa
// colar) e deixa adicionar o `npub` de alguém para ver os treinos dela —
// o teste da Demo 3: publicar no dispositivo A e ver no B.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nostr/nip19.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/page_layout.dart';
import '../data/network_workouts_service.dart';
import '../domain/published_workout.dart';
import 'network_feed_controller.dart';

/// `npub1abcdefgh…wxyz` para caber na tela.
String shortNpub(String npub) => npub.length <= 20
    ? npub
    : '${npub.substring(0, 12)}…${npub.substring(npub.length - 6)}';

class NetworkWorkoutsView extends ConsumerWidget {
  const NetworkWorkoutsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(networkFeedProvider);
    final own = ref.watch(ownIdentityProvider).valueOrNull;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(networkFeedProvider.future).then(
            (_) {},
            onError: (Object _) {},
          ),
      child: LayoutBuilder(
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: pagePadding(constraints, bottom: 96),
          children: [
            if (own != null) _OwnIdentityCard(npub: own.npub),
            const SizedBox(height: 12),
            const _AddPersonField(),
            const SizedBox(height: 20),
            ...feed.when(
              skipLoadingOnRefresh: false,
              loading: () => const [
                SizedBox(
                  height: 160,
                  child: LoadingIndicator(message: 'Lendo os relays...'),
                ),
              ],
              error: (error, _) => [
                ErrorBanner(
                  message: error is RelaysUnavailableException
                      ? error.message
                      : 'Não foi possível ler os treinos da rede.',
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Tentar novamente',
                  icon: Icons.refresh_rounded,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => ref.invalidate(networkFeedProvider),
                ),
              ],
              data: (data) => _feedChildren(context, data, own?.publicKeyHex),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _feedChildren(
    BuildContext context,
    NetworkFeed feed,
    String? ownPubkey,
  ) {
    final theme = Theme.of(context);
    final responded = feed.relays.where((r) => r.responded).length;
    final source = <String>[
      'Lido de $responded de ${feed.relays.length} '
          '${feed.relays.length == 1 ? 'relay' : 'relays'}',
      if (feed.discarded > 0)
        '${feed.discarded} ${feed.discarded == 1 ? 'evento descartado' : 'eventos descartados'}'
            ' (assinatura inválida)',
    ].join(' · ');

    return [
      SectionLabel(
        feed.workouts.length == 1
            ? '1 treino na rede'
            : '${feed.workouts.length} treinos na rede',
      ),
      const SizedBox(height: 4),
      Text(source, style: theme.textTheme.bodySmall),
      const SizedBox(height: 12),
      if (feed.workouts.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'Nenhum treino publicado ainda. Publique um treino ou adicione '
            'o npub de alguém.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        )
      else
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < feed.workouts.length; i++) ...[
                if (i > 0) const Divider(),
                _NetworkWorkoutRow(
                  workout: feed.workouts[i],
                  isOwn: feed.workouts[i].pubkey == ownPubkey,
                ),
              ],
            ],
          ),
        ),
    ];
  }
}

class _OwnIdentityCard extends StatelessWidget {
  const _OwnIdentityCard({required this.npub});

  final String npub;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Seu npub', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(shortNpub(npub), style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    'Identificador público. Compartilhe para outra pessoa '
                    'ver seus treinos publicados.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Copiar npub',
              icon: const Icon(Icons.copy_rounded, size: 20),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await Clipboard.setData(ClipboardData(text: npub));
                messenger.showSnackBar(
                  const SnackBar(content: Text('npub copiado.')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AddPersonField extends ConsumerStatefulWidget {
  const _AddPersonField();

  @override
  ConsumerState<_AddPersonField> createState() => _AddPersonFieldState();
}

class _AddPersonFieldState extends ConsumerState<_AddPersonField> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final error =
        ref.read(followedNpubsProvider.notifier).add(_controller.text);
    setState(() => _error = error);
    if (error == null) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final followed = ref.watch(followedNpubsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _add(),
          decoration: InputDecoration(
            labelText: 'Ver treinos de outra pessoa',
            hintText: 'Cole o npub dela',
            errorText: _error,
            suffixIcon: IconButton(
              tooltip: 'Adicionar',
              icon: const Icon(Icons.person_add_alt_rounded, size: 20),
              onPressed: _add,
            ),
          ),
        ),
        if (followed.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final npub in followed)
                InputChip(
                  label: Text(shortNpub(npub)),
                  onDeleted: () =>
                      ref.read(followedNpubsProvider.notifier).remove(npub),
                  deleteButtonTooltipMessage: 'Remover',
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _NetworkWorkoutRow extends StatelessWidget {
  const _NetworkWorkoutRow({required this.workout, required this.isOwn});

  final PublishedWorkout workout;
  final bool isOwn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final names = workout.exerciseNames;
    final setsCount = workout.sets.length;
    final author = isOwn ? 'Você' : shortNpub(Nip19.encodeNpub(workout.pubkey));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatDateBr(workout.date),
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Text(author, style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            names.length <= 3
                ? names.join(' · ')
                : '${names.take(3).join(' · ')} +${names.length - 3}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
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
        ],
      ),
    );
  }
}
