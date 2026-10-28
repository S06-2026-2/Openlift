// FE-03 — WorkoutRepository contra um adapter HTTP falso: rotas, query
// params, parsing tolerante e mensagens humanas de erro (incl. 422).
// FE-05 — rotas de publicação: só dados públicos do evento no corpo.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlift/core/network/api_client.dart';
import 'package:openlift/core/network/api_exception.dart';
import 'package:openlift/features/workouts/data/workout_repository.dart';
import 'package:openlift/features/workouts/domain/set_model.dart';
import 'package:openlift/features/workouts/domain/workout_model.dart';

import '../../helpers/fake_http_adapter.dart';

void main() {
  late FakeHttpAdapter adapter;
  late ApiClient client;
  late WorkoutRepository repository;

  void build(RequestHandler handler) {
    adapter = FakeHttpAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))
      ..httpClientAdapter = adapter;
    client = ApiClient(storage: MemorySecureStorage(access: 'a'), dio: dio);
    repository = WorkoutRepository(api: client);
  }

  tearDown(() => client.dispose());

  final workoutJson = {
    'id': 7,
    'date': '2026-10-13',
    'created_at': '2026-10-13T10:00:00Z',
    'sets': [
      {'id': 1, 'exercise_id': 1, 'reps': 8, 'weight_kg': '80.00', 'rpe': null},
    ],
  };

  test('listWorkouts envia o filtro como query params', () async {
    build((_) => jsonResponse([workoutJson]));

    final result = await repository.listWorkouts(
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 31),
      exerciseId: 2,
    );

    expect(result.single.id, 7);
    final request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/workouts');
    expect(request.queryParameters, {
      'date_from': '2026-10-01',
      'date_to': '2026-10-31',
      'exercise_id': 2,
    });
  });

  test('listWorkouts aceita envelope {items: [...]}', () async {
    build((_) => jsonResponse({'items': [workoutJson]}));

    final result = await repository.listWorkouts();

    expect(result, hasLength(1));
    expect(adapter.requests.single.queryParameters, isEmpty);
  });

  test('fetchExercises lê a biblioteca', () async {
    build((_) => jsonResponse([
          {'id': 1, 'name': 'Supino reto', 'muscle_group': 'Peito'},
          {
            'id': 2,
            'name': 'Agachamento',
            'muscle_group': {'id': 9, 'name': 'Pernas'},
          },
        ]));

    final result = await repository.fetchExercises();

    expect(result.map((e) => e.muscleGroup), ['Peito', 'Pernas']);
  });

  test('createWorkout faz POST com data e séries em kg', () async {
    build((_) => jsonResponse(workoutJson, status: 201));

    await repository.createWorkout(
      WorkoutModel(
        date: DateTime(2026, 10, 13),
        sets: const [
          SetModel(exerciseId: 1, reps: 8, weightKg: 80, rpe: 8),
        ],
      ),
    );

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/workouts');
    expect(request.data, {
      'date': '2026-10-13',
      'sets': [
        {
          'exercise_id': 1,
          'reps': 8,
          'weight_kg': 80.0,
          'rpe': 8.0,
          'set_type': 'normal',
        },
      ],
    });
  });

  test('updateWorkout usa PATCH e deleteWorkout usa DELETE', () async {
    build((options) => options.method == 'DELETE'
        ? jsonResponse(null, status: 200)
        : jsonResponse(workoutJson));

    await repository.updateWorkout(7, WorkoutModel(date: DateTime(2026, 10, 13)));
    await repository.deleteWorkout(7);

    expect(adapter.count('PATCH', '/workouts/7'), 1);
    expect(adapter.count('DELETE', '/workouts/7'), 1);
  });

  test('422 vira mensagem humana citando os limites', () async {
    build((_) => jsonResponse({'detail': [{'loc': ['body']}]}, status: 422));

    await expectLater(
      repository.createWorkout(WorkoutModel(date: DateTime(2026, 10, 13))),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'status', 422)
            .having((e) => e.message, 'message', contains('1000 kg')),
      ),
    );
  });

  test('404 vira "treino não encontrado"', () async {
    build((_) => jsonResponse({'detail': 'Not found'}, status: 404));

    await expectLater(
      repository.getWorkout(99),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('Não encontramos esse treino'),
        ),
      ),
    );
  });

  test('resposta fora do contrato vira erro humano, sem vazar detalhes',
      () async {
    build((_) => jsonResponse([
          {'id': 1, 'sem': 'data'},
        ]));

    await expectLater(
      repository.listWorkouts(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Resposta inesperada do servidor.',
        ),
      ),
    );
  });

  group('publicação (FE-05)', () {
    const eventId =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const pubkey =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const dTag = '7c9e6679-7425-4f1b-9a2e-6a1f0c8d5b34';

    test('registerPublication envia event_id, pubkey e d_tag', () async {
      build((_) => jsonResponse({
            ...workoutJson,
            'visibility': 'published',
            'publish_status': 'published',
            'd_tag': dTag,
          }));

      final saved = await repository.registerPublication(
        7,
        eventId: eventId,
        pubkey: pubkey,
        dTag: dTag,
      );

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/workouts/7/publication');
      expect(request.data, {
        'event_id': eventId,
        'pubkey': pubkey,
        'd_tag': dTag,
      });
      expect(saved.publishStatus, PublishStatus.published);
      expect(saved.dTag, dTag);
    });

    test('registerPublicationFailure envia só event_id e pubkey', () async {
      build((_) => jsonResponse({...workoutJson, 'publish_status': 'failed'}));

      final saved = await repository.registerPublicationFailure(
        7,
        eventId: eventId,
        pubkey: pubkey,
      );

      final request = adapter.requests.single;
      expect(request.path, '/workouts/7/publication-failure');
      expect(request.data, {'event_id': eventId, 'pubkey': pubkey});
      expect(saved.publishStatus, PublishStatus.failed);
    });

    test('403 e 422 viram mensagens humanas de publicação', () async {
      build((_) => jsonResponse({'code': 'pubkey_mismatch'}, status: 403));
      await expectLater(
        repository.registerPublication(7,
            eventId: eventId, pubkey: pubkey, dTag: dTag),
        throwsA(isA<ApiException>().having(
            (e) => e.message, 'message', contains('identidade NOSTR'))),
      );

      client.dispose();
      build((_) => jsonResponse({'code': 'no_sets'}, status: 422));
      await expectLater(
        repository.registerPublication(7,
            eventId: eventId, pubkey: pubkey, dTag: dTag),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', contains('uma série'))),
      );
    });
  });
}
