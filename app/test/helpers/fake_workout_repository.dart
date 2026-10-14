// Helper de teste: WorkoutRepository em memória (sem rede).

import 'package:openlift/core/network/api_exception.dart';
import 'package:openlift/features/workouts/data/workout_repository.dart';
import 'package:openlift/features/workouts/domain/exercise_model.dart';
import 'package:openlift/features/workouts/domain/workout_model.dart';

/// Biblioteca padrão dos testes.
const ExerciseModel supino =
    ExerciseModel(id: 1, name: 'Supino reto', muscleGroup: 'Peito');
const ExerciseModel agachamento =
    ExerciseModel(id: 2, name: 'Agachamento livre', muscleGroup: 'Pernas');
const ExerciseModel remada =
    ExerciseModel(id: 3, name: 'Remada curvada', muscleGroup: 'Costas');

class FakeWorkoutRepository implements WorkoutRepository {
  FakeWorkoutRepository({
    List<WorkoutModel>? workouts,
    List<ExerciseModel>? exercises,
  })  : workouts = [...?workouts],
        exercises = exercises ?? const [supino, agachamento, remada];

  final List<WorkoutModel> workouts;
  final List<ExerciseModel> exercises;

  /// Se definidos, a operação correspondente lança o erro.
  ApiException? listError;
  ApiException? saveError;
  ApiException? exercisesError;

  // Registro do que a UI pediu.
  final List<WorkoutModel> created = [];
  final List<(int, WorkoutModel)> updated = [];
  final List<int> deleted = [];
  int listCalls = 0;
  DateTime? lastFrom;
  DateTime? lastTo;
  int? lastExerciseId;

  int _nextId = 100;

  @override
  Future<List<ExerciseModel>> fetchExercises() async {
    final error = exercisesError;
    if (error != null) throw error;
    return exercises;
  }

  @override
  Future<List<WorkoutModel>> listWorkouts({
    DateTime? from,
    DateTime? to,
    int? exerciseId,
  }) async {
    listCalls++;
    lastFrom = from;
    lastTo = to;
    lastExerciseId = exerciseId;
    final error = listError;
    if (error != null) throw error;
    return List.of(workouts);
  }

  @override
  Future<WorkoutModel> getWorkout(int id) async {
    final match = workouts.where((w) => w.id == id);
    if (match.isEmpty) {
      throw const ApiException('Não encontramos esse treino.', statusCode: 404);
    }
    return match.first;
  }

  @override
  Future<WorkoutModel> createWorkout(WorkoutModel workout) async {
    final error = saveError;
    if (error != null) throw error;
    created.add(workout);
    final saved = WorkoutModel(
      id: _nextId++,
      date: workout.date,
      sets: workout.sets,
    );
    workouts.add(saved);
    return saved;
  }

  @override
  Future<WorkoutModel> updateWorkout(int id, WorkoutModel workout) async {
    final error = saveError;
    if (error != null) throw error;
    updated.add((id, workout));
    final saved = WorkoutModel(id: id, date: workout.date, sets: workout.sets);
    final index = workouts.indexWhere((w) => w.id == id);
    if (index >= 0) workouts[index] = saved;
    return saved;
  }

  @override
  Future<void> deleteWorkout(int id) async {
    deleted.add(id);
    workouts.removeWhere((w) => w.id == id);
  }
}
