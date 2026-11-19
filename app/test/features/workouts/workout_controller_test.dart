// FE-03 — WorkoutController (repositório em memória): ordenação, filtro,
// criar/editar/excluir e erros.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlift/core/network/api_exception.dart';
import 'package:openlift/features/workouts/data/workout_repository.dart';
import 'package:openlift/features/workouts/domain/set_model.dart';
import 'package:openlift/features/workouts/domain/workout_model.dart';
import 'package:openlift/features/workouts/presentation/workout_controller.dart';

import '../../helpers/fake_workout_repository.dart';

WorkoutModel _workout(int id, DateTime date, {int exerciseId = 1}) {
  return WorkoutModel(
    id: id,
    date: date,
    sets: [SetModel(exerciseId: exerciseId, reps: 8, weightKg: 80)],
  );
}

ProviderContainer _container(FakeWorkoutRepository repository) {
  final container = ProviderContainer(
    overrides: [workoutRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('lista do mais novo para o mais antigo', () async {
    final repository = FakeWorkoutRepository(workouts: [
      _workout(1, DateTime(2026, 10, 1)),
      _workout(2, DateTime(2026, 10, 13)),
      _workout(3, DateTime(2026, 10, 7)),
    ]);
    final container = _container(repository);

    final items = await container.read(workoutControllerProvider.future);

    expect(items.map((w) => w.id), [2, 3, 1]);
  });

  test('filtro por exercício e período é enviado e reaplicado no cliente',
      () async {
    final repository = FakeWorkoutRepository(workouts: [
      _workout(1, DateTime(2026, 10, 1), exerciseId: 1),
      _workout(2, DateTime(2026, 10, 13), exerciseId: 2),
      _workout(3, DateTime(2026, 10, 20), exerciseId: 2),
    ]);
    final container = _container(repository);
    await container.read(workoutControllerProvider.future);

    container.read(workoutFilterProvider.notifier).set(
          WorkoutFilter(
            from: DateTime(2026, 10, 10),
            to: DateTime(2026, 10, 15),
            exerciseId: 2,
          ),
        );
    final items = await container.read(workoutControllerProvider.future);

    // O fake ignora os parâmetros (como uma API sem filtro), então quem
    // garante o resultado correto é o filtro do cliente.
    expect(items.map((w) => w.id), [2]);
    expect(repository.lastExerciseId, 2);
    expect(repository.lastFrom, DateTime(2026, 10, 10));
    expect(repository.lastTo, DateTime(2026, 10, 15));
  });

  test('WorkoutFilter.matches inclui as datas das pontas', () {
    final filter = WorkoutFilter(
      from: DateTime(2026, 10, 10),
      to: DateTime(2026, 10, 12),
    );

    expect(filter.matches(_workout(1, DateTime(2026, 10, 10))), isTrue);
    expect(filter.matches(_workout(2, DateTime(2026, 10, 12))), isTrue);
    expect(filter.matches(_workout(3, DateTime(2026, 10, 9))), isFalse);
    expect(filter.matches(_workout(4, DateTime(2026, 10, 13))), isFalse);
    expect(const WorkoutFilter().isActive, isFalse);
  });

  test('create envia ao repositório e recarrega a lista', () async {
    final repository = FakeWorkoutRepository();
    final container = _container(repository);
    expect(await container.read(workoutControllerProvider.future), isEmpty);

    await container.read(workoutControllerProvider.notifier).create(
          WorkoutModel(
            date: DateTime(2026, 10, 13),
            sets: const [SetModel(exerciseId: 1, reps: 10, weightKg: 60)],
          ),
        );
    final items = await container.read(workoutControllerProvider.future);

    expect(repository.created, hasLength(1));
    expect(items, hasLength(1));
    expect(repository.listCalls, 2);
  });

  test('edit envia o id e o treino alterado', () async {
    final repository = FakeWorkoutRepository(
      workouts: [_workout(5, DateTime(2026, 10, 13))],
    );
    final container = _container(repository);
    await container.read(workoutControllerProvider.future);

    await container.read(workoutControllerProvider.notifier).edit(
          5,
          _workout(5, DateTime(2026, 10, 14)),
        );

    expect(repository.updated.single.$1, 5);
    expect(repository.updated.single.$2.date, DateTime(2026, 10, 14));
  });

  test('remove exclui e some da lista sem novo GET', () async {
    final repository = FakeWorkoutRepository(workouts: [
      _workout(1, DateTime(2026, 10, 1)),
      _workout(2, DateTime(2026, 10, 2)),
    ]);
    final container = _container(repository);
    await container.read(workoutControllerProvider.future);

    await container.read(workoutControllerProvider.notifier).remove(1);

    expect(repository.deleted, [1]);
    expect(repository.listCalls, 1);
    final items = container.read(workoutControllerProvider).requireValue;
    expect(items.map((w) => w.id), [2]);
  });

  test('erro de listagem vira AsyncError com ApiException', () async {
    final repository = FakeWorkoutRepository()
      ..listError = const ApiException('Sem conexão.');
    final container = _container(repository);

    await expectLater(
      container.read(workoutControllerProvider.future),
      throwsA(isA<ApiException>()),
    );
  });

  test('erro de criação (422) propaga para a UI tratar', () async {
    final repository = FakeWorkoutRepository()
      ..saveError = const ApiException('Dados inválidos.', statusCode: 422);
    final container = _container(repository);
    await container.read(workoutControllerProvider.future);

    await expectLater(
      container
          .read(workoutControllerProvider.notifier)
          .create(WorkoutModel(date: DateTime(2026, 10, 13))),
      throwsA(isA<ApiException>()),
    );
  });

  group('paginação (FE-09)', () {
    /// [count] treinos, um por dia, do mais novo (id 1) para o mais antigo.
    FakeWorkoutRepository manyWorkouts(int count) => FakeWorkoutRepository(
          workouts: [
            for (var i = 1; i <= count; i++)
              _workout(i, DateTime(2026, 10, 31).subtract(Duration(days: i))),
          ],
        );

    test('a 1ª página traz só o tamanho da página e avisa que há mais',
        () async {
      final repository = manyWorkouts(WorkoutRepository.pageSize + 5);
      final container = _container(repository);

      final items = await container.read(workoutControllerProvider.future);
      final controller = container.read(workoutControllerProvider.notifier);

      expect(items, hasLength(WorkoutRepository.pageSize));
      expect(controller.hasMore, isTrue);
      expect(controller.total, WorkoutRepository.pageSize + 5);
    });

    test('loadMore junta a página seguinte ao fim da lista', () async {
      final repository = manyWorkouts(WorkoutRepository.pageSize + 5);
      final container = _container(repository);
      await container.read(workoutControllerProvider.future);
      final controller = container.read(workoutControllerProvider.notifier);

      await controller.loadMore();

      final items = container.read(workoutControllerProvider).requireValue;
      expect(items, hasLength(WorkoutRepository.pageSize + 5));
      expect(items.map((w) => w.id).toSet(), hasLength(items.length));
      expect(repository.listOffsets, [0, WorkoutRepository.pageSize]);
      expect(controller.hasMore, isFalse);
    });

    test('sem mais páginas, loadMore não chama a API', () async {
      final repository = manyWorkouts(3);
      final container = _container(repository);
      await container.read(workoutControllerProvider.future);

      await container.read(workoutControllerProvider.notifier).loadMore();

      expect(repository.listOffsets, [0]);
    });

    test('loadMore com falha mantém a lista já carregada', () async {
      final repository = manyWorkouts(WorkoutRepository.pageSize + 1)
        ..loadMoreError = const ApiException('Sem conexão.');
      final container = _container(repository);
      await container.read(workoutControllerProvider.future);
      final controller = container.read(workoutControllerProvider.notifier);

      await expectLater(controller.loadMore(), throwsA(isA<ApiException>()));

      expect(
        container.read(workoutControllerProvider).requireValue,
        hasLength(WorkoutRepository.pageSize),
      );
      expect(controller.hasMore, isTrue);
    });

    test('excluir um treino não pula nenhum na página seguinte', () async {
      final repository = manyWorkouts(WorkoutRepository.pageSize + 2);
      final container = _container(repository);
      await container.read(workoutControllerProvider.future);
      final controller = container.read(workoutControllerProvider.notifier);

      await controller.remove(1);
      repository.workouts.removeWhere((w) => w.id == 1);
      await controller.loadMore();

      final items = container.read(workoutControllerProvider).requireValue;
      expect(items, hasLength(WorkoutRepository.pageSize + 1));
      expect(controller.total, WorkoutRepository.pageSize + 1);
    });
  });
}
