// FE-08 — Curtidas de um treino publicado (RF-32, RN-06).
//
// - [LikeCount]: contagem do cache do backend (`GET /social/likes`, BE-10),
//   que o worker projeta a partir dos kind 7 assinados (ADR-0004);
// - [LikeEvent]: o kind 7 (NIP-25) que o app assina para curtir.

import '../../../core/nostr/nostr_event.dart';
import '../../../core/nostr/nostr_kinds.dart';
import '../../../core/utils/json_utils.dart';
import 'published_workout.dart';

class LikeCount {
  const LikeCount({
    required this.eventId,
    this.count = 0,
    this.likedByMe = false,
  });

  factory LikeCount.fromJson(Map<String, dynamic> json) {
    final eventId = json['event_id'];
    if (eventId is! String) throw const FormatException('Like sem event_id');
    return LikeCount(
      eventId: eventId,
      count: asInt(json['count']) ?? 0,
      likedByMe: json['liked_by_me'] == true,
    );
  }

  /// `id` do kind 1301 curtido.
  final String eventId;

  /// Pessoas diferentes que curtiram (RN-06: uma por pubkey).
  final int count;
  final bool likedByMe;
}

abstract final class LikeEvent {
  /// `content` de like na NIP-25. O "-" é dislike, que o OpenLift não usa.
  static const String like = '+';

  /// Kind 7 curtindo [workout]: tag `e` com o evento (a última `e` é o alvo,
  /// NIP-25), `p` com o autor e `k` com o kind do alvo.
  static UnsignedNostrEvent build({
    required String pubkey,
    required PublishedWorkout workout,
    required int createdAt,
    String relayHint = '',
  }) =>
      UnsignedNostrEvent(
        pubkey: pubkey,
        createdAt: createdAt,
        kind: NostrKinds.reaction,
        tags: [
          ['e', workout.eventId, relayHint, workout.pubkey],
          ['p', workout.pubkey, relayHint],
          ['k', '${NostrKinds.workoutRecord}'],
        ],
        content: like,
      );
}
