// Helper de teste: StatsRepository em memória (sem rede). Sem dados
// definidos, responde tudo zerado (usuário sem treinos).

import 'package:openlift/core/network/api_exception.dart';
import 'package:openlift/features/dashboard/data/stats_repository.dart';
import 'package:openlift/features/dashboard/domain/stats_model.dart';

class FakeStatsRepository implements StatsRepository {
  FakeStatsRepository({
    this.volume,
    this.muscleGroups = const [],
    this.heatmap,
  });

  VolumeStats? volume;
  List<MuscleGroupStats> muscleGroups;
  HeatmapData? heatmap;

  /// Se definido, toda chamada falha com ele.
  ApiException? error;

  /// Parâmetros de cada chamada, para conferir as janelas de data.
  final List<String> calls = [];

  Future<T> _answer<T>(String call, T Function() value) async {
    calls.add(call);
    final failure = error;
    if (failure != null) throw failure;
    return value();
  }

  @override
  Future<VolumeStats> getVolume({required DateTime until, int weeks = 8}) =>
      _answer(
        'volume weeks=$weeks until=${until.toIso8601String()}',
        () =>
            volume ??
            const VolumeStats(weeks: [], totalVolume: 0, totalWorkouts: 0),
      );

  @override
  Future<List<MuscleGroupStats>> getMuscleGroups({
    required DateTime from,
    required DateTime to,
  }) =>
      _answer(
        'groups from=${from.toIso8601String()} to=${to.toIso8601String()}',
        () => muscleGroups,
      );

  @override
  Future<HeatmapData> getHeatmap({
    required DateTime from,
    required DateTime to,
  }) =>
      _answer(
        'heatmap from=${from.toIso8601String()} to=${to.toIso8601String()}',
        () =>
            heatmap ??
            HeatmapData(from: from, to: to, groups: const {}, cells: const []),
      );
}
