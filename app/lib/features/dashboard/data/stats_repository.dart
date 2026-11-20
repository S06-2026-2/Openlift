// Estatísticas do dashboard (RF-41, RF-42) lidas da API (RF-54).
//
// Contrato, base /api/v1:
//   GET /stats/volume?weeks&date_to             -> {weeks, total_volume, total_workouts}
//   GET /stats/muscle-groups?date_from&date_to  -> [{muscle_group_id, muscle_group, volume, sets, sessions}]
//   GET /stats/heatmap?date_from&date_to        -> {date_from, date_to, muscle_groups, cells}
//
// O app manda a data local em `date_to`: a "semana atual" é a do aparelho,
// não a do relógio do servidor.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/stats_model.dart';

class StatsRepository {
  StatsRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  static const Map<int, String> _errors = {
    422: 'Período inválido para as estatísticas.',
  };

  Future<VolumeStats> getVolume({required DateTime until, int weeks = 8}) {
    return _guard(() async {
      final response = await _api.dio.get<dynamic>(
        '/stats/volume',
        queryParameters: {'weeks': weeks, 'date_to': toApiDate(until)},
      );
      return VolumeStats.fromJson(response.data);
    });
  }

  Future<List<MuscleGroupStats>> getMuscleGroups({
    required DateTime from,
    required DateTime to,
  }) {
    return _guard(() async {
      final response = await _api.dio.get<dynamic>(
        '/stats/muscle-groups',
        queryParameters: {
          'date_from': toApiDate(from),
          'date_to': toApiDate(to),
        },
      );
      final data = response.data;
      if (data is! List) throw const FormatException('Lista esperada');
      return [
        for (final item in data)
          MuscleGroupStats.fromJson(item as Map<String, dynamic>),
      ];
    });
  }

  Future<HeatmapData> getHeatmap({
    required DateTime from,
    required DateTime to,
  }) {
    return _guard(() async {
      final response = await _api.dio.get<dynamic>(
        '/stats/heatmap',
        queryParameters: {
          'date_from': toApiDate(from),
          'date_to': toApiDate(to),
        },
      );
      return HeatmapData.fromJson(response.data);
    });
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw ApiException.fromDio(e, overrides: _errors);
    } on ApiException {
      rethrow;
    } on Object {
      throw const ApiException('Resposta inesperada do servidor.');
    }
  }
}

final statsRepositoryProvider = Provider<StatsRepository>(
  (ref) => StatsRepository(api: ref.watch(apiClientProvider)),
);
