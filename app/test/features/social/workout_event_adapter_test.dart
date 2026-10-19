// NOSTR-03 — Adapter treino ⇄ evento (mini-NIP, ADR-0003).
//
// O contrato é o de docs/nips/: o teste lê os schemas e os exemplos assinados
// de lá, então qualquer divergência entre o app e o documento quebra aqui.
// Nenhuma chave privada no repositório: os eventos novos são assinados com
// chave gerada na hora (RNF-01).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema/json_schema.dart';
import 'package:openlift/core/nostr/nostr_event.dart';
import 'package:openlift/core/nostr/nostr_kinds.dart';
import 'package:openlift/core/nostr/nostr_signer.dart';
import 'package:openlift/features/social/domain/workout_event_adapter.dart';
import 'package:openlift/features/workouts/domain/exercise_model.dart';
import 'package:openlift/features/workouts/domain/set_model.dart';
import 'package:openlift/features/workouts/domain/workout_model.dart';

dynamic _docs(String path) =>
    jsonDecode(File('../docs/nips/$path').readAsStringSync());

JsonSchema _schema(String name) => JsonSchema.create(_docs(name));

const _bench = ExerciseModel(id: 1, name: 'Supino reto', muscleGroup: 'Peito');
const _squat = ExerciseModel(
  id: 2,
  name: 'Agachamento livre',
  muscleGroup: 'Quadríceps',
);
const _library = {1: _bench, 2: _squat};
const _adapter = WorkoutEventAdapter(relayHint: 'wss://nos.lol');

/// O treino de docs/nips/examples/workout-record.json.
final _exampleWorkout = WorkoutModel(
  date: DateTime(2026, 10, 19),
  sets: const [
    SetModel(exerciseId: 1, reps: 12, weightKg: 40, type: SetType.warmup),
    SetModel(exerciseId: 1, reps: 8, weightKg: 80, rpe: 7),
    SetModel(exerciseId: 1, reps: 8, weightKg: 80, rpe: 8.5),
    SetModel(
        exerciseId: 1, reps: 6, weightKg: 80, rpe: 10, type: SetType.failure),
    SetModel(exerciseId: 2, reps: 5, weightKg: 100, rpe: 8),
    SetModel(exerciseId: 2, reps: 5, weightKg: 102.5),
  ],
);

int _noonLocal(DateTime date) =>
    DateTime(date.year, date.month, date.day, 12).millisecondsSinceEpoch ~/
    1000;

UnsignedNostrEvent _record(
  WorkoutModel workout, {
  String pubkey =
      '3361fd648012d81dfb176fd52b6c0f6dd9c5979b3bf40beaa30a9dae199a7f6a',
  String d = '9d1f55ca-6a25-4d69-a04f-54fc5d026679',
}) =>
    _adapter.workoutRecord(
      pubkey: pubkey,
      createdAt: 1792447800,
      d: d,
      workout: workout,
      exercises: _library,
    );

/// Evento "de terceiro" com tags arbitrárias, assinado na hora.
NostrEvent _thirdParty(
  NostrSigner signer,
  List<List<String>> tags, {
  int createdAt = 1792447800,
  int kind = NostrKinds.workoutRecord,
}) =>
    signer.sign(UnsignedNostrEvent(
      pubkey: signer.publicKey,
      createdAt: createdAt,
      kind: kind,
      tags: tags,
      content: '',
    ));

List<String> _set(NostrSigner signer, String kg, String reps,
        [String? rpe, String? type]) =>
    [
      'exercise',
      '33401:${signer.publicKey}:9c086100-ba50-5108-bda5-98ea2d1d63c8',
      '',
      kg,
      reps,
      if (rpe != null) rpe,
      if (type != null) type,
    ];

void main() {
  group('identificador do exercício (mini-NIP §3)', () {
    test('slug tira acento, símbolo e espaço', () {
      expect(WorkoutEventAdapter.exerciseSlug('Supino reto'), 'supino-reto');
      expect(WorkoutEventAdapter.exerciseSlug('Leg press 45°'), 'leg-press-45');
      expect(WorkoutEventAdapter.exerciseSlug('Glúteo na polia'),
          'gluteo-na-polia');
      expect(
          WorkoutEventAdapter.exerciseSlug('  Rosca  Scott! '), 'rosca-scott');
    });

    test('d bate com os vetores de teste do mini-NIP', () {
      expect(WorkoutEventAdapter.exerciseTemplateD('Supino reto'),
          '9c086100-ba50-5108-bda5-98ea2d1d63c8');
      expect(WorkoutEventAdapter.exerciseTemplateD('Agachamento livre'),
          '06328c6a-abb8-516d-9631-2c2870f0b4d3');
    });

    test('d do treino é UUID v4 novo a cada chamada', () {
      final a = WorkoutEventAdapter.newRecordD();
      final b = WorkoutEventAdapter.newRecordD();
      final v4 = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

      expect(a, matches(v4));
      expect(a, isNot(b));
    });
  });

  group('kind 33401 — modelo de exercício', () {
    test('gera exatamente o evento de exemplo (mesmo id)', () {
      final examples = (_docs('examples/exercise-templates.json') as List)
          .cast<Map<String, dynamic>>();
      final pairs = [(_bench, examples[0]), (_squat, examples[1])];

      for (final (exercise, example) in pairs) {
        final event = _adapter.exerciseTemplate(
          pubkey: example['pubkey'] as String,
          createdAt: example['created_at'] as int,
          exercise: exercise,
          equipment: ExerciseEquipment.barbell,
        );

        expect(event.kind, NostrKinds.exerciseTemplate);
        expect(event.tags, example['tags']);
        expect(event.computeId(), example['id'], reason: exercise.name);
      }
    });

    test('grupo fora do vocabulário não gera tag t', () {
      final event = _adapter.exerciseTemplate(
        pubkey: '0' * 64,
        createdAt: 1,
        exercise:
            const ExerciseModel(id: 9, name: 'Burpee', muscleGroup: 'Outros'),
        equipment: ExerciseEquipment.bodyweight,
      );

      expect(event.tags.where((t) => t.first == 't'), isEmpty);
    });

    test('contrato: assinado, valida contra exercise-template.schema.json', () {
      final signer = NostrSigner.generate();
      final event = signer.sign(_adapter.exerciseTemplate(
        pubkey: signer.publicKey,
        createdAt: 1792447800,
        exercise: _bench,
        equipment: ExerciseEquipment.barbell,
      ));

      final result =
          _schema('exercise-template.schema.json').validate(event.toJson());
      expect(result.isValid, isTrue, reason: result.errors.join('\n'));
    });
  });

  group('kind 1301 — escrita', () {
    test('gera as tags do exemplo do mini-NIP', () {
      final example = _docs('examples/workout-record.json') as Map;
      final start = '${_noonLocal(DateTime(2026, 10, 19))}';
      final expected = [
        for (final tag in (example['tags'] as List).cast<List>())
          if (tag.first == 'start' || tag.first == 'end')
            [tag.first, start]
          else
            tag,
      ];

      final event = _record(_exampleWorkout);

      expect(event.kind, NostrKinds.workoutRecord);
      expect(event.content, '');
      expect(event.tags, expected);
    });

    test('contrato: assinado, valida contra workout-event.schema.json', () {
      final signer = NostrSigner.generate();
      final event = signer.sign(_record(
        _exampleWorkout,
        pubkey: signer.publicKey,
        d: WorkoutEventAdapter.newRecordD(),
      ));

      final result =
          _schema('workout-event.schema.json').validate(event.toJson());
      expect(result.isValid, isTrue, reason: result.errors.join('\n'));
      expect(event.isValid, isTrue);
    });

    test('start = end = 12:00 local do dia do treino', () {
      final event = _record(_exampleWorkout);
      final noon = '${_noonLocal(DateTime(2026, 10, 19))}';

      expect(event.tags, anyElement(equals(['start', noon])));
      expect(event.tags, anyElement(equals(['end', noon])));
    });

    test('números canônicos: sem zero à direita, arredondados', () {
      final workout = WorkoutModel(date: DateTime(2026, 10, 19), sets: const [
        SetModel(exerciseId: 1, reps: 10, weightKg: 80.0, rpe: 8.0),
        SetModel(exerciseId: 1, reps: 10, weightKg: 82.50, rpe: 9.5),
        SetModel(exerciseId: 1, reps: 10, weightKg: 0.1 + 0.2),
        SetModel(exerciseId: 1, reps: 10, weightKg: 0),
        SetModel(exerciseId: 1, reps: 10, weightKg: 1000),
      ]);

      final sets = _record(workout)
          .tags
          .where((t) => t.first == 'exercise')
          .map((t) => [t[3], t[5]])
          .toList();

      expect(sets, [
        ['80', '8'],
        ['82.5', '9.5'],
        ['0.3', ''],
        ['0', ''],
        ['1000', ''],
      ]);
    });

    test('alt: resumo humano com volume do RN-03 e singular', () {
      final workout = WorkoutModel(date: DateTime(2026, 1, 5), sets: const [
        SetModel(exerciseId: 2, reps: 5, weightKg: 100),
      ]);

      expect(
        _record(workout).tags.last,
        [
          'alt',
          'Registro de treino de 05/01/2026: Agachamento livre (1 série). '
              'Volume: 500 kg.',
        ],
      );
    });

    test('só tags do mini-NIP: nada de localização ou dado pessoal', () {
      final names = _record(_exampleWorkout).tags.map((t) => t.first).toSet();

      expect(names, {
        'd',
        'title',
        'type',
        'start',
        'end',
        'completed',
        'exercise',
        'alt',
      });
    });

    test('RN-01: treino sem série não vira evento', () {
      expect(
        () => _record(WorkoutModel(date: DateTime(2026, 10, 19))),
        throwsA(isA<WorkoutEventException>()
            .having((e) => e.message, 'mensagem', contains('série'))),
      );
    });

    test('RN-07 e RPE fora do intervalo são recusados com mensagem humana', () {
      for (final set in const [
        SetModel(exerciseId: 1, reps: 10, weightKg: 1000.5),
        SetModel(exerciseId: 1, reps: 10, weightKg: -1),
        SetModel(exerciseId: 1, reps: 0, weightKg: 80),
        SetModel(exerciseId: 1, reps: 501, weightKg: 80),
        SetModel(exerciseId: 1, reps: 10, weightKg: 80, rpe: 0),
        SetModel(exerciseId: 1, reps: 10, weightKg: 80, rpe: 10.5),
      ]) {
        final workout = WorkoutModel(date: DateTime(2026, 10, 19), sets: [set]);
        expect(() => _record(workout), throwsA(isA<WorkoutEventException>()),
            reason: set.toJson().toString());
      }
    });

    test('exercício fora da biblioteca é recusado', () {
      final workout = WorkoutModel(date: DateTime(2026, 10, 19), sets: const [
        SetModel(exerciseId: 99, reps: 10, weightKg: 80),
      ]);

      expect(() => _record(workout), throwsA(isA<WorkoutEventException>()));
    });
  });

  group('kind 1301 — leitura (mini-NIP §5)', () {
    final example = NostrEvent.fromJson(
        _docs('examples/workout-record.json') as Map<String, dynamic>);
    final titles = WorkoutEventAdapter.exerciseTitles([
      for (final json in _docs('examples/exercise-templates.json') as List)
        NostrEvent.fromJson(json as Map<String, dynamic>),
    ]);

    test('lê o exemplo: exercícios, séries, data e volume (RN-03)', () {
      final workout = WorkoutEventAdapter.parseWorkoutRecord(example,
          exerciseTitles: titles)!;

      expect(workout.eventId, example.id);
      expect(workout.d, '9d1f55ca-6a25-4d69-a04f-54fc5d026679');
      expect(workout.title, 'Treino de 19/10/2026');
      expect(workout.date, DateTime(2026, 10, 19));
      expect(workout.sets, hasLength(6));
      expect(workout.exerciseNames, ['Supino reto', 'Agachamento livre']);
      expect(workout.sets.first.type, SetType.warmup);
      expect(workout.sets[2].rpe, 8.5);
      expect(workout.sets.last.rpe, isNull);
      expect(workout.volumeKg, 2772.5);
      expect(workout.isPlausible, isTrue);
    });

    test('modelo de exercício adulterado não dá nome', () {
      final json = _docs('examples/exercise-templates.json') as List;
      final forged = Map<String, dynamic>.from(json.first as Map)
        ..['tags'] = [
          ['d', '9c086100-ba50-5108-bda5-98ea2d1d63c8'],
          ['title', 'Nome falso'],
        ];

      expect(WorkoutEventAdapter.exerciseTitles([NostrEvent.fromJson(forged)]),
          isEmpty);
    });

    test('referência sem modelo vira "Exercício desconhecido"', () {
      final workout = WorkoutEventAdapter.parseWorkoutRecord(example)!;

      expect(workout.exerciseNames,
          ['Exercício desconhecido', 'Exercício desconhecido']);
      expect(workout.volumeKg, 2772.5);
    });

    test('assinatura inválida ou kind errado: descarta (RF-51)', () {
      final json = example.toJson()..['content'] = 'adulterado';
      final signer = NostrSigner.generate();

      expect(WorkoutEventAdapter.parseWorkoutRecord(NostrEvent.fromJson(json)),
          isNull);
      expect(
        WorkoutEventAdapter.parseWorkoutRecord(_thirdParty(
            signer, [_set(signer, '80', '8', '7', 'normal')],
            kind: 1)),
        isNull,
      );
    });

    test('tolerante com eventos de terceiros', () {
      final signer = NostrSigner.generate();
      final event = _thirdParty(
          signer,
          [
            _set(signer, '', '10'), // peso corporal, sem rpe nem tipo
            _set(signer, '-20', '8', '', 'normal'), // assistido
            _set(signer, '60', '10', 'abc', 'drop'), // drop conta; rpe inválido
            _set(signer, '50', '10', '7', 'superset'), // tipo desconhecido
            ['exercise', 'x', '', '80'], // curta demais: ignora
            _set(signer, '80', 'x'), // reps inválido: ignora
          ],
          createdAt: 1792447800);

      final workout = WorkoutEventAdapter.parseWorkoutRecord(event)!;

      expect(workout.sets.map((s) => s.weightKg), [0, -20, 60, 50]);
      expect(workout.sets.map((s) => s.type), everyElement(SetType.normal));
      expect(workout.sets[2].rpe, isNull);
      expect(workout.volumeKg, 600 + 500); // assistido conta 0
      expect(workout.title, isNull);
      expect(
        workout.date,
        DateUtils.dateOnly(
            DateTime.fromMillisecondsSinceEpoch(1792447800 * 1000)),
      );
    });

    test('sem nenhuma série válida: descarta', () {
      final signer = NostrSigner.generate();

      expect(
        WorkoutEventAdapter.parseWorkoutRecord(
            _thirdParty(signer, [_set(signer, '80', '0')])),
        isNull,
      );
    });

    test('série fora do RN-07 exibe, mas marca como implausível', () {
      final signer = NostrSigner.generate();
      final workout = WorkoutEventAdapter.parseWorkoutRecord(
          _thirdParty(signer, [_set(signer, '1200', '5', '10', 'normal')]))!;

      expect(workout.sets, hasLength(1));
      expect(workout.isPlausible, isFalse);
    });
  });

  group('latestVersions (RF-24, RN-08)', () {
    test('deduplica por id, mantém a versão mais nova por (pubkey, d)', () {
      final a = NostrSigner.generate();
      final b = NostrSigner.generate();
      List<List<String>> tags(NostrSigner s, String d, String kg) => [
            ['d', d],
            _set(s, kg, '5', '8', 'normal'),
          ];
      final v1 = _thirdParty(a, tags(a, 'treino-1', '80'), createdAt: 100);
      final v2 = _thirdParty(a, tags(a, 'treino-1', '90'), createdAt: 200);
      final other = _thirdParty(a, tags(a, 'treino-2', '70'), createdAt: 150);
      final sameDOtherAuthor =
          _thirdParty(b, tags(b, 'treino-1', '60'), createdAt: 50);
      final forged = NostrEvent.fromJson(
          _thirdParty(a, tags(a, 'treino-3', '50'), createdAt: 300).toJson()
            ..['content'] = 'adulterado');

      final latest = WorkoutEventAdapter.latestVersions(
          [v1, v2, v2, other, sameDOtherAuthor, forged, v1]);

      expect(
          latest.map((w) => w.eventId), [v2.id, other.id, sameDOtherAuthor.id]);
    });
  });
}
