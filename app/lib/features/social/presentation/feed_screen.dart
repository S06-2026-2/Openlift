// FE-07 — Aba Social: feed cronológico dos treinos de quem a pessoa segue
// (RF-31), lido dos relays NOSTR com a assinatura verificada no app.
//
// Estados: carregando, erro de rede com "Tentar novamente", "você ainda não
// segue ninguém", ninguém publicou ainda e a lista, com "Carregar mais" para
// os treinos anteriores (paginação por `until`).
//
// FE-08: cada card tem o botão de curtir; as contagens vêm de
// `GET /social/likes` sempre que o feed carrega ou ganha uma página.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/page_layout.dart';
import '../../workouts/presentation/widgets/state_views.dart';
import '../data/network_workouts_service.dart';
import 'feed_controller.dart';
import 'likes_controller.dart';
import 'network_feed_controller.dart';
import 'widgets/feed_workout_card.dart';
import 'widgets/like_button.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  void _retry(WidgetRef ref) => ref
    ..invalidate(followingProvider)
    ..invalidate(feedProvider);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider);
    // Mantém as curtidas vivas enquanto o feed está na tela.
    ref.watch(likesProvider);
    ref.listen(feedProvider, (_, next) {
      final workouts = next.valueOrNull?.workouts ?? const [];
      ref
          .read(likesProvider.notifier)
          .fetch([for (final w in workouts) w.eventId]);
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Social')),
      body: feed.when(
        skipLoadingOnRefresh: false,
        loading: () => const LoadingIndicator(message: 'Carregando o feed...'),
        error: (error, _) => ErrorStateView(
          message: error is RelaysUnavailableException
              ? error.message
              : 'Não foi possível carregar o feed.',
          onRetry: () => _retry(ref),
        ),
        data: (state) {
          if (!state.followsAnyone) {
            return EmptyStateView(
              icon: Icons.people_outline_rounded,
              title: 'Você ainda não segue ninguém',
              description: 'Busque alguém pelo ID em Treinos → Da rede, e os '
                  'treinos publicados por essa pessoa aparecem aqui.',
              actionLabel: 'Seguir alguém',
              onAction: () => context.go(AppRoutes.workouts),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(feedProvider.future).then(
                  (_) {},
                  onError: (Object _) {},
                ),
            child: state.workouts.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 120),
                      const _NobodyPublished(),
                      // Tudo descartado não é "ninguém publicou": avisa.
                      if (state.discarded > 0) ...[
                        const SizedBox(height: 12),
                        Center(child: _DiscardedNote(state.discarded)),
                      ],
                    ],
                  )
                : _FeedList(state: state),
          );
        },
      ),
    );
  }
}

class _NobodyPublished extends StatelessWidget {
  const _NobodyPublished();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(
        'Quem você segue ainda não publicou nenhum treino.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// RF-51: eventos recusados por assinatura inválida, para não sumirem calados.
class _DiscardedNote extends StatelessWidget {
  const _DiscardedNote(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$count ${count == 1 ? 'evento descartado' : 'eventos descartados'}'
      ' (assinatura inválida)',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

class _FeedList extends StatelessWidget {
  const _FeedList({required this.state});

  final FeedState state;

  @override
  Widget build(BuildContext context) {
    final workouts = state.workouts;
    // Itens: treinos + rodapé (aviso de descartados e/ou "Carregar mais").
    final hasFooter = state.hasMore || state.discarded > 0;

    return LayoutBuilder(
      builder: (context, constraints) => ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: pagePadding(constraints, bottom: 96),
        itemCount: workouts.length + (hasFooter ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < workouts.length) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FeedWorkoutCard(
                workout: workouts[index],
                footer: LikeButton(workout: workouts[index]),
              ),
            );
          }
          return _FeedFooter(state: state);
        },
      ),
    );
  }
}

class _FeedFooter extends ConsumerStatefulWidget {
  const _FeedFooter({required this.state});

  final FeedState state;

  @override
  ConsumerState<_FeedFooter> createState() => _FeedFooterState();
}

class _FeedFooterState extends ConsumerState<_FeedFooter> {
  bool _loading = false;

  Future<void> _loadMore() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      await ref.read(feedProvider.notifier).loadMore();
    } on RelaysUnavailableException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } on Object {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Não foi possível carregar mais treinos.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final discarded = widget.state.discarded;
    return Column(
      children: [
        if (discarded > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DiscardedNote(discarded),
          ),
        if (widget.state.hasMore)
          AppButton(
            label: 'Carregar mais',
            icon: Icons.expand_more_rounded,
            variant: AppButtonVariant.secondary,
            isLoading: _loading,
            onPressed: _loadMore,
          ),
      ],
    );
  }
}
