// Helper de teste: WorkoutRepository em memória (sem rede).

import 'package:openlift/core/network/api_exception.dart';
import 'package:openlift/features/workouts/data/workout_repository.dart';
import 'package:openlift/features/workouts/domain/exercise_model.dart';
import 'package:openlift/features/workouts/domain/workout_model.dart';

/// Biblioteca padrão dos testes.
const ExerciseModel supino = ExerciseModel(
  id: 1,
  name: 'Supino reto',
  muscleGroup: 'Peito',
  equipment: 'barbell',
);
const ExerciseModel agachamento = ExerciseModel(
  id: 2,
  name: 'Agachamento livre',
  muscleGroup: 'Pernas',
  equipment: 'barbell',
);
const ExerciseModel remada = ExerciseModel(
  id: 3,
  name: 'Remada curvada',
  muscleGroup: 'Costas',
  equipment: 'barbell',
);

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
  ApiException? publicationError;

  // Registro do que a UI pediu.
  final List<WorkoutModel> created = [];
  final List<(int, WorkoutModel)> updated = [];
  final List<int> deleted = [];

  /// Avisos de publicação (FE-05): o corpo de cada POST, como iria à API.
  final List<(int, Map<String, String>)> publications = [];
  final List<(int, Map<String, String>)> publicationFailures = [];
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
    final index = workouts.indexWhere((w) => w.id == id);
    // Como o backend: PATCH não mexe na publicação.
    final saved = WorkoutModel(
      id: id,
      date: workout.date,
      sets: workout.sets,
      visibility: index >= 0 ? workouts[index].visibility : workout.visibility,
      publishStatus:
          index >= 0 ? workouts[index].publishStatus : workout.publishStatus,
      dTag: index >= 0 ? workouts[index].dTag : workout.dTag,
    );
    if (index >= 0) workouts[index] = saved;
    return saved;
  }

  @override
  Future<WorkoutModel> registerPublication(
    int id, {
    required String eventId,
    required String pubkey,
    required String dTag,
  }) async {
    final error = publicationError;
    if (error != null) throw error;
    publications
        .add((id, {'event_id': eventId, 'pubkey': pubkey, 'd_tag': dTag}));
    return _setPublication(id, PublishStatus.published, dTag: dTag);
  }

  @override
  Future<WorkoutModel> registerPublicationFailure(
    int id, {
    required String eventId,
    required String pubkey,
  }) async {
    final error = publicationError;
    if (error != null) throw error;
    publicationFailures.add((id, {'event_id': eventId, 'pubkey': pubkey}));
    return _setPublication(id, PublishStatus.failed);
  }

  WorkoutModel _setPublication(int id, PublishStatus status, {String? dTag}) {
    final index = workouts.indexWhere((w) => w.id == id);
    final current = workouts[index];
    final saved = WorkoutModel(
      id: id,
      date: current.date,
      sets: current.sets,
      visibility: status == PublishStatus.published
          ? WorkoutVisibility.published
          : current.visibility,
      publishStatus: status,
      dTag: dTag ?? current.dTag,
    );
    workouts[index] = saved;
    return saved;
  }

  @override
  Future<void> deleteWorkout(int id) async {
    deleted.add(id);
    workouts.removeWhere((w) => w.id == id);
  }
}
