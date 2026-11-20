// ADR-0012 — Comentários: kind 1111 (NIP-22) com raiz E/K/P e pai e/k/p,
// lidos dos relays com assinatura verificada e publicados pela folha de
// comentários do feed.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlift/core/nostr/nostr_event.dart';
import 'package:openlift/core/nostr/nostr_kinds.dart';
import 'package:openlift/core/nostr/nostr_signer.dart';
import 'package:openlift/core/storage/secure_storage_service.dart';
import 'package:openlift/features/auth/data/auth_repository.dart';
import 'package:openlift/features/auth/data/nostr_identity_service.dart';
import 'package:openlift/features/dashboard/data/stats_repository.dart';
import 'package:openlift/features/social/data/comment_service.dart';
import 'package:openlift/features/social/data/nostr_relay_service.dart';
import 'package:openlift/features/social/data/photo_picker.dart';
import 'package:openlift/features/social/data/post_service.dart';
import 'package:openlift/features/social/data/profile_repository.dart';
import 'package:openlift/features/social/domain/comment.dart';
import 'package:openlift/features/workouts/data/workout_repository.dart';
import 'package:openlift/main.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_nostr_relay_service.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fake_stats_repository.dart';
import '../../helpers/fake_workout_repository.dart';

String _hex(int n) => n.toRadixString(16).padLeft(64, '0');

final _target = CommentTarget(
  eventId: _hex(20),
  pubkey: NostrSigner.generate().publicKey,
  kind: NostrKinds.picture,
);

NostrEvent _comment(NostrSigner signer, String text, {int createdAt = 100}) =>
    signer.sign(CommentEvent.build(
      pubkey: signer.publicKey,
      target: _target,
      text: text,
      createdAt: createdAt,
    ));

void _store(FakeNostrRelayService relays, List<NostrEvent> events) {
  for (final url in relays.relays) {
    relays.stored.putIfAbsent(url, () => []).addAll(events);
  }
}

class _Picker implements PhotoPicker {
  @override
  Future<PickedPhoto?> pick() async =>
      PickedPhoto(bytes: Uint8List.fromList([1]), name: 'f.jpg');
}

void main() {
  group('CommentEvent', () {
    test('kind 1111 com raiz e pai apontando para a postagem', () {
      final signer = NostrSigner.generate();
      final event = signer.sign(CommentEvent.build(
        pubkey: signer.publicKey,
        target: _target,
        text: '  Mandou bem! ',
        createdAt: 10,
        relayHint: 'wss://relay.um.test',
      ));

      expect(event.kind, NostrKinds.comment);
      expect(event.kind, 1111);
      expect(event.isValid, isTrue);
      expect(event.content, 'Mandou bem!');
      expect(event.tags, [
        ['E', _target.eventId, 'wss://relay.um.test', _target.pubkey],
        ['K', '20'],
        ['P', _target.pubkey, 'wss://relay.um.test'],
        ['e', _target.eventId, 'wss://relay.um.test', _target.pubkey],
        ['k', '20'],
        ['p', _target.pubkey, 'wss://relay.um.test'],
      ]);
    });

    test('Comment lê a raiz e ignora comentário vazio', () {
      final signer = NostrSigner.generate();
      final comment = Comment.fromEvent(_comment(signer, 'Boa!'))!;
      expect(comment.rootId, _target.eventId);
      expect(comment.text, 'Boa!');
      expect(Comment.fromEvent(_comment(signer, '   ')), isNull);
    });
  });

  group('CommentService', () {
    late FakeNostrRelayService relays;
    late CommentService service;

    Future<void> build({Map<String, RelayOutcome>? outcomes}) async {
      final storage = MemorySecureStorage();
      final auth = FakeAuthRepository(session: true);
      final identity = NostrIdentityService(storage: storage);
      await identity.ensureIdentity(auth.userId);
      relays = FakeNostrRelayService(outcomes: outcomes);
      service = CommentService(
        auth: auth,
        identity: identity,
        relays: relays,
        clock: () => DateTime.fromMillisecondsSinceEpoch(500 * 1000),
      );
    }

    test('lê por #E, em ordem, sem assinatura inválida', () async {
      await build();
      final ana = NostrSigner.generate();
      final second = _comment(ana, 'segundo', createdAt: 200);
      final first = _comment(ana, 'primeiro', createdAt: 100);
      final third = _comment(ana, 'terceiro', createdAt: 300);
      // Alguém troca o texto do terceiro sem poder reassinar.
      final forged = NostrEvent(
        id: third.id,
        pubkey: third.pubkey,
        createdAt: third.createdAt,
        kind: third.kind,
        tags: third.tags,
        content: 'texto trocado',
        sig: third.sig,
      );
      _store(relays, [second, forged, first]);

      final loaded = await service.load([_target.eventId, _hex(1)]);

      expect(
          loaded[_target.eventId]!.map((c) => c.text), ['primeiro', 'segundo']);
      expect(loaded[_hex(1)], isEmpty);
      expect(relays.queries.last.single['#E'], [_target.eventId, _hex(1)]);
    });

    test('publicar envia o kind 1111 assinado', () async {
      await build();

      final comment = await service.publish(_target, 'Que shape!');

      final event = relays.sent.single.single;
      expect(event.kind, NostrKinds.comment);
      expect(event.createdAt, 500);
      expect(comment.text, 'Que shape!');
    });

    test('nenhum relay aceita: erro humano', () async {
      await build(outcomes: {
        'wss://relay.um.test': RelayOutcome.rejected,
        'wss://relay.dois.test': RelayOutcome.rejected,
        'wss://relay.tres.test': RelayOutcome.rejected,
      });

      await expectLater(
        service.publish(_target, 'oi'),
        throwsA(isA<PostPublishException>()),
      );
    });
  });

  group('folha de comentários', () {
    testWidgets('comentar uma foto do feed', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final storage = MemorySecureStorage();
      final auth = FakeAuthRepository(session: true);
      final own = await NostrIdentityService(storage: storage)
          .ensureIdentity(auth.userId);
      final relays = FakeNostrRelayService();
      final profiles = FakeProfileRepository(
        mine: fakeProfile('eu.mesmo', pubkey: own.publicKeyHex),
      )..myPubkey = own.publicKeyHex;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            statsRepositoryProvider.overrideWithValue(FakeStatsRepository()),
            workoutRepositoryProvider
                .overrideWithValue(FakeWorkoutRepository()),
            secureStorageServiceProvider.overrideWithValue(storage),
            nostrRelayServiceProvider.overrideWithValue(relays),
            profileRepositoryProvider.overrideWithValue(profiles),
            photoPickerProvider.overrideWithValue(_Picker()),
          ],
          child: const OpenLiftApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Social'));
      await tester.pumpAndSettle();

      // Publica uma foto para ter o que comentar.
      await tester.tap(find.text('Nova postagem'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Escolher foto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Publicar'));
      await tester.pumpAndSettle();
      expect(find.text('0 comentários'), findsOneWidget);

      await tester.tap(find.byTooltip('Comentários'));
      await tester.pumpAndSettle();
      expect(
        find.text('Ninguém comentou ainda. Seja a primeira pessoa.'),
        findsOneWidget,
      );

      // Vazio não é enviado.
      await tester.tap(find.byTooltip('Enviar comentário'));
      await tester.pumpAndSettle();
      expect(
          find.text('Escreva alguma coisa antes de enviar.'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Escreva um comentário'),
        'Bora treinar!',
      );
      await tester.tap(find.byTooltip('Enviar comentário'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Bora treinar!'), findsOneWidget);
      final event = relays.sent.last.single;
      expect(event.kind, NostrKinds.comment);
      expect(event.tags.first[0], 'E');
      expect(event.tags[1], ['K', '20']);

      Navigator.of(tester.element(find.text('Comentários'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('1 comentário'), findsOneWidget);
    });
  });
}
