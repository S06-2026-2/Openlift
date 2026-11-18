// FE-08 — Curtidas dos treinos do feed, com atualização otimista.
//
// A contagem vem de `GET /social/likes` (BE-10). Curtir soma 1 na hora; se
// nenhum relay aceitar o kind 7, volta ao que era. Enquanto o worker não
// processa o like (um ciclo), a API ainda responde sem ele: o like feito
// neste aparelho continua aparecendo até a API confirmar.
//
// Não há "descurtir": o worker ignora o content "-" (dislike na NIP-25) e
// ainda não processa exclusão (kind 5). Curtido, o botão fica marcado.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/like_service.dart';
import '../data/social_repository.dart';
import '../domain/like_model.dart';
import '../domain/published_workout.dart';

class LikesController extends AutoDisposeNotifier<Map<String, LikeCount>> {
  /// Curtidos neste aparelho e ainda não confirmados pela API.
  final Set<String> _unconfirmed = {};

  /// Likes sendo publicados agora (barra o toque duplo).
  final Set<String> _publishing = {};

  @override
  Map<String, LikeCount> build() => const {};

  LikeCount countFor(String eventId) =>
      state[eventId] ?? LikeCount(eventId: eventId);

  /// Busca as contagens de [eventIds] na API. Falha deixa as contagens como
  /// estavam: o feed continua utilizável sem elas.
  Future<void> fetch(List<String> eventIds) async {
    if (eventIds.isEmpty) return;
    final List<LikeCount> counts;
    try {
      counts = await ref.read(socialRepositoryProvider).getLikeCounts(eventIds);
    } on Object {
      return;
    }
    final next = {...state};
    for (final count in counts) {
      if (count.likedByMe) {
        _unconfirmed.remove(count.eventId);
        next[count.eventId] = count;
      } else if (_unconfirmed.contains(count.eventId)) {
        // O worker ainda não viu o like: mantém o otimista.
        next[count.eventId] = LikeCount(
          eventId: count.eventId,
          count: count.count + 1,
          likedByMe: true,
        );
      } else {
        next[count.eventId] = count;
      }
    }
    state = next;
  }

  /// Curte [workout]. Devolve a mensagem de erro para a tela, ou `null`.
  Future<String?> like(PublishedWorkout workout) async {
    final id = workout.eventId;
    final before = countFor(id);
    if (before.likedByMe || !_publishing.add(id)) return null;
    state = {
      ...state,
      id: LikeCount(eventId: id, count: before.count + 1, likedByMe: true),
    };
    try {
      await ref.read(likeServiceProvider).like(workout);
      _unconfirmed.add(id);
      return null;
    } on Object catch (e) {
      state = {...state, id: before};
      return e is LikePublishException
          ? e.message
          : const LikePublishException().message;
    } finally {
      _publishing.remove(id);
    }
  }
}

final likesProvider =
    NotifierProvider.autoDispose<LikesController, Map<String, LikeCount>>(
  LikesController.new,
);
