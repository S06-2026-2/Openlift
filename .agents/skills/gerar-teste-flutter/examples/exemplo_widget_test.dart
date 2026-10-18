// Exemplo da skill gerar-teste-flutter — teste de tela no padrão do OpenLift.
//
// Baseado em app/test/features/workouts/workout_screens_test.dart. Mostra:
// tela fixa, ProviderScope com fakes, navegação pelo texto visível, erro da
// API em linguagem humana e "Tentar novamente".
//
// Para usar de verdade, o arquivo fica em app/test/features/<feature>/.

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
  // Tamanho fixo: < 840 px de largura = navegação inferior.
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Sessão salva: o app abre direto na tela Início.
        authRepositoryProvider
            .overrideWithValue(FakeAuthRepository(session: true)),
        workoutRepositoryProvider.overrideWithValue(repository),
      ],
      child: const OpenLiftApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('histórico mostra o treino com séries e volume', (tester) async {
    // Arrange
    final repository = FakeWorkoutRepository(
      workouts: [
        WorkoutModel(
          id: 1,
          date: DateTime(2026, 10, 13),
          sets: const [SetModel(exerciseId: 1, reps: 8, weightKg: 80)],
        ),
      ],
    );
    await _pumpApp(tester, repository);

    // Act: navega como o usuário, pelo texto visível.
    await tester.tap(find.text('Meus treinos'));
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('13/10/2026'), findsOneWidget);
    expect(find.text('1 série · 640 kg'), findsOneWidget);
  });

  testWidgets('erro da API aparece em linguagem humana e o retry recarrega',
      (tester) async {
    final repository = FakeWorkoutRepository()
      ..listError = const ApiException('Não foi possível conectar ao servidor.');
    await _pumpApp(tester, repository);

    await tester.tap(find.text('Meus treinos'));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível conectar ao servidor.'), findsOneWidget);

    // A API volta: "Tentar novamente" recarrega e mostra o estado vazio.
    repository.listError = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum treino ainda'), findsOneWidget);
  });
}
