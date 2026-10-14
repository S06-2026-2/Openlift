// FE-03 — Chamadas de CRUD de treino e biblioteca de exercícios à API.
//
// Contrato esperado do backend (BE-03/BE-04), base /api/v1:
//   GET    /exercises                              -> [ExerciseOut]
//   GET    /workouts?date_from&date_to&exercise_id -> [WorkoutOut] (ou {items: [...]})
//   GET    /workouts/{id}                          -> WorkoutOut
//   POST   /workouts        {date, sets: [...]}    -> WorkoutOut
//   PATCH  /workouts/{id}   {date, sets: [...]}    -> WorkoutOut (substitui as séries)
//   DELETE /workouts/{id}                          -> 204
//
// Toda falha vira ApiException com mensagem humana (nunca stack trace).

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/exercise_model.dart';
import '../domain/workout_model.dart';

class WorkoutRepository {
  WorkoutRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  static const Map<int, String> _workoutErrors = {
    404: 'Não encontramos esse treino. Ele pode ter sido excluído.',
    422: 'O servidor recusou alguns dados. Confira repetições (até 500) '
        'e carga (até 1000 kg).',
  };

  Future<List<ExerciseModel>> fetchExercises() {
    return _guard(() async {
      final response = await _api.dio.get<dynamic>('/exercises');
      return [
        for (final item in _asList(response.data))
          ExerciseModel.fromJson(item as Map<String, dynamic>),
      ];
    });
  }

  Future<List<WorkoutModel>> listWorkouts({
    DateTime? from,
    DateTime? to,
    int? exerciseId,
  }) {
    return _guard(() async {
      final response = await _api.dio.get<dynamic>(
        '/workouts',
        queryParameters: {
          if (from != null) 'date_from': toApiDate(from),
          if (to != null) 'date_to': toApiDate(to),
          if (exerciseId != null) 'exercise_id': exerciseId,
        },
      );
      return [
        for (final item in _asList(response.data))
          WorkoutModel.fromJson(item as Map<String, dynamic>),
      ];
    });
  }

  Future<WorkoutModel> getWorkout(int id) {
    return _guard(() async {
      final response = await _api.dio.get<Map<String, dynamic>>('/workouts/$id');
      return WorkoutModel.fromJson(response.data!);
    });
  }

  Future<WorkoutModel> createWorkout(WorkoutModel workout) {
    return _guard(() async {
      final response = await _api.dio.post<Map<String, dynamic>>(
        '/workouts',
        data: workout.toJson(),
      );
      return WorkoutModel.fromJson(response.data!);
    });
  }

  Future<WorkoutModel> updateWorkout(int id, WorkoutModel workout) {
    return _guard(() async {
      final response = await _api.dio.patch<Map<String, dynamic>>(
        '/workouts/$id',
        data: workout.toJson(),
      );
      return WorkoutModel.fromJson(response.data!);
    });
  }

  Future<void> deleteWorkout(int id) {
    return _guard(() async {
      await _api.dio.delete<dynamic>('/workouts/$id');
    });
  }

  /// Aceita lista crua ou envelope `{items: [...]}`.
  List<dynamic> _asList(Object? data) {
    if (data is List) return data;
    if (data is Map && data['items'] is List) return data['items'] as List;
    throw const FormatException('Lista esperada');
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw ApiException.fromDio(e, overrides: _workoutErrors);
    } on ApiException {
      rethrow;
    } on Object {
      // Resposta fora do contrato (campo faltando, tipo errado...).
      throw const ApiException('Resposta inesperada do servidor.');
    }
  }
}

final workoutRepositoryProvider = Provider<WorkoutRepository>(
  (ref) => WorkoutRepository(api: ref.watch(apiClientProvider)),
);
