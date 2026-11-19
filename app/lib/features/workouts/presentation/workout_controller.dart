// FE-03 — Estado do histórico de treinos (Riverpod).
//
// - [WorkoutFilter]/[workoutFilterProvider]: filtro por data e exercício;
// - [WorkoutController]: lista (loading/error/data) + criar/editar/excluir,
//   em páginas: a 1ª vem no build e [WorkoutController.loadMore] busca as
//   seguintes (FE-09);
// - [exerciseLibraryProvider]: biblioteca de exercícios (BE-03);
// - [workoutByIdProvider]: um treino para a tela de edição.
//
// O filtro é enviado ao servidor (query params) e reaplicado no cliente, para
// continuar correto mesmo se a API ainda ignorar algum parâmetro.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/workout_repository.dart';
import '../domain/exercise_model.dart';
import '../domain/workout_model.dart';

@immutable
class WorkoutFilter {
  const WorkoutFilter({this.from, this.to, this.exerciseId});

  final DateTime? from;
  final DateTime? to;
  final int? exerciseId;

  bool get isActive => from != null || to != null || exerciseId != null;

  WorkoutFilter copyWith({
    DateTime? from,
    DateTime? to,
    int? exerciseId,
    bool clearDates = false,
    bool clearExercise = false,
  }) {
    return WorkoutFilter(
      from: clearDates ? null : (from ?? this.from),
      to: clearDates ? null : (to ?? this.to),
      exerciseId: clearExercise ? null : (exerciseId ?? this.exerciseId),
    );
  }

  /// O treino passa pelo filtro? (datas inclusivas, só dia/mês/ano)
  bool matches(WorkoutModel workout) {
    final day = DateUtils.dateOnly(workout.date);
    if (from != null && day.isBefore(DateUtils.dateOnly(from!))) return false;
    if (to != null && day.isAfter(DateUtils.dateOnly(to!))) return false;
    if (exerciseId != null &&
        !workout.sets.any((s) => s.exerciseId == exerciseId)) {
      return false;
    }
    return true;
  }
}

class WorkoutFilterNotifier extends Notifier<WorkoutFilter> {
  @override
  WorkoutFilter build() => const WorkoutFilter();

  void set(WorkoutFilter filter) => state = filter;

  void clear() => state = const WorkoutFilter();
}

final workoutFilterProvider =
    NotifierProvider<WorkoutFilterNotifier, WorkoutFilter>(
  WorkoutFilterNotifier.new,
);

class WorkoutController extends AsyncNotifier<List<WorkoutModel>> {
  /// Total no servidor para o filtro atual e quantos já foram pedidos.
  int _total = 0;
  int _fetched = 0;
  bool _loadingMore = false;

  /// Há treinos em páginas que ainda não foram carregadas?
  bool get hasMore => _fetched < _total;

  /// Total de treinos do filtro, contando as páginas não carregadas.
  int get total => _total;

  @override
  Future<List<WorkoutModel>> build() async {
    final filter = ref.watch(workoutFilterProvider);
    ref.watch(workoutRepositoryProvider);
    final page = await _fetch(filter, offset: 0);
    _total = page.total;
    _fetched = page.items.length;
    return _newestFirst(page.items.where(filter.matches).toList());
  }

  /// Busca a próxima página e junta ao fim da lista. Lança ApiException se
  /// a API falhar; a lista já carregada continua na tela.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !hasMore || _loadingMore) return;
    _loadingMore = true;
    try {
      final filter = ref.read(workoutFilterProvider);
      final page = await _fetch(filter, offset: _fetched);
      _total = page.total;
      _fetched += page.items.length;
      // Treino que entrou nas duas páginas (lista mudou no meio) vale uma vez.
      final known = {for (final w in current) w.id};
      state = AsyncData([
        ...current,
        ..._newestFirst([
          for (final w in page.items)
            if (filter.matches(w) && !known.contains(w.id)) w,
        ]),
      ]);
    } finally {
      _loadingMore = false;
    }
  }

  Future<WorkoutPage> _fetch(WorkoutFilter filter, {required int offset}) =>
      ref.read(workoutRepositoryProvider).listWorkouts(
            from: filter.from,
            to: filter.to,
            exerciseId: filter.exerciseId,
            offset: offset,
          );

  /// Devolve o treino salvo (com id), para a publicação logo em seguida.
  Future<WorkoutModel> create(WorkoutModel workout) async {
    final saved =
        await ref.read(workoutRepositoryProvider).createWorkout(workout);
    ref.invalidateSelf();
    return saved;
  }

  Future<WorkoutModel> edit(int id, WorkoutModel workout) async {
    final saved =
        await ref.read(workoutRepositoryProvider).updateWorkout(id, workout);
    ref.invalidate(workoutByIdProvider(id));
    ref.invalidateSelf();
    return saved;
  }

  /// Exclui e some com o treino da lista na hora (sem novo GET).
  Future<void> remove(int id) async {
    await ref.read(workoutRepositoryProvider).deleteWorkout(id);
    final current = state.valueOrNull;
    if (current != null) {
      // O próximo offset também anda uma casa para trás.
      _total--;
      _fetched--;
      state = AsyncData([
        for (final workout in current)
          if (workout.id != id) workout,
      ]);
    }
    ref.invalidate(workoutByIdProvider(id));
  }

  List<WorkoutModel> _newestFirst(List<WorkoutModel> items) {
    return items
      ..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        return byDate != 0 ? byDate : (b.id ?? 0).compareTo(a.id ?? 0);
      });
  }
}

final workoutControllerProvider =
    AsyncNotifierProvider<WorkoutController, List<WorkoutModel>>(
  WorkoutController.new,
);

/// Biblioteca de exercícios (BE-03), agrupada por grupo muscular na UI.
final exerciseLibraryProvider = FutureProvider<List<ExerciseModel>>(
  (ref) => ref.watch(workoutRepositoryProvider).fetchExercises(),
);

/// Um treino específico (tela de edição).
final workoutByIdProvider =
    FutureProvider.autoDispose.family<WorkoutModel, int>(
  (ref, id) => ref.watch(workoutRepositoryProvider).getWorkout(id),
);
