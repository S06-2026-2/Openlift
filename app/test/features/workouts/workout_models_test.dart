// FE-03 — Modelos (fromJson/toJson, carga em kg), volume e validadores
// (limites de 1000 kg / 500 reps).

import 'package:flutter_test/flutter_test.dart';
import 'package:openlift/features/workouts/domain/exercise_model.dart';
import 'package:openlift/features/workouts/domain/set_model.dart';
import 'package:openlift/features/workouts/domain/workout_model.dart';
import 'package:openlift/features/workouts/domain/workout_validators.dart';

void main() {
  group('ExerciseModel.fromJson', () {
    test('lê grupo muscular como texto', () {
      final e = ExerciseModel.fromJson(
        {'id': 1, 'name': 'Supino reto', 'muscle_group': 'Peito'},
      );
      expect(e.muscleGroup, 'Peito');
    });

    test('lê grupo muscular como objeto', () {
      final e = ExerciseModel.fromJson({
        'id': 1,
        'name': 'Supino reto',
        'muscle_group': {'id': 4, 'name': 'Peito'},
      });
      expect(e.muscleGroup, 'Peito');
    });

    test('sem grupo cai em "Outros"', () {
      final e = ExerciseModel.fromJson({'id': 1, 'name': 'X'});
      expect(e.muscleGroup, ExerciseModel.fallbackGroup);
    });

    test('exercício sem id ou nome é inválido', () {
      expect(
        () => ExerciseModel.fromJson({'name': 'X'}),
        throwsFormatException,
      );
    });
  });

  group('SetModel', () {
    test('aceita Decimal como string (como o backend serializa)', () {
      final set = SetModel.fromJson({
        'id': 5,
        'exercise_id': 1,
        'reps': 8,
        'weight_kg': '62.50',
        'rpe': '8.5',
      });

      expect(set.weightKg, 62.5);
      expect(set.rpe, 8.5);
      expect(set.type, SetType.normal);
    });

    test('toJson envia kg, rpe nulo e tipo; não envia id', () {
      const set = SetModel(
        id: 9,
        exerciseId: 2,
        reps: 5,
        weightKg: 100,
        type: SetType.failure,
      );

      expect(set.toJson(), {
        'exercise_id': 2,
        'reps': 5,
        'weight_kg': 100.0,
        'rpe': null,
        'set_type': 'failure',
      });
    });

    test('tipo desconhecido cai em normal', () {
      expect(SetType.fromApi('qualquer-coisa'), SetType.normal);
      expect(SetType.fromApi(null), SetType.normal);
      expect(SetType.fromApi('warmup'), SetType.warmup);
    });

    test('série sem campos obrigatórios é inválida', () {
      expect(
        () => SetModel.fromJson({'exercise_id': 1, 'reps': 8}),
        throwsFormatException,
      );
    });
  });

  group('WorkoutModel', () {
    final workout = WorkoutModel(
      id: 1,
      date: DateTime(2026, 10, 13),
      sets: const [
        SetModel(
          exerciseId: 1,
          reps: 10,
          weightKg: 60,
          type: SetType.warmup,
        ),
        SetModel(exerciseId: 1, reps: 8, weightKg: 80),
        SetModel(exerciseId: 1, reps: 8, weightKg: 80, type: SetType.failure),
        SetModel(exerciseId: 2, reps: 5, weightKg: 100),
      ],
    );

    test('volume = Σ carga × reps, sem aquecimento (RN-03)', () {
      // 8*80 + 8*80 + 5*100 = 1780 (a série de aquecimento 10*60 fica de fora)
      expect(workout.volumeKg, 1780);
    });

    test('exerciseIds são distintos e na ordem de aparição', () {
      expect(workout.exerciseIds, [1, 2]);
    });

    test('toJson usa data yyyy-MM-dd', () {
      final json = WorkoutModel(date: DateTime(2026, 1, 5)).toJson();
      expect(json['date'], '2026-01-05');
      expect(json['sets'], isEmpty);
    });

    test('fromJson lê data, séries e tolera data com horário', () {
      final parsed = WorkoutModel.fromJson({
        'id': 3,
        'date': '2026-10-13T00:00:00',
        'created_at': '2026-10-13T12:30:00Z',
        'shared_event_id': null,
        'sets': [
          {'id': 1, 'exercise_id': 1, 'reps': 8, 'weight_kg': '80.00'},
        ],
      });

      expect(parsed.date, DateTime(2026, 10, 13));
      expect(parsed.sets.single.weightKg, 80);
      expect(parsed.createdAt, isNotNull);
    });

    test('treino sem data é inválido', () {
      expect(() => WorkoutModel.fromJson({'sets': []}), throwsFormatException);
    });
  });

  group('WorkoutValidators', () {
    test('repetições: 1 a 500', () {
      expect(WorkoutValidators.reps(''), 'Informe');
      expect(WorkoutValidators.reps('abc'), 'Inteiro');
      expect(WorkoutValidators.reps('0'), 'De 1 a 500');
      expect(WorkoutValidators.reps('501'), 'De 1 a 500');
      expect(WorkoutValidators.reps('1'), isNull);
      expect(WorkoutValidators.reps('500'), isNull);
    });

    test('carga: 0 a 1000 kg, aceitando vírgula', () {
      expect(WorkoutValidators.weight(''), 'Informe');
      expect(WorkoutValidators.weight('x'), 'Número');
      expect(WorkoutValidators.weight('-1'), 'De 0 a 1000');
      expect(WorkoutValidators.weight('1000.5'), 'De 0 a 1000');
      expect(WorkoutValidators.weight('1001'), 'De 0 a 1000');
      expect(WorkoutValidators.weight('1000'), isNull);
      expect(WorkoutValidators.weight('62,5'), isNull);
      expect(WorkoutValidators.weight('0'), isNull);
    });

    test('RPE é opcional e vai de 0 a 10', () {
      expect(WorkoutValidators.rpe(''), isNull);
      expect(WorkoutValidators.rpe('8,5'), isNull);
      expect(WorkoutValidators.rpe('11'), 'De 0 a 10');
      expect(WorkoutValidators.rpe('x'), 'De 0 a 10');
    });

    test('parseDecimal troca vírgula por ponto', () {
      expect(WorkoutValidators.parseDecimal('62,5'), 62.5);
      expect(WorkoutValidators.parseDecimal(' 60 '), 60);
      expect(WorkoutValidators.parseDecimal('abc'), isNull);
    });
  });
}
