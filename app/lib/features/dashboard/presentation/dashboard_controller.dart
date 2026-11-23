// Controller do dashboard: carrega volume semanal e mensal, grupos
// musculares e mapa de calor em paralelo.
//
// Janelas: volume das últimas [volumeWeeks] semanas e [volumeMonths] meses;
// mapa de calor dos últimos [heatmapMonths] meses (a visão por semana usa as
// últimas [heatmapWeeks]); frequência por grupo nos últimos [frequencyDays]
// dias. Tudo termina hoje (data do aparelho).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/stats_repository.dart';
import '../domain/stats_model.dart';

/// "Hoje" do dashboard. Override nos testes para fixar a data.
final dashboardTodayProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

class DashboardController extends AutoDisposeAsyncNotifier<DashboardData> {
  static const int volumeWeeks = 8;
  static const int volumeMonths = 6;
  static const int heatmapWeeks = 8;
  static const int heatmapMonths = 6;
  static const int frequencyDays = 28;

  @override
  Future<DashboardData> build() => _load();

  Future<DashboardData> _load() async {
    final now = ref.read(dashboardTodayProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final repository = ref.read(statsRepositoryProvider);

    // Dia 1 do mês mais antigo: cobre os meses e, com folga, as 8 semanas.
    final heatmapFrom = DateTime(today.year, today.month - (heatmapMonths - 1));
    final frequencyFrom =
        today.subtract(const Duration(days: frequencyDays - 1));

    // Future.wait: a primeira falha vira o erro da tela e as outras não
    // ficam soltas como erro não tratado.
    final results = await Future.wait<Object>([
      repository.getVolume(until: today, periods: volumeWeeks),
      repository.getVolume(
        until: today,
        scale: StatsScale.month,
        periods: volumeMonths,
      ),
      repository.getMuscleGroups(from: frequencyFrom, to: today),
      repository.getHeatmap(from: heatmapFrom, to: today),
    ]);

    return DashboardData(
      weekly: results[0] as VolumeStats,
      monthly: results[1] as VolumeStats,
      muscleGroups: results[2] as List<MuscleGroupStats>,
      heatmap: results[3] as HeatmapData,
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
