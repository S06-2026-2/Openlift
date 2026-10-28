// FE-05 — Fluxo de publicação pela tela: status por treino (RF-25),
// consentimento na 1ª vez (RNF-12), toggle só ida (RF-21), republicar após
// editar (RN-08) e feedback por relay com "Tentar novamente" (RF-22).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlift/core/storage/secure_storage_service.dart';
import 'package:openlift/features/auth/data/auth_repository.dart';
import 'package:openlift/features/social/data/nostr_relay_service.dart';
import 'package:openlift/features/workouts/data/workout_repository.dart';
import 'package:openlift/features/workouts/domain/set_model.dart';
import 'package:openlift/features/workouts/domain/workout_model.dart';
import 'package:openlift/main.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_nostr_relay_service.dart';
import '../../helpers/fake_workout_repository.dart';

const String _d = '7c9e6679-7425-4f1b-9a2e-6a1f0c8d5b34';

class _Harness {
  _Harness({List<WorkoutModel>? workouts})
      : repository = FakeWorkoutRepository(workouts: workouts);

  final FakeWorkoutRepository repository;
  final FakeAuthRepository auth = FakeAuthRepository(session: true);
  final MemorySecureStorage storage = MemorySecureStorage();
  final FakeNostrRelayService relays = FakeNostrRelayService();

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          workoutRepositoryProvider.overrideWithValue(repository),
          secureStorageServiceProvider.overrideWithValue(storage),
          nostrRelayServiceProvider.overrideWithValue(relays),
        ],
        child: const OpenLiftApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Meus treinos'));
    await tester.pumpAndSettle();
  }
}

WorkoutModel _workout(
  int id, {
  PublishStatus status = PublishStatus.local,
  int day = 13,
}) =>
    WorkoutModel(
      id: id,
      date: DateTime(2026, 10, day),
      sets: const [SetModel(exerciseId: 1, reps: 8, weightKg: 80)],
      visibility: status == PublishStatus.published
          ? WorkoutVisibility.published
          : WorkoutVisibility.private,
      publishStatus: status,
      dTag: status == PublishStatus.published ? _d : null,
    );

Future<void> _newPublishedWorkout(WidgetTester tester) async {
  await tester.tap(find.text('Novo treino'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Adicionar exercício'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Supino reto'));
  await tester.pumpAndSettle();
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), '8');
  await tester.enterText(fields.at(1), '80');
  await tester.tap(find.text('Publicado'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Salvar treino'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('histórico mostra o status de cada treino', (tester) async {
    final harness = _Harness(workouts: [
      _workout(1, day: 13),
      _workout(2, day: 12, status: PublishStatus.published),
      _workout(3, day: 11, status: PublishStatus.failed),
    ]);
    await harness.pump(tester);

    expect(find.text('Privado'), findsOneWidget);
    expect(find.text('Publicado'), findsOneWidget);
    expect(find.text('Falha ao publicar'), findsOneWidget);
    // Só o que falhou oferece nova tentativa.
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('sem consentimento não publica nem salva', (tester) async {
    final harness = _Harness();
    await harness.pump(tester);

    await _newPublishedWorkout(tester);

    expect(find.text('Publicar treinos no NOSTR'), findsOneWidget);
    expect(find.textContaining('não o apaga dos relays'), findsOneWidget);

    await tester.tap(find.text('Agora não'));
    await tester.pumpAndSettle();

    expect(harness.repository.created, isEmpty);
    expect(harness.relays.sent, isEmpty);
    expect(harness.storage.values.keys,
        isNot(contains('nostr.publish_consent.1')));
    expect(find.text('Salvar treino'), findsOneWidget);
  });

  testWidgets('com consentimento salva, publica e mostra o resultado por relay',
      (tester) async {
    final harness = _Harness();
    harness.relays.outcomes['wss://relay.tres.test'] = RelayOutcome.timeout;
    await harness.pump(tester);

    await _newPublishedWorkout(tester);
    await tester.tap(find.text('Entendi, publicar'));
    await tester.pumpAndSettle();

    expect(harness.repository.created, hasLength(1));
    expect(harness.relays.sent, hasLength(1));
    expect(harness.repository.publications, hasLength(1));
    expect(
      harness.storage.values[SecureStorageService.publishConsentKey(1)],
      'true',
    );
    expect(find.text('Publicado (2/3 relays)'), findsOneWidget);
    expect(find.text('✓ relay.um.test'), findsOneWidget);
    expect(find.text('✗ relay.tres.test'), findsOneWidget);
    expect(find.text('Treino publicado em 2 de 3 relays.'), findsOneWidget);

    // "Tentar novamente" reenvia (nova versão, mesmo d).
    harness.relays.outcomes.clear();
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(harness.relays.sent, hasLength(2));
    expect(find.text('Publicado (3/3 relays)'), findsOneWidget);
    expect(
      harness.repository.publications.last.$2['d_tag'],
      harness.repository.publications.first.$2['d_tag'],
    );
  });

  testWidgets('depois do 1º consentimento, só o aviso curto', (tester) async {
    final harness = _Harness();
    await harness.storage.savePublishConsent(1);
    await harness.pump(tester);

    await _newPublishedWorkout(tester);

    expect(find.text('Publicar treinos no NOSTR'), findsNothing);
    expect(find.text('Publicar treino?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Publicar'));
    await tester.pumpAndSettle();

    expect(harness.repository.publications, hasLength(1));
  });

  testWidgets('mostra "Publicando..." enquanto os relays respondem',
      (tester) async {
    final harness = _Harness(workouts: [
      _workout(1, status: PublishStatus.failed),
    ]);
    final gate = harness.relays.gate = Completer<void>();
    await harness.pump(tester);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    expect(find.text('Publicando...'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Publicado (3/3 relays)'), findsOneWidget);
  });

  testWidgets(
      'treino publicado: visibilidade travada e salvar pergunta se republica',
      (tester) async {
    final harness = _Harness(workouts: [
      _workout(1, status: PublishStatus.published),
    ]);
    await harness.pump(tester);

    await tester.tap(find.text('13/10/2026'));
    await tester.pumpAndSettle();
    expect(
      find.text('Publicado no NOSTR. Não dá para voltar a privado.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Privado'));
    await tester.pumpAndSettle();
    expect(
      find.text('Publicado no NOSTR. Não dá para voltar a privado.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextFormField).at(0), '10');
    await tester.tap(find.text('Salvar treino'));
    await tester.pumpAndSettle();

    expect(find.text('Publicar a nova versão?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Publicar'));
    await tester.pumpAndSettle();

    expect(harness.repository.updated, hasLength(1));
    final record = harness.relays.sent.single.last;
    expect(record.firstTagValue('d'), _d);
    expect(
      record.tags.firstWhere((t) => t[0] == 'exercise')[4],
      '10',
    );
    expect(harness.repository.publications.single.$2['d_tag'], _d);
  });

  testWidgets('editar publicado e não republicar só salva', (tester) async {
    final harness = _Harness(workouts: [
      _workout(1, status: PublishStatus.published),
    ]);
    await harness.pump(tester);

    await tester.tap(find.text('13/10/2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar treino'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agora não'));
    await tester.pumpAndSettle();

    expect(harness.repository.updated, hasLength(1));
    expect(harness.relays.sent, isEmpty);
    expect(find.text('Treino salvo.'), findsOneWidget);
  });

  testWidgets('excluir treino publicado avisa que ele continua nos relays',
      (tester) async {
    final harness = _Harness(workouts: [
      _workout(1, status: PublishStatus.published),
    ]);
    await harness.pump(tester);

    await tester.tap(find.byTooltip('Excluir treino'));
    await tester.pumpAndSettle();

    expect(find.textContaining('continua público nos relays'), findsOneWidget);
  });
}
