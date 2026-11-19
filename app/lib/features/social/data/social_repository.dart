// FE-08 — Contadores sociais do cache do backend (BE-10).
//
//   GET /social/likes?event_ids=a&event_ids=b -> [{event_id, count, liked_by_me}]
//
// A contagem é cache do worker (ADR-0004): um like recém-publicado pode levar
// um ciclo para aparecer. Até 100 ids por requisição; mais que isso vai em
// várias requisições.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/like_model.dart';

class SocialRepository {
  SocialRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  /// Limite de `event_ids` por requisição na API.
  static const int maxEventIds = 100;

  /// Uma contagem por id pedido (repetidos contam uma vez).
  Future<List<LikeCount>> getLikeCounts(List<String> eventIds) async {
    final unique = eventIds.toSet().toList();
    final result = <LikeCount>[];
    for (var start = 0; start < unique.length; start += maxEventIds) {
      final end = (start + maxEventIds).clamp(0, unique.length);
      result.addAll(await _fetch(unique.sublist(start, end)));
    }
    return result;
  }

  Future<List<LikeCount>> _fetch(List<String> ids) async {
    try {
      final response = await _api.dio.get<List<dynamic>>(
        '/social/likes',
        queryParameters: {'event_ids': ids},
        options: Options(listFormat: ListFormat.multi),
      );
      return [
        for (final item in response.data ?? const [])
          LikeCount.fromJson(item as Map<String, dynamic>),
      ];
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on ApiException {
      rethrow;
    } on Object {
      throw const ApiException('Resposta inesperada do servidor.');
    }
  }
}

final socialRepositoryProvider = Provider<SocialRepository>(
  (ref) => SocialRepository(api: ref.watch(apiClientProvider)),
);
