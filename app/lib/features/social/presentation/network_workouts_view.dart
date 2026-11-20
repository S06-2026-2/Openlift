// FE-06 — Aba provisória "Da rede" do histórico: treinos lidos dos relays
// NOSTR, já com a assinatura verificada (RF-51, RNF-02).
//
// Mostra o ID deste aparelho (o `npub`, identificador público, para outra
// pessoa colar) e deixa buscar alguém pelo ID: aparecem os treinos que a
// pessoa publicou e o botão de seguir. Desde o NOSTR-04, seguir publica a
// contact list (kind 3) e vale em qualquer aparelho com a mesma identidade.

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

/// ID (`npub1abcdefgh…wxyz`) encurtado para caber na tela.
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
            const _IdSearch(),
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
                  onPressed: () => ref
                    ..invalidate(followingProvider)
                    ..invalidate(networkFeedProvider),
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
            'Nenhum treino publicado ainda. Publique um treino ou busque '
            'alguém pelo ID.',
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
                  Text('Seu ID', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(shortNpub(npub), style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    'Seu identificador público na rede. Compartilhe para '
                    'outra pessoa te encontrar e ver seus treinos.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Copiar ID',
              icon: const Icon(Icons.copy_rounded, size: 20),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await Clipboard.setData(ClipboardData(text: npub));
                messenger.showSnackBar(
                  const SnackBar(content: Text('ID copiado.')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Busca de pessoa pelo ID + quem a pessoa já segue.
class _IdSearch extends ConsumerStatefulWidget {
  const _IdSearch();

  @override
  ConsumerState<_IdSearch> createState() => _IdSearchState();
}

class _IdSearchState extends ConsumerState<_IdSearch> {
  final _controller = TextEditingController();
  String? _error;

  /// Chave pública (hex) de quem foi encontrado.
  String? _found;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    String? error;
    String? found;
    try {
      found = parseIdInput(_controller.text);
      final own = await ref.read(ownIdentityProvider.future);
      if (found == own.publicKeyHex) {
        found = null;
        error = IdInputException.ownId;
      }
    } on IdInputException catch (e) {
      error = e.message;
    } on Object {
      error = 'Não foi possível buscar agora. Tente novamente.';
    }
    if (!mounted) return;
    setState(() {
      _error = error;
      _found = found;
    });
  }

  void _close() {
    setState(() => _found = null);
    _controller.clear();
  }

  Future<void> _unfollow(String pubkey) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await ref.read(followingProvider.notifier).unfollow(pubkey);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final following = ref.watch(followingProvider).valueOrNull;
    final found = _found;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          autocorrect: false,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: InputDecoration(
            labelText: 'Buscar pessoa pelo ID',
            hintText: 'Cole o ID dela (npub1...)',
            errorText: _error,
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: IconButton(
              tooltip: 'Buscar',
              icon: const Icon(Icons.arrow_forward_rounded, size: 20),
              onPressed: _search,
            ),
          ),
        ),
        if (found != null) ...[
          const SizedBox(height: 12),
          _PersonResult(pubkey: found, onClose: _close),
        ],
        if (following != null && !following.isEmpty) ...[
          const SizedBox(height: 12),
          Text(
            following.pubkeys.length == 1
                ? 'Seguindo 1 pessoa'
                : 'Seguindo ${following.pubkeys.length} pessoas',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final pubkey in following.pubkeys)
                InputChip(
                  label: Text(shortNpub(Nip19.encodeNpub(pubkey))),
                  onDeleted: () => _unfollow(pubkey),
                  deleteButtonTooltipMessage: 'Deixar de seguir',
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Resultado da busca: o ID encontrado, os treinos publicados e seguir.
class _PersonResult extends ConsumerStatefulWidget {
  const _PersonResult({required this.pubkey, required this.onClose});

  final String pubkey;
  final VoidCallback onClose;

  @override
  ConsumerState<_PersonResult> createState() => _PersonResultState();
}

class _PersonResultState extends ConsumerState<_PersonResult> {
  bool _busy = false;

  Future<void> _toggleFollow({required bool following}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(followingProvider.notifier);
    final error = following
        ? await notifier.unfollow(widget.pubkey)
        : await notifier.followPubkey(widget.pubkey);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contacts = ref.watch(followingProvider).valueOrNull;
    final isFollowing = contacts?.contains(widget.pubkey) ?? false;
    final workouts = ref.watch(personWorkoutsProvider(widget.pubkey));
    final id = shortNpub(Nip19.encodeNpub(widget.pubkey));

    String summary(NetworkFeed feed) {
      if (feed.workouts.isEmpty) {
        return 'Nenhum treino publicado por esse ID ainda.';
      }
      final last = formatDateBr(feed.workouts.first.date);
      return feed.workouts.length == 1
          ? '1 treino publicado · último em $last'
          : '${feed.workouts.length} treinos publicados · último em $last';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person_rounded,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pessoa encontrada',
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(id, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar busca',
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: widget.onClose,
                ),
              ],
            ),
            const SizedBox(height: 12),
            workouts.when(
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (_, __) => Text(
                'Não deu para ler os treinos dessa pessoa agora.',
                style: theme.textTheme.bodySmall,
              ),
              data: (feed) =>
                  Text(summary(feed), style: theme.textTheme.bodySmall),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AppButton(
                label: isFollowing ? 'Seguindo' : 'Seguir',
                icon: isFollowing
                    ? Icons.check_rounded
                    : Icons.person_add_alt_rounded,
                variant: isFollowing
                    ? AppButtonVariant.secondary
                    : AppButtonVariant.primary,
                isLoading: _busy,
                onPressed: contacts == null
                    ? null
                    : () => _toggleFollow(following: isFollowing),
              ),
            ),
            if (isFollowing)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Toque em "Seguindo" para deixar de seguir.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
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
