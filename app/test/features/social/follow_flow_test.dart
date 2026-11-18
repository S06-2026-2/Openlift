// NOSTR-04 — Seguir e deixar de seguir pela aba "Da rede" (RF-30): cada
// mudança publica um kind 3 com a lista completa, e a lista vem do relay,
// então sobrevive a sair e entrar e vale em outro aparelho com a mesma
// identidade.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlift/core/nostr/nostr_kinds.dart';
import 'package:openlift/core/storage/secure_storage_service.dart';
import 'package:openlift/features/auth/data/auth_repository.dart';
import 'package:openlift/features/auth/data/nostr_identity_service.dart';
import 'package:openlift/features/social/data/nostr_relay_service.dart';
import 'package:openlift/features/workouts/data/workout_repository.dart';
import 'package:openlift/main.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_nostr_relay_service.dart';
import '../../helpers/fake_workout_repository.dart';

/// Um "aparelho": conta, armazenamento e API próprios; relays compartilhados.
class _Device {
  _Device(this.relays, {required int userId, MemorySecureStorage? storage})
      : auth = FakeAuthRepository(session: true)..userId = userId,
        storage = storage ?? MemorySecureStorage();

  final FakeNostrRelayService relays;
  final FakeAuthRepository auth;
  final MemorySecureStorage storage;
  final FakeWorkoutRepository repository = FakeWorkoutRepository();

  Future<NostrIdentity> identity() =>
      NostrIdentityService(storage: storage).ensureIdentity(auth.userId);

  /// Abre o app já na aba "Da rede".
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
    await tester.tap(find.text('Da rede'));
    await tester.pumpAndSettle();
  }

  Future<void> follow(WidgetTester tester, String npub) async {
    await tester.enterText(find.byType(TextField), npub);
    await tester.tap(find.byTooltip('Seguir'));
    await tester.pumpAndSettle();
  }
}

/// Identidade de outra conta, criada sem abrir o app.
Future<NostrIdentity> _person(int userId) =>
    NostrIdentityService(storage: MemorySecureStorage()).ensureIdentity(userId);

String _short(String npub) =>
    '${npub.substring(0, 12)}…${npub.substring(npub.length - 6)}';

/// Tags `p` do último kind 3 publicado.
List<String> _lastPublishedList(FakeNostrRelayService relays) {
  final event = relays.sent.last.single;
  expect(event.kind, NostrKinds.contacts);
  expect(event.isValid, isTrue);
  return [for (final tag in event.tags) tag[1]];
}

void main() {
  testWidgets('seguir e deixar de seguir publicam a lista completa',
      (tester) async {
    final relays = FakeNostrRelayService();
    final ana = await _person(10);
    final bia = await _person(11);
    final device = _Device(relays, userId: 1);
    await device.open(tester);

    await device.follow(tester, ana.npub);
    expect(_lastPublishedList(relays), [ana.publicKeyHex]);

    await device.follow(tester, bia.npub);
    expect(_lastPublishedList(relays), [ana.publicKeyHex, bia.publicKeyHex]);
    expect(find.text('Seguindo 2 pessoas'), findsOneWidget);
    expect(find.byType(InputChip), findsNWidgets(2));

    await tester.tap(find.byTooltip('Deixar de seguir').first);
    await tester.pumpAndSettle();

    expect(_lastPublishedList(relays), [bia.publicKeyHex]);
    expect(find.text('Seguindo 1 pessoa'), findsOneWidget);
    expect(find.text(_short(bia.npub)), findsOneWidget);
    expect(find.text(_short(ana.npub)), findsNothing);
  });

  testWidgets('a lista sobrevive a sair e entrar de novo', (tester) async {
    final relays = FakeNostrRelayService();
    final ana = await _person(10);
    final device = _Device(relays, userId: 1);
    await device.open(tester);
    await device.follow(tester, ana.npub);

    // Novo ProviderScope = app reaberto; nada do estado anterior sobra.
    await device.open(tester);

    expect(find.text('Seguindo 1 pessoa'), findsOneWidget);
    expect(find.text(_short(ana.npub)), findsOneWidget);
  });

  testWidgets('outro aparelho com a mesma identidade vê a mesma lista',
      (tester) async {
    final relays = FakeNostrRelayService();
    final ana = await _person(10);
    final a = _Device(relays, userId: 1);
    await a.open(tester);
    await a.follow(tester, ana.npub);

    // Aparelho B: mesma conta, armazenamento próprio, com a chave importada.
    final secret = await a.storage.readNostrSecret(1);
    final storageB = MemorySecureStorage();
    await storageB.saveNostrSecret(1, secret!);
    final b = _Device(relays, userId: 1, storage: storageB);
    await b.open(tester);

    expect(find.text('Seguindo 1 pessoa'), findsOneWidget);
    expect(find.text(_short(ana.npub)), findsOneWidget);

    // E B continua a lista em vez de recomeçar do zero.
    final bia = await _person(11);
    await b.follow(tester, bia.npub);
    expect(_lastPublishedList(relays), [ana.publicKeyHex, bia.publicKeyHex]);
  });

  testWidgets('npub inválido mostra erro humano e não publica nada',
      (tester) async {
    final relays = FakeNostrRelayService();
    final device = _Device(relays, userId: 1);
    await device.open(tester);

    await device.follow(tester, 'npub1naoexiste');

    expect(find.text('Isso não é um npub válido.'), findsOneWidget);
    expect(find.byType(InputChip), findsNothing);
    expect(relays.sent, isEmpty);
  });

  testWidgets('seguir a si mesmo é bloqueado', (tester) async {
    final relays = FakeNostrRelayService();
    final device = _Device(relays, userId: 1);
    await device.open(tester);

    await device.follow(tester, (await device.identity()).npub);

    expect(
      find.text('Esse é o seu npub. Não dá para seguir a si mesmo.'),
      findsOneWidget,
    );
    expect(relays.sent, isEmpty);
  });

  testWidgets('seguir quem já é seguido avisa e não publica de novo',
      (tester) async {
    final relays = FakeNostrRelayService();
    final ana = await _person(10);
    final device = _Device(relays, userId: 1);
    await device.open(tester);
    await device.follow(tester, ana.npub);

    await device.follow(tester, ana.npub);

    expect(find.text('Você já segue essa pessoa.'), findsOneWidget);
    expect(relays.sent, hasLength(1));
  });

  testWidgets('nenhum relay aceita: mensagem humana e a lista não muda',
      (tester) async {
    final relays = FakeNostrRelayService(outcomes: {
      'wss://relay.um.test': RelayOutcome.rejected,
      'wss://relay.dois.test': RelayOutcome.timeout,
      'wss://relay.tres.test': RelayOutcome.unreachable,
    });
    final ana = await _person(10);
    final device = _Device(relays, userId: 1);
    await device.open(tester);

    await device.follow(tester, ana.npub);

    expect(find.textContaining('atualizar quem você segue'), findsOneWidget);
    expect(find.byType(InputChip), findsNothing);
  });

  testWidgets('quem é seguido tem os treinos lidos no feed da rede',
      (tester) async {
    final relays = FakeNostrRelayService();
    final ana = await _person(10);
    final device = _Device(relays, userId: 1);
    await device.open(tester);

    await device.follow(tester, ana.npub);

    final authors = relays.queries.last.first['authors']! as List;
    expect(authors, contains(ana.publicKeyHex));
  });
}
