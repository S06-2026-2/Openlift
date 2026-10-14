// FE-03 — Widget tests de histórico e formulário de treino (API em memória).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlift/core/network/api_exception.dart';
import 'package:openlift/features/auth/data/auth_repository.dart';
import 'package:openlift/features/workouts/data/workout_repository.dart';
import 'package:openlift/features/workouts/domain/set_model.dart';
import 'package:openlift/features/workouts/domain/workout_model.dart';
import 'package:openlift/main.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_workout_repository.dart';

Future<void> _pumpApp(
  WidgetTester tester,
  FakeWorkoutRepository repository,
) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider
            .overrideWithValue(FakeAuthRepository(session: true)),
        workoutRepositoryProvider.overrideWithValue(repository),
      ],
      child: const OpenLiftApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openHistory(WidgetTester tester) async {
  await tester.tap(find.text('Meus treinos'));
  await tester.pumpAndSettle();
}

Future<void> _openNewWorkout(WidgetTester tester) async {
  await tester.tap(find.text('Novo treino'));
  await tester.pumpAndSettle();
}

Future<void> _addExercise(WidgetTester tester, String name) async {
  await tester.tap(find.text('Adicionar exercício'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

Finder get _fields => find.byType(TextFormField);

/// Preenche a n-ésima linha (reps, carga, rpe) — 3 campos por linha.
Future<void> _fillRow(
  WidgetTester tester,
  int row, {
  required String reps,
  required String weight,
  String? rpe,
}) async {
  await tester.enterText(_fields.at(row * 3), reps);
  await tester.enterText(_fields.at(row * 3 + 1), weight);
  if (rpe != null) await tester.enterText(_fields.at(row * 3 + 2), rpe);
}

List<WorkoutModel> _seedWorkouts() => [
      WorkoutModel(
        id: 1,
        date: DateTime(2026, 10, 13),
        sets: const [
          SetModel(
            exerciseId: 1,
            reps: 10,
            weightKg: 60,
            type: SetType.warmup,
          ),
          SetModel(exerciseId: 1, reps: 8, weightKg: 80, rpe: 7),
          SetModel(exerciseId: 1, reps: 8, weightKg: 80, rpe: 8),
        ],
      ),
      WorkoutModel(
        id: 2,
        date: DateTime(2026, 10, 10),
        sets: const [SetModel(exerciseId: 2, reps: 5, weightKg: 100)],
      ),
    ];

void main() {
  group('Histórico', () {
    testWidgets('lista treinos: data, exercícios, séries e volume (sem aquecimento)',
        (tester) async {
      await _pumpApp(tester, FakeWorkoutRepository(workouts: _seedWorkouts()));
      await _openHistory(tester);

      expect(find.text('13/10/2026'), findsOneWidget);
      expect(find.text('Supino reto'), findsOneWidget);
      expect(find.text('3 séries · 1.280 kg'), findsOneWidget);
      expect(find.text('10/10/2026'), findsOneWidget);
      expect(find.text('1 série · 500 kg'), findsOneWidget);

      // Mais novo primeiro.
      final newer = tester.getTopLeft(find.text('13/10/2026')).dy;
      final older = tester.getTopLeft(find.text('10/10/2026')).dy;
      expect(newer, lessThan(older));
    });

    testWidgets('estado vazio tem chamada para ação que abre o formulário',
        (tester) async {
      await _pumpApp(tester, FakeWorkoutRepository());
      await _openHistory(tester);

      expect(find.text('Nenhum treino ainda'), findsOneWidget);

      await tester.tap(find.text('Registrar primeiro treino'));
      await tester.pumpAndSettle();

      expect(find.text('Novo treino'), findsWidgets);
      expect(find.text('Salvar treino'), findsOneWidget);
    });

    testWidgets('erro mostra mensagem humana e "Tentar novamente" recarrega',
        (tester) async {
      final repository = FakeWorkoutRepository(workouts: _seedWorkouts())
        ..listError = const ApiException(
          'Não foi possível conectar ao servidor. '
          'Verifique sua conexão e tente novamente.',
        );
      await _pumpApp(tester, repository);
      await _openHistory(tester);

      expect(find.textContaining('conectar ao servidor'), findsOneWidget);

      repository.listError = null;
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();

      expect(find.text('13/10/2026'), findsOneWidget);
    });

    testWidgets('pull-to-refresh recarrega a lista', (tester) async {
      final repository = FakeWorkoutRepository(workouts: _seedWorkouts());
      await _pumpApp(tester, repository);
      await _openHistory(tester);
      final before = repository.listCalls;

      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(repository.listCalls, greaterThan(before));
    });

    testWidgets('excluir pede confirmação; cancelar mantém o treino',
        (tester) async {
      final repository = FakeWorkoutRepository(workouts: _seedWorkouts());
      await _pumpApp(tester, repository);
      await _openHistory(tester);

      await tester.tap(find.byTooltip('Excluir treino').first);
      await tester.pumpAndSettle();
      expect(find.text('Excluir treino?'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(repository.deleted, isEmpty);
      expect(find.text('13/10/2026'), findsOneWidget);
    });

    testWidgets('confirmar exclui o treino e some da lista', (tester) async {
      final repository = FakeWorkoutRepository(workouts: _seedWorkouts());
      await _pumpApp(tester, repository);
      await _openHistory(tester);

      await tester.tap(find.byTooltip('Excluir treino').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();

      expect(repository.deleted, [1]);
      expect(find.text('13/10/2026'), findsNothing);
      expect(find.text('10/10/2026'), findsOneWidget);
      expect(find.text('Treino excluído.'), findsOneWidget);
    });

    testWidgets('filtro por exercício deixa só os treinos que o contêm',
        (tester) async {
      await _pumpApp(tester, FakeWorkoutRepository(workouts: _seedWorkouts()));
      await _openHistory(tester);

      await tester.tap(find.byTooltip('Filtrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agachamento livre').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();

      expect(find.text('10/10/2026'), findsOneWidget);
      expect(find.text('13/10/2026'), findsNothing);
    });

    testWidgets('filtro sem resultado oferece "Limpar filtros"',
        (tester) async {
      await _pumpApp(tester, FakeWorkoutRepository(workouts: _seedWorkouts()));
      await _openHistory(tester);

      await tester.tap(find.byTooltip('Filtrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remada curvada').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();

      expect(find.text('Nenhum treino encontrado'), findsOneWidget);

      await tester.tap(find.text('Limpar filtros'));
      await tester.pumpAndSettle();

      expect(find.text('13/10/2026'), findsOneWidget);
    });
  });

  group('Formulário — novo treino', () {
    testWidgets('começa vazio e exige ao menos um exercício', (tester) async {
      await _pumpApp(tester, FakeWorkoutRepository());
      await _openNewWorkout(tester);

      expect(find.textContaining('Nenhum exercício ainda'), findsOneWidget);

      await tester.tap(find.text('Salvar treino'));
      await tester.pumpAndSettle();

      expect(
        find.text('Adicione ao menos um exercício com uma série.'),
        findsOneWidget,
      );
    });

    testWidgets('seletor agrupa por grupo muscular e permite buscar',
        (tester) async {
      await _pumpApp(tester, FakeWorkoutRepository());
      await _openNewWorkout(tester);

      await tester.tap(find.text('Adicionar exercício'));
      await tester.pumpAndSettle();

      expect(find.text('PEITO'), findsOneWidget);
      expect(find.text('PERNAS'), findsOneWidget);
      expect(find.text('COSTAS'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'agach');
      await tester.pumpAndSettle();

      expect(find.text('Agachamento livre'), findsOneWidget);
      expect(find.text('Supino reto'), findsNothing);
    });

    testWidgets('salva exercício com séries no formato da API', (tester) async {
      final repository = FakeWorkoutRepository();
      await _pumpApp(tester, repository);
      await _openNewWorkout(tester);

      await _addExercise(tester, 'Supino reto');
      await _fillRow(tester, 0, reps: '10', weight: '62,5', rpe: '8');
      await tester.tap(find.text('Salvar treino'));
      await tester.pumpAndSettle();

      final saved = repository.created.single;
      expect(saved.date, DateUtils.dateOnly(DateTime.now()));
      final set = saved.sets.single;
      expect(set.exerciseId, 1);
      expect(set.reps, 10);
      expect(set.weightKg, 62.5);
      expect(set.rpe, 8);
      expect(set.type, SetType.normal);

      // Depois de salvar, volta ao histórico já com o treino novo.
      expect(find.text('Treino salvo.'), findsOneWidget);
      expect(find.text('1 série · 625 kg'), findsOneWidget);
    });

    testWidgets('"Repetir última" copia a série em 1 toque (RNF-13)',
        (tester) async {
      final repository = FakeWorkoutRepository();
      await _pumpApp(tester, repository);
      await _openNewWorkout(tester);

      await _addExercise(tester, 'Supino reto');
      await _fillRow(tester, 0, reps: '8', weight: '80', rpe: '7');

      await tester.tap(find.text('Repetir última'));
      await tester.pumpAndSettle();

      expect(_fields, findsNWidgets(6));
      expect(tester.widget<TextFormField>(_fields.at(3)).controller!.text, '8');
      expect(tester.widget<TextFormField>(_fields.at(4)).controller!.text, '80');
      expect(tester.widget<TextFormField>(_fields.at(5)).controller!.text, '7');

      await tester.tap(find.text('Salvar treino'));
      await tester.pumpAndSettle();
      expect(repository.created.single.sets, hasLength(2));
    });

    testWidgets('carga acima de 1000 kg e reps acima de 500 são recusadas',
        (tester) async {
      final repository = FakeWorkoutRepository();
      await _pumpApp(tester, repository);
      await _openNewWorkout(tester);

      await _addExercise(tester, 'Supino reto');
      await _fillRow(tester, 0, reps: '501', weight: '1001');
      await tester.tap(find.text('Salvar treino'));
      await tester.pumpAndSettle();

      expect(find.text('De 1 a 500'), findsOneWidget);
      expect(find.text('De 0 a 1000'), findsOneWidget);
      expect(repository.created, isEmpty);
    });

    testWidgets('exatamente 1000 kg e 500 reps são aceitos', (tester) async {
      final repository = FakeWorkoutRepository();
      await _pumpApp(tester, repository);
      await _openNewWorkout(tester);

      await _addExercise(tester, 'Supino reto');
      await _fillRow(tester, 0, reps: '500', weight: '1000');
      await tester.tap(find.text('Salvar treino'));
      await tester.pumpAndSettle();

      expect(repository.created.single.sets.single.weightKg, 1000);
      expect(repository.created.single.sets.single.reps, 500);
    });

    testWidgets('campos obrigatórios vazios mostram "Informe"', (tester) async {
      final repository = FakeWorkoutRepository();
      await _pumpApp(tester, repository);
      await _openNewWorkout(tester);

      await _addExercise(tester, 'Supino reto');
      await tester.tap(find.text('Salvar treino'));
      await tester.pumpAndSettle();

      expect(find.text('Informe'), findsNWidgets(2));
      expect(repository.created, isEmpty);
    });

    testWidgets('tipo da série: aquecimento muda o rótulo e vai no payload',
        (tester) async {
      final repository = FakeWorkoutRepository();
      await _pumpApp(tester, repository);
      await _openNewWorkout(tester);

      await _addExercise(tester, 'Supino reto');
      await _fillRow(tester, 0, reps: '12', weight: '40');
      await tester.tap(find.text('Norm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aquecimento'));
      await tester.pumpAndSettle();

      expect(find.text('Aq.'), findsOneWidget);

      await tester.tap(find.text('Salvar treino'));
      await tester.pumpAndSettle();
      expect(repository.created.single.sets.single.type, SetType.warmup);
    });

    testWidgets('422 do servidor aparece em linguagem humana e mantém o form',
        (tester) async {
      final repository = FakeWorkoutRepository()
        ..saveError = const ApiException(
          'O servidor recusou alguns dados. Confira repetições (até 500) '
          'e carga (até 1000 kg).',
          statusCode: 422,
        );
      await _pumpApp(tester, repository);
      await _openNewWorkout(tester);

      await _addExercise(tester, 'Supino reto');
      await _fillRow(tester, 0, reps: '8', weight: '80');
      await tester.tap(find.text('Salvar treino'));
      await tester.pumpAndSettle();

      expect(find.textContaining('O servidor recusou alguns dados'), findsOneWidget);
      expect(find.text('Salvar treino'), findsOneWidget);
    });

    testWidgets('remover a série e o exercício atualiza a tela',
        (tester) async {
      await _pumpApp(tester, FakeWorkoutRepository());
      await _openNewWorkout(tester);

      await _addExercise(tester, 'Supino reto');
      expect(_fields, findsNWidgets(3));

      await tester.tap(find.byTooltip('Remover série'));
      await tester.pumpAndSettle();
      expect(_fields, findsNothing);

      await tester.tap(find.byTooltip('Remover exercício'));
      await tester.pumpAndSettle();
      expect(find.text('Supino reto'), findsNothing);
    });
  });

  group('Formulário — edição', () {
    testWidgets('abre preenchido, salva via PATCH com o id', (tester) async {
      final repository = FakeWorkoutRepository(workouts: _seedWorkouts());
      await _pumpApp(tester, repository);
      await _openHistory(tester);

      await tester.tap(find.text('13/10/2026'));
      await tester.pumpAndSettle();

      expect(find.text('Editar treino'), findsOneWidget);
      expect(find.text('Supino reto'), findsOneWidget);
      // 3 séries × 3 campos
      expect(_fields, findsNWidgets(9));
      expect(tester.widget<TextFormField>(_fields.at(0)).controller!.text, '10');
      expect(tester.widget<TextFormField>(_fields.at(1)).controller!.text, '60');
      expect(find.text('Aq.'), findsOneWidget);

      await tester.enterText(_fields.at(4), '85');
      await tester.tap(find.text('Salvar treino'));
      await tester.pumpAndSettle();

      final (id, workout) = repository.updated.single;
      expect(id, 1);
      expect(workout.sets, hasLength(3));
      expect(workout.sets[1].weightKg, 85);
      expect(workout.sets[0].type, SetType.warmup);
    });

    testWidgets('treino inexistente mostra erro humano com retry',
        (tester) async {
      final repository = FakeWorkoutRepository(workouts: _seedWorkouts());
      await _pumpApp(tester, repository);
      await _openHistory(tester);
      repository.workouts.removeWhere((w) => w.id == 1);

      await tester.tap(find.text('13/10/2026'));
      await tester.pumpAndSettle();

      expect(find.text('Não encontramos esse treino.'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
    });
  });
}
