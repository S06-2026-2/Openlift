// ADR-0012 — Postagem de foto: kind 20 (NIP-68) com imeta (NIP-92), leitura
// dos relays com assinatura verificada, curtidas contadas dos relays e o
// fluxo de publicar pela aba Social.

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
import 'package:openlift/features/social/data/nostr_relay_service.dart';
import 'package:openlift/features/social/data/photo_picker.dart';
import 'package:openlift/features/social/data/post_service.dart';
import 'package:openlift/features/social/data/profile_repository.dart';
import 'package:openlift/features/social/domain/media_model.dart';
import 'package:openlift/features/social/domain/photo_post.dart';
import 'package:openlift/features/workouts/data/workout_repository.dart';
import 'package:openlift/main.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_nostr_relay_service.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fake_stats_repository.dart';
import '../../helpers/fake_workout_repository.dart';

const _media = UploadedMedia(
  url: 'http://api.test/media/abc.webp',
  mimeType: 'image/webp',
  width: 1600,
  height: 1200,
  sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
);

class _Picker implements PhotoPicker {
  @override
  Future<PickedPhoto?> pick() async =>
      PickedPhoto(bytes: Uint8List.fromList([1, 2, 3]), name: 'treino.jpg');
}

NostrEvent _post(NostrSigner signer, {int createdAt = 100, String? url}) =>
    signer.sign(PhotoPostEvent.build(
      pubkey: signer.publicKey,
      media: url == null
          ? _media
          : UploadedMedia(
              url: url,
              mimeType: 'image/webp',
              width: 1,
              height: 1,
              sha256: 'a' * 64,
            ),
      caption: 'Dia de perna',
      createdAt: createdAt,
    ));

NostrEvent _reaction(NostrSigner signer, String target,
        {String content = '+'}) =>
    signer.sign(UnsignedNostrEvent(
      pubkey: signer.publicKey,
      createdAt: 200,
      kind: NostrKinds.reaction,
      tags: [
        ['e', target],
        ['k', '20'],
      ],
      content: content,
    ));

/// Guarda os eventos em todos os relays falsos.
void _store(FakeNostrRelayService relays, List<NostrEvent> events) {
  for (final url in relays.relays) {
    relays.stored.putIfAbsent(url, () => []).addAll(events);
  }
}

void main() {
  group('PhotoPostEvent', () {
    test('kind 20 com imeta, alt, t e a legenda no content', () {
      final signer = NostrSigner.generate();
      final event = _post(signer);

      expect(event.kind, NostrKinds.picture);
      expect(event.kind, isNot(1));
      expect(event.isValid, isTrue);
      expect(event.content, 'Dia de perna');
      expect(event.tags.first, [
        'imeta',
        'url http://api.test/media/abc.webp',
        'm image/webp',
        'dim 1600x1200',
        'x ${_media.sha256}',
        'alt Foto publicada no OpenLift: Dia de perna',
      ]);
      expect(event.tags, contains(equals(['t', 'openlift'])));
      expect(
        event.tags,
        contains(equals(['alt', 'Foto publicada no OpenLift: Dia de perna'])),
      );
    });

    test('PhotoPost lê url, dimensões e legenda', () {
      final post = PhotoPost.fromEvent(_post(NostrSigner.generate()))!;

      expect(post.imageUrl, _media.url);
      expect(post.caption, 'Dia de perna');
      expect(post.aspectRatio, closeTo(1600 / 1200, 0.001));
    });

    test('sem foto http(s) não vira postagem', () {
      final signer = NostrSigner.generate();
      expect(
        PhotoPost.fromEvent(_post(signer, url: 'javascript:alert(1)')),
        isNull,
      );
      final textNote = signer.sign(UnsignedNostrEvent(
        pubkey: signer.publicKey,
        createdAt: 1,
        kind: 1,
        tags: const [],
        content: 'oi',
      ));
      expect(PhotoPost.fromEvent(textNote), isNull);
    });
  });

  group('PostService', () {
    late FakeNostrRelayService relays;
    late FakeProfileRepository profiles;
    late PostService service;
    late String ownPubkey;

    Future<void> build({Map<String, RelayOutcome>? outcomes}) async {
      final storage = MemorySecureStorage();
      final auth = FakeAuthRepository(session: true);
      final identity = NostrIdentityService(storage: storage);
      ownPubkey = (await identity.ensureIdentity(auth.userId)).publicKeyHex;
      relays = FakeNostrRelayService(outcomes: outcomes);
      profiles = FakeProfileRepository();
      service = PostService(
        profiles: profiles,
        auth: auth,
        identity: identity,
        relays: relays,
        clock: () => DateTime.fromMillisecondsSinceEpoch(9000 * 1000),
      );
    }

    test('publicar envia a foto e publica o kind 20 assinado', () async {
      await build();

      final post = await service.publish(
        PickedPhoto(bytes: Uint8List.fromList([1]), name: 'f.jpg'),
        '  Supino novo recorde ',
      );

      expect(profiles.uploads, ['f.jpg']);
      final event = relays.sent.single.single;
      expect(event.kind, NostrKinds.picture);
      expect(event.pubkey, ownPubkey);
      expect(event.createdAt, 9000);
      expect(event.isValid, isTrue);
      expect(post.caption, 'Supino novo recorde');
      expect(post.imageUrl, 'http://api.test/media/1.webp');
    });

    test('nenhum relay aceita: erro humano', () async {
      await build(outcomes: {
        'wss://relay.um.test': RelayOutcome.rejected,
        'wss://relay.dois.test': RelayOutcome.timeout,
        'wss://relay.tres.test': RelayOutcome.unreachable,
      });

      await expectLater(
        service.publish(
          PickedPhoto(bytes: Uint8List.fromList([1]), name: 'f.jpg'),
          '',
        ),
        throwsA(isA<PostPublishException>()),
      );
    });

    test('ler descarta assinatura inválida e autor não pedido', () async {
      await build();
      final ana = NostrSigner.generate();
      final intruso = NostrSigner.generate();
      final valid = _post(ana, createdAt: 100);
      final newer = _post(ana, createdAt: 300);
      final forged = NostrEvent(
        id: valid.id,
        pubkey: valid.pubkey,
        createdAt: valid.createdAt,
        kind: valid.kind,
        tags: valid.tags,
        content: 'legenda trocada',
        sig: valid.sig,
      );
      _store(relays, [forged, newer, _post(intruso)]);

      final posts = await service.load([ana.publicKey]);

      expect(posts.map((p) => p.eventId), [newer.id]);
    });

    test('curtidas: uma por pessoa, sem contar "-"', () async {
      await build();
      final ana = NostrSigner.generate();
      final post = _post(ana);
      final bia = NostrSigner.generate();
      final caio = NostrSigner.generate();
      _store(relays, [
        post,
        _reaction(bia, post.id),
        _reaction(bia, post.id),
        _reaction(caio, post.id, content: '-'),
        _reaction(ana, post.id),
      ]);

      final likes = await service.likes([post.id], ana.publicKey);

      expect(likes[post.id]!.count, 2);
      expect(likes[post.id]!.likedByMe, isTrue);
    });

    test('curtir publica kind 7 com k = 20', () async {
      await build();
      final post = PhotoPost.fromEvent(_post(NostrSigner.generate()))!;

      await service.like(post);

      final event = relays.sent.single.single;
      expect(event.kind, NostrKinds.reaction);
      expect(event.content, '+');
      expect(event.tags.where((t) => t[0] == 'e').last[1], post.eventId);
      expect(event.tags, contains(equals(['k', '20'])));
    });
  });

  group('aba Social', () {
    late FakeNostrRelayService relays;
    late FakeProfileRepository profiles;

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final storage = MemorySecureStorage();
      final auth = FakeAuthRepository(session: true);
      final own = await NostrIdentityService(storage: storage)
          .ensureIdentity(auth.userId);
      relays = FakeNostrRelayService();
      profiles = FakeProfileRepository(
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
    }

    testWidgets('publicar foto: aparece no feed e dá para curtir',
        (tester) async {
      await open(tester);

      await tester.tap(find.text('Nova postagem'));
      await tester.pumpAndSettle();
      expect(find.text('Escolher foto'), findsOneWidget);

      await tester.tap(find.text('Escolher foto'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Legenda'),
        'Primeiro treino de costas',
      );
      await tester.tap(find.text('Publicar'));
      await tester.pumpAndSettle();

      expect(find.text('Foto publicada.'), findsOneWidget);
      expect(find.textContaining('Primeiro treino de costas'), findsOneWidget);
      expect(find.text('0 curtidas'), findsOneWidget);

      await tester.tap(find.byTooltip('Curtir foto'));
      await tester.pumpAndSettle();

      expect(find.text('1 curtida'), findsOneWidget);
      final like = relays.sent.last.single;
      expect(like.kind, NostrKinds.reaction);
      expect(like.tags, contains(equals(['k', '20'])));
    });

    testWidgets('"Publicar" fica desabilitado sem foto', (tester) async {
      await open(tester);
      await tester.tap(find.text('Nova postagem'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Publicar'));
      await tester.pumpAndSettle();

      expect(relays.sent, isEmpty);
      expect(find.text('Nova postagem'), findsOneWidget);
    });

    testWidgets('perfil mostra a grade de fotos', (tester) async {
      await open(tester);
      await tester.tap(find.text('Nova postagem'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Escolher foto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Publicar'));
      await tester.pumpAndSettle();

      // Abre o próprio perfil pela foto no topo do feed.
      await tester.tap(find.byType(CircleAvatar).first);
      await tester.pumpAndSettle();

      expect(find.text('1 FOTO'), findsOneWidget);
      final post = relays.sent.single.single;
      await tester.tap(find.byKey(ValueKey('photo-${post.id}')));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
    });
  });
}
