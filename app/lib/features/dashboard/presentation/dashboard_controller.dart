// Controller do dashboard: carrega volume semanal, grupos musculares e mapa
// de calor em paralelo.
//
// Janelas: volume das últimas [volumeWeeks] semanas; mapa de calor das
// últimas [heatmapWeeks] semanas; frequência por grupo nos últimos
// [frequencyDays] dias. Tudo termina hoje (data do aparelho).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/stats_repository.dart';
import '../domain/stats_model.dart';

/// "Hoje" do dashboard. Override nos testes para fixar a data.
final dashboardTodayProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

class DashboardController extends AutoDisposeAsyncNotifier<DashboardData> {
  static const int volumeWeeks = 8;
  static const int heatmapWeeks = 8;
  static const int frequencyDays = 28;

  @override
  Future<DashboardData> build() => _load();

  Future<DashboardData> _load() async {
    final now = ref.read(dashboardTodayProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final repository = ref.read(statsRepositoryProvider);

    final heatmapFrom = weekStartOf(today)
        .subtract(const Duration(days: 7 * (heatmapWeeks - 1)));
    final frequencyFrom =
        today.subtract(const Duration(days: frequencyDays - 1));

    // Future.wait: a primeira falha vira o erro da tela e as outras não
    // ficam soltas como erro não tratado.
    final results = await Future.wait<Object>([
      repository.getVolume(until: today, weeks: volumeWeeks),
      repository.getMuscleGroups(from: frequencyFrom, to: today),
      repository.getHeatmap(from: heatmapFrom, to: today),
    ]);

    return DashboardData(
      volume: results[0] as VolumeStats,
      muscleGroups: results[1] as List<MuscleGroupStats>,
      heatmap: results[2] as HeatmapData,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading<DashboardData>().copyWithPrevious(state);
    state = await AsyncValue.guard(_load);
  }
}

final dashboardProvider =
    AsyncNotifierProvider.autoDispose<DashboardController, DashboardData>(
  DashboardController.new,
);
