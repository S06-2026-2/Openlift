// FE-07 — Feed cronológico de quem a pessoa segue (RF-31).
//
// Os autores vêm da contact list (NOSTR-04, [followingProvider]); os treinos,
// direto dos relays, com assinatura verificada no app (RF-51, RNF-02), um por
// `id` (RF-24) e só a versão mais nova de cada treino (RN-08). Nada passa pelo
// backend.
//
// Paginação por `until` (NIP-01): a 1ª página traz os mais novos e
// [FeedController.loadMore] pede os anteriores ao mais antigo já recebido.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/network_workouts_service.dart';
import '../domain/published_workout.dart';
import 'network_feed_controller.dart';

class FeedState {
  const FeedState({
    this.workouts = const [],
    this.followsAnyone = true,
    this.nextUntil,
    this.discarded = 0,
  });

  /// Mais recentes primeiro.
  final List<PublishedWorkout> workouts;

  /// `false` quando a contact list está vazia ("você ainda não segue
  /// ninguém").
  final bool followsAnyone;

  /// `until` da próxima página; `null` quando não há mais.
  final int? nextUntil;

  /// Eventos recusados por assinatura inválida, somando as páginas.
  final int discarded;

  bool get hasMore => nextUntil != null;
}

class FeedController extends AutoDisposeAsyncNotifier<FeedState> {
  /// Treinos por página. Pequeno o bastante para a 1ª tela chegar rápido.
  static const int pageSize = 50;

  List<String> _authors = const [];
  bool _loadingMore = false;

  @override
  Future<FeedState> build() async {
    final following = await ref.watch(followingProvider.future);
    _authors = following.pubkeys;
    if (_authors.isEmpty) return const FeedState(followsAnyone: false);
    final page = await _page(until: null);
    return _merge(const FeedState(), page);
  }

  /// Busca a página seguinte e junta ao fim. Lança
  /// [RelaysUnavailableException] se nenhum relay respondeu; o que já estava
  /// na tela continua.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || _loadingMore) return;
    _loadingMore = true;
    try {
      final page = await _page(until: current.nextUntil);
      state = AsyncData(_merge(current, page));
    } finally {
      _loadingMore = false;
    }
  }

  Future<NetworkFeed> _page({required int? until}) =>
      ref.read(networkWorkoutsServiceProvider).load(
            _authors,
            until: until,
            limit: pageSize,
          );

  /// Junta [page] depois de [current]. Treino já exibido (mesmo `id`, ou
  /// versão mais antiga de um treino já na tela) não entra de novo.
  static FeedState _merge(FeedState current, NetworkFeed page) {
    final seenIds = {for (final w in current.workouts) w.eventId};
    final seenWorkouts = {for (final w in current.workouts) _key(w)};
    final added = [
      for (final w in page.workouts)
        if (!seenIds.contains(w.eventId) && !seenWorkouts.contains(_key(w))) w,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final oldest = page.oldestCreatedAt;
    return FeedState(
      workouts: [...current.workouts, ...added],
      nextUntil: page.reachedLimit && oldest != null ? oldest - 1 : null,
      discarded: current.discarded + page.discarded,
    );
  }

  /// Treinos sem `d` não têm versão: cada evento é um treino.
  static String _key(PublishedWorkout w) => '${w.pubkey}:${w.d ?? w.eventId}';
}

final feedProvider =
    AsyncNotifierProvider.autoDispose<FeedController, FeedState>(
  FeedController.new,
);
