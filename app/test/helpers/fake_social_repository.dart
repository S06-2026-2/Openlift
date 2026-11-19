// Helper de teste: SocialRepository em memória (sem rede). Responde as
// contagens de [counts] e guarda os ids de cada chamada.

import 'package:openlift/core/network/api_exception.dart';
import 'package:openlift/features/social/data/social_repository.dart';
import 'package:openlift/features/social/domain/like_model.dart';

class FakeSocialRepository implements SocialRepository {
  /// Contagem que a "API" devolve por `event_id`; id fora do mapa tem 0.
  final Map<String, LikeCount> counts = {};

  /// Ids pedidos em cada chamada.
  final List<List<String>> calls = [];

  /// Se definido, `getLikeCounts` falha com ele.
  ApiException? error;

  @override
  Future<List<LikeCount>> getLikeCounts(List<String> eventIds) async {
    calls.add(List.of(eventIds));
    final failure = error;
    if (failure != null) throw failure;
    return [
      for (final id in eventIds) counts[id] ?? LikeCount(eventId: id),
    ];
  }
}
