// Helper de teste: StatsRepository em memória (sem rede). Sem dados
// definidos, responde tudo zerado (usuário sem treinos).

import 'package:openlift/core/network/api_exception.dart';
import 'package:openlift/features/dashboard/data/stats_repository.dart';
import 'package:openlift/features/dashboard/domain/stats_model.dart';

class FakeStatsRepository implements StatsRepository {
  FakeStatsRepository({
    this.volume,
    this.monthly,
    this.muscleGroups = const [],
    this.heatmap,
  });

  /// Volume por semana (e o resumo: treinos no mês, sequência).
  VolumeStats? volume;

  /// Volume por mês.
  VolumeStats? monthly;
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
  Future<VolumeStats> getVolume({
    required DateTime until,
    StatsScale scale = StatsScale.week,
    int periods = 8,
  }) =>
      _answer(
        'volume ${scale.name} periods=$periods '
        'until=${until.toIso8601String()}',
        () => scale == StatsScale.month
            ? monthly ?? const VolumeStats.empty(StatsScale.month)
            : volume ?? const VolumeStats.empty(),
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
