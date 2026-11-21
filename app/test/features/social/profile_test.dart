// ADR-0012 — Perfil da rede social: nome de usuário único, kind 0 assinado,
// cadastro antes de entrar na aba Social, busca por nome e página de perfil.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlift/core/network/api_client.dart';
import 'package:openlift/core/network/api_exception.dart';
import 'package:openlift/core/nostr/nostr_kinds.dart';
import 'package:openlift/core/nostr/nostr_signer.dart';
import 'package:openlift/core/storage/secure_storage_service.dart';
import 'package:openlift/features/auth/data/auth_repository.dart';
import 'package:openlift/features/auth/data/nostr_identity_service.dart';
import 'package:openlift/features/dashboard/data/stats_repository.dart';
import 'package:openlift/features/social/data/nostr_relay_service.dart';
import 'package:openlift/features/social/data/photo_picker.dart';
import 'package:openlift/features/social/data/profile_repository.dart';
import 'package:openlift/features/social/data/profile_service.dart';
import 'package:openlift/features/social/domain/profile_model.dart';
import 'package:openlift/features/workouts/data/workout_repository.dart';
import 'package:openlift/main.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_nostr_relay_service.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fake_stats_repository.dart';
import '../../helpers/fake_workout_repository.dart';

const _profileJson = {
  'username': 'ana.fit',
  'display_name': 'Ana',
  'bio': null,
  'avatar_url': 'http://api.test/media/1.webp',
  'npub': 'npub1ana',
  'pubkey': '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d',
  'nip05': 'ana.fit@api.test',
};

class _FakePicker implements PhotoPicker {
  int calls = 0;

  @override
  Future<PickedPhoto?> pick() async {
    calls++;
    return PickedPhoto(bytes: Uint8List.fromList([1, 2, 3]), name: 'eu.jpg');
  }
}

class _App {
  _App({SocialProfile? mine, List<SocialProfile> others = const []})
      : profiles = FakeProfileRepository(mine: mine, others: others);

  final FakeProfileRepository profiles;
  final FakeNostrRelayService relays = FakeNostrRelayService();
  final MemorySecureStorage storage = MemorySecureStorage();
  final FakeAuthRepository auth = FakeAuthRepository(session: true);
  final _FakePicker picker = _FakePicker();

  Future<void> openSocial(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // A chave da conta já existe neste aparelho (como depois do login).
    final identity = await NostrIdentityService(storage: storage)
        .ensureIdentity(auth.userId);
    profiles.myPubkey = profiles.mine?.pubkey ?? identity.publicKeyHex;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          statsRepositoryProvider.overrideWithValue(FakeStatsRepository()),
          workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
          secureStorageServiceProvider.overrideWithValue(storage),
          nostrRelayServiceProvider.overrideWithValue(relays),
          profileRepositoryProvider.overrideWithValue(profiles),
          photoPickerProvider.overrideWithValue(picker),
        ],
        child: const OpenLiftApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Social'));
    await tester.pumpAndSettle();
  }
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

void main() {
  group('nome de usuário', () {
    test('normaliza como a API', () {
      expect(normalizeUsername('  @Ana.Fit '), 'ana.fit');
    });

    test('valida tamanho e caracteres', () {
      expect(validateUsername('ana_fit.2'), isNull);
      expect(validateUsername('@ANA'), isNull);
      expect(validateUsername(''), 'Escolha um nome de usuário.');
      expect(validateUsername('ab'), 'Use pelo menos 3 caracteres.');
      expect(validateUsername('a' * 21), 'Use no máximo 20 caracteres.');
      expect(validateUsername('joão'), isNotNull);
      expect(validateUsername('ana fit'), isNotNull);
    });
  });

  group('SocialProfile e kind 0', () {
    test('lê o formato da API', () {
      final profile = SocialProfile.fromJson(_profileJson);
      expect(profile.handle, '@ana.fit');
      expect(profile.title, 'Ana');
      expect(profile.bio, isNull);
    });

    test('sem username é resposta fora do contrato', () {
      expect(
        () => SocialProfile.fromJson({..._profileJson, 'username': null}),
        throwsFormatException,
      );
    });

    test('kind 0 leva nome, foto e nip05, assinado no aparelho', () {
      final signer = NostrSigner.generate();
      final event = signer.sign(ProfileMetadataEvent.build(
        pubkey: signer.publicKey,
        profile: SocialProfile.fromJson(_profileJson),
        createdAt: 100,
      ));

      expect(event.kind, NostrKinds.metadata);
      expect(event.isValid, isTrue);
      expect(jsonDecode(event.content), {
        'name': 'ana.fit',
        'display_name': 'Ana',
        'picture': 'http://api.test/media/1.webp',
        'nip05': 'ana.fit@api.test',
      });
    });
  });

  group('ProfileRepository', () {
    late FakeHttpAdapter adapter;
    late ApiClient client;
    late ProfileRepository repository;

    void build(RequestHandler handler) {
      adapter = FakeHttpAdapter(handler);
      final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))
        ..httpClientAdapter = adapter;
      client = ApiClient(storage: MemorySecureStorage(access: 'a'), dio: dio);
      repository = ProfileRepository(api: client);
    }

    tearDown(() => client.dispose());

    test('sem perfil (404) devolve null', () async {
      build((_) => jsonResponse(
            {'detail': 'Perfil não encontrado.', 'code': 'profile_not_found'},
            status: 404,
          ));

      expect(await repository.fetchMine(), isNull);
    });

    test('nome em uso (409) vira mensagem humana', () async {
      build((_) => jsonResponse(
            {'detail': 'x', 'code': 'username_taken'},
            status: 409,
          ));

      await expectLater(
        repository.saveMine(const ProfileInput(username: 'ana')),
        throwsA(isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('em uso'),
        )),
      );
    });

    test('salva com o corpo normalizado', () async {
      build((_) => jsonResponse(_profileJson));

      await repository.saveMine(
        const ProfileInput(username: ' @Ana.Fit', displayName: ' ', bio: 'x'),
      );

      final request = adapter.requests.single;
      expect(request.method, 'PUT');
      expect(request.path, '/me/profile');
      expect(request.data, {
        'username': 'ana.fit',
        'display_name': null,
        'bio': 'x',
        'avatar_url': null,
      });
    });

    test('perfis por pubkey repetem o parâmetro', () async {
      build((_) => jsonResponse([_profileJson]));

      final found = await repository.byPubkeys(['a' * 64, 'b' * 64]);

      expect(
        adapter.requests.single.uri.query,
        'pubkeys=${'a' * 64}&pubkeys=${'b' * 64}',
      );
      expect(found.single.username, 'ana.fit');
    });

    test('foto vai em multipart para /media', () async {
      build((_) => jsonResponse({
            'url': 'http://api.test/media/x.webp',
            'mime_type': 'image/webp',
            'width': 10,
            'height': 10,
            'size_bytes': 3,
            'sha256': 'a' * 64,
          }, status: 201));

      final media =
          await repository.uploadPhoto(Uint8List.fromList([1, 2]), 'f.jpg');

      expect(adapter.requests.single.path, '/media');
      expect(adapter.requests.single.data, isA<FormData>());
      expect(media.url, 'http://api.test/media/x.webp');
    });

    test('foto grande demais (413) vira mensagem humana', () async {
      build((_) => jsonResponse({'detail': 'x', 'code': 'y'}, status: 413));

      await expectLater(
        repository.uploadPhoto(Uint8List(1), 'f.jpg'),
        throwsA(isA<ApiException>().having(
          (e) => e.message,
          'message',
          'A foto pode ter no máximo 5 MB.',
        )),
      );
    });
  });

  group('ProfileService', () {
    Future<(ProfileService, FakeNostrRelayService, FakeProfileRepository)>
        build({Map<String, RelayOutcome>? outcomes}) async {
      final storage = MemorySecureStorage();
      final auth = FakeAuthRepository(session: true);
      final identity = NostrIdentityService(storage: storage);
      final profiles = FakeProfileRepository()
        ..myPubkey = (await identity.ensureIdentity(auth.userId)).publicKeyHex;
      final relays = FakeNostrRelayService(outcomes: outcomes);
      return (
        ProfileService(
          profiles: profiles,
          auth: auth,
          identity: identity,
          relays: relays,
          clock: () => DateTime.fromMillisecondsSinceEpoch(5000 * 1000),
        ),
        relays,
        profiles,
      );
    }

    test('salva na API e publica o kind 0 da própria chave', () async {
      final (service, relays, profiles) = await build();

      final result =
          await service.save(const ProfileInput(username: 'ana.fit'));

      expect(result.published, isTrue);
      final event = relays.sent.single.single;
      expect(event.kind, NostrKinds.metadata);
      expect(event.pubkey, profiles.myPubkey);
      expect(event.createdAt, 5000);
      expect(jsonDecode(event.content)['nip05'], 'ana.fit@api.test');
    });

    test('nenhum relay aceita: perfil salvo, publicação pendente', () async {
      final (service, _, profiles) = await build(outcomes: {
        'wss://relay.um.test': RelayOutcome.rejected,
        'wss://relay.dois.test': RelayOutcome.timeout,
        'wss://relay.tres.test': RelayOutcome.unreachable,
      });

      final result =
          await service.save(const ProfileInput(username: 'ana.fit'));

      expect(result.published, isFalse);
      expect(profiles.mine?.username, 'ana.fit');
    });
  });

  group('aba Social', () {
    testWidgets('sem perfil, pede o nome de usuário antes de entrar',
        (tester) async {
      final app = _App();
      await app.openSocial(tester);

      expect(find.text('Crie seu perfil'), findsOneWidget);
      expect(find.text('Você ainda não segue ninguém'), findsNothing);

      await tester.enterText(_field('Nome de usuário'), 'Ana.Fit');
      await tester.enterText(_field('Nome (opcional)'), 'Ana');
      await tester.tap(find.text('Criar perfil'));
      await tester.pumpAndSettle();

      expect(app.profiles.mine?.username, 'ana.fit');
      expect(find.text('Crie seu perfil'), findsNothing);
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('@ana.fit'), findsOneWidget);
      expect(find.text('Você ainda não segue ninguém'), findsOneWidget);
      // O perfil foi publicado como kind 0 nos relays.
      final kind0 = app.relays.sent.expand((e) => e).where(
            (e) => e.kind == NostrKinds.metadata,
          );
      expect(kind0, hasLength(1));
    });

    testWidgets('nome fora do formato não chega à API', (tester) async {
      final app = _App();
      await app.openSocial(tester);

      await tester.enterText(_field('Nome de usuário'), 'ana fit');
      await tester.tap(find.text('Criar perfil'));
      await tester.pumpAndSettle();

      expect(find.text('Só letras sem acento, números, _ e ponto.'),
          findsOneWidget);
      expect(app.profiles.saved, isEmpty);
    });

    testWidgets('nome em uso mostra erro e mantém o cadastro', (tester) async {
      final app = _App(others: [fakeProfile('bia', pubkey: 'b' * 64)]);
      await app.openSocial(tester);

      await tester.enterText(_field('Nome de usuário'), 'bia');
      await tester.tap(find.byTooltip('Verificar nome'));
      await tester.pumpAndSettle();
      expect(find.text('Esse nome já está em uso'), findsOneWidget);

      await tester.tap(find.text('Criar perfil'));
      await tester.pumpAndSettle();
      expect(
        find.text('Esse nome de usuário já está em uso. Escolha outro.'),
        findsOneWidget,
      );
      expect(find.text('Crie seu perfil'), findsOneWidget);

      await tester.enterText(_field('Nome de usuário'), 'bia2');
      await tester.tap(find.byTooltip('Verificar nome'));
      await tester.pumpAndSettle();
      expect(find.text('Disponível'), findsOneWidget);
    });

    testWidgets('foto de perfil é enviada e vai no perfil salvo',
        (tester) async {
      final app = _App();
      await app.openSocial(tester);

      await tester.tap(find.byTooltip('Escolher foto'));
      await tester.pumpAndSettle();
      await tester.enterText(_field('Nome de usuário'), 'ana');
      await tester.tap(find.text('Criar perfil'));
      await tester.pumpAndSettle();

      expect(app.picker.calls, 1);
      expect(app.profiles.uploads, ['eu.jpg']);
      expect(app.profiles.mine?.avatarUrl, 'http://api.test/media/1.webp');
    });

    testWidgets('busca pelo nome, abre o perfil e segue', (tester) async {
      final bia = fakeProfile(
        'bia_run',
        pubkey: NostrSigner.generate().publicKey,
        displayName: 'Bia Corredora',
        bio: 'Corrida e força',
      );
      final app =
          _App(mine: fakeProfile('eu.mesmo', pubkey: 'e' * 64), others: [bia]);
      await app.openSocial(tester);

      await tester.tap(find.byTooltip('Buscar pessoas'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'bi');
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();

      expect(find.text('Bia Corredora'), findsOneWidget);
      await tester.tap(find.text('Bia Corredora'));
      await tester.pumpAndSettle();

      expect(find.text('@bia_run'), findsWidgets);
      expect(find.text('Corrida e força'), findsOneWidget);
      expect(find.text('bia_run@api.test'), findsOneWidget);
      expect(find.text('Nenhum treino publicado ainda.'), findsOneWidget);

      await tester.tap(find.text('Seguir'));
      await tester.pumpAndSettle();

      final contacts = app.relays.sent.last.single;
      expect(contacts.kind, NostrKinds.contacts);
      expect(contacts.tags.map((t) => t[1]), [bia.pubkey]);
      expect(find.text('Seguindo'), findsOneWidget);
    });

    testWidgets('busca sem resultado avisa', (tester) async {
      final app = _App(mine: fakeProfile('eu.mesmo', pubkey: 'e' * 64));
      await app.openSocial(tester);

      await tester.tap(find.byTooltip('Buscar pessoas'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();

      expect(find.text('Ninguém encontrado com "zzz".'), findsOneWidget);
    });

    testWidgets('editar perfil troca a bio e volta para o feed',
        (tester) async {
      final app = _App(mine: fakeProfile('eu.mesmo', pubkey: 'e' * 64));
      await app.openSocial(tester);

      await tester.tap(find.text('Editar perfil'));
      await tester.pumpAndSettle();
      expect(find.text('Salvar perfil'), findsOneWidget);

      await tester.enterText(_field('Bio (opcional)'), 'Agachamento livre');
      await tester.tap(find.text('Salvar perfil'));
      await tester.pumpAndSettle();

      expect(app.profiles.mine?.bio, 'Agachamento livre');
      expect(find.text('Perfil atualizado.'), findsOneWidget);
      expect(find.text('Editar perfil'), findsOneWidget);
    });
  });
}
