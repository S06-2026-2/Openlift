// FE-06 — Aba "Da rede": treino publicado no aparelho A aparece no B (outra
// conta), evento adulterado é descartado e relay fora do ar mostra erro
// humano com "Tentar novamente".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlift/core/nostr/nostr_event.dart';
import 'package:openlift/core/storage/secure_storage_service.dart';
import 'package:openlift/features/auth/data/auth_repository.dart';
import 'package:openlift/features/auth/data/nostr_identity_service.dart';
import 'package:openlift/features/social/data/nostr_relay_service.dart';
import 'package:openlift/features/workouts/data/workout_repository.dart';
import 'package:openlift/features/workouts/domain/set_model.dart';
import 'package:openlift/features/workouts/domain/workout_model.dart';
import 'package:openlift/main.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_nostr_relay_service.dart';
import '../../helpers/fake_workout_repository.dart';

/// Um "aparelho": conta, armazenamento e API próprios; relays compartilhados.
class _Device {
  _Device(this.relays, {required int userId, List<WorkoutModel>? workouts})
      : auth = FakeAuthRepository(session: true)..userId = userId,
        repository = FakeWorkoutRepository(workouts: workouts);

  final FakeNostrRelayService relays;
  final FakeAuthRepository auth;
  final FakeWorkoutRepository repository;
  final MemorySecureStorage storage = MemorySecureStorage();

  Future<NostrIdentity> identity() =>
      NostrIdentityService(storage: storage).ensureIdentity(auth.userId);

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
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

  Future<void> openNetworkTab(WidgetTester tester) async {
    await tester.tap(find.text('Da rede'));
    await tester.pumpAndSettle();
  }
}

WorkoutModel _workout() => WorkoutModel(
      id: 1,
      date: DateTime(2026, 10, 13),
      sets: const [
        SetModel(exerciseId: 1, reps: 8, weightKg: 80),
        SetModel(exerciseId: 1, reps: 8, weightKg: 80),
      ],
    );

String _short(String npub) =>
    '${npub.substring(0, 12)}…${npub.substring(npub.length - 6)}';

void main() {
  testWidgets('publicado no aparelho A aparece no B, com outra conta',
      (tester) async {
    final relays = FakeNostrRelayService();

    // Aparelho A publica pela tela de histórico ("Tentar novamente" de um
    // treino que falhou é o caminho mais curto).
    final a = _Device(relays, userId: 1, workouts: [
      WorkoutModel(
        id: 1,
        date: DateTime(2026, 10, 13),
        sets: _workout().sets,
        publishStatus: PublishStatus.failed,
      ),
    ]);
    await a.open(tester);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Publicado (3/3 relays)'), findsOneWidget);
    final npubA = (await a.identity()).npub;

    // Aparelho B: outra conta, nenhum treino local.
    final b = _Device(relays, userId: 2);
    await b.open(tester);
    await b.openNetworkTab(tester);

    final npubB = (await b.identity()).npub;
    expect(find.text(_short(npubB)), findsOneWidget);
    expect(find.text('0 TREINOS NA REDE'), findsOneWidget);

    await tester.enterText(find.byType(TextField), npubA);
    await tester.tap(find.byTooltip('Adicionar'));
    await tester.pumpAndSettle();

    expect(find.text('1 TREINO NA REDE'), findsOneWidget);
    expect(find.text('Lido de 3 de 3 relays'), findsOneWidget);
    expect(find.text('Supino reto'), findsOneWidget);
    expect(find.text('2 séries · 1.280 kg'), findsOneWidget);
    expect(find.text(_short(npubA)), findsNWidgets(2)); // chip + autor
  });

  testWidgets('os próprios treinos aparecem como "Você"', (tester) async {
    final relays = FakeNostrRelayService();
    final device = _Device(relays, userId: 1, workouts: [
      WorkoutModel(
        id: 1,
        date: DateTime(2026, 10, 13),
        sets: _workout().sets,
        publishStatus: PublishStatus.failed,
      ),
    ]);
    await device.open(tester);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    await device.openNetworkTab(tester);

    expect(find.text('Você'), findsOneWidget);
    expect(find.text('13/10/2026'), findsOneWidget);
  });

  testWidgets('evento adulterado não aparece e é contado como descartado',
      (tester) async {
    final relays = FakeNostrRelayService();
    final device = _Device(relays, userId: 1, workouts: [
      WorkoutModel(
        id: 1,
        date: DateTime(2026, 10, 13),
        sets: _workout().sets,
        publishStatus: PublishStatus.failed,
      ),
    ]);
    await device.open(tester);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    // Alguém troca as repetições no relay sem poder reassinar.
    for (final events in relays.stored.values) {
      for (var i = 0; i < events.length; i++) {
        final e = events[i];
        if (e.kind != 1301) continue;
        events[i] = NostrEvent(
          id: e.id,
          pubkey: e.pubkey,
          createdAt: e.createdAt,
          kind: e.kind,
          tags: [
            for (final tag in e.tags)
              tag[0] == 'exercise'
                  ? [...tag.take(4), '100', ...tag.skip(5)]
                  : tag,
          ],
          content: e.content,
          sig: e.sig,
        );
      }
    }
    await device.openNetworkTab(tester);

    expect(find.text('0 TREINOS NA REDE'), findsOneWidget);
    expect(
      find.text('Lido de 3 de 3 relays · 1 evento descartado '
          '(assinatura inválida)'),
      findsOneWidget,
    );
  });

  testWidgets('npub inválido mostra erro e não entra na lista', (tester) async {
    final device = _Device(FakeNostrRelayService(), userId: 1);
    await device.open(tester);
    await device.openNetworkTab(tester);

    await tester.enterText(find.byType(TextField), 'npub1naoexiste');
    await tester.tap(find.byTooltip('Adicionar'));
    await tester.pumpAndSettle();

    expect(find.text('Isso não é um npub válido.'), findsOneWidget);
    expect(find.byType(InputChip), findsNothing);
  });

  testWidgets('nenhum relay responde: erro humano e "Tentar novamente"',
      (tester) async {
    final relays = FakeNostrRelayService();
    for (final url in relays.relays) {
      relays.readStatus[url] = RelayReadStatus.unreachable;
    }
    final device = _Device(relays, userId: 1);
    await device.open(tester);
    await device.openNetworkTab(tester);

    expect(find.textContaining('conectar aos relays NOSTR'), findsOneWidget);
    expect(relays.queries, hasLength(1));

    relays.readStatus.clear();
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(relays.queries, hasLength(2));
    expect(find.text('0 TREINOS NA REDE'), findsOneWidget);
  });

  testWidgets('o filtro só aparece na aba do histórico', (tester) async {
    final device = _Device(FakeNostrRelayService(), userId: 1);
    await device.open(tester);
    expect(find.byTooltip('Filtrar'), findsOneWidget);

    await device.openNetworkTab(tester);

    expect(find.byTooltip('Filtrar'), findsNothing);
  });
}
