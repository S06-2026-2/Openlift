// FE-04 — Sincronização da identidade NOSTR com o backend (RF-02, RF-03,
// RF-04) e o teste do RNF-01: nenhuma requisição nem log contém a chave
// privada, nem no caminho mais arriscado (importar um nsec colado).

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlift/core/network/api_client.dart';
import 'package:openlift/core/network/api_exception.dart';
import 'package:openlift/core/nostr/nip19.dart';
import 'package:openlift/features/auth/data/auth_repository.dart';
import 'package:openlift/features/auth/data/nostr_identity_service.dart';
import 'package:openlift/features/auth/presentation/auth_controller.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_http_adapter.dart';

const _nsec = 'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';
const _secHex =
    '67dea2ed018072d675f5415ecfaed7d2597555e202d85b3d65ea4e58d2d92ffa';
// Chave pública do nsec acima (vetor da NIP-19), conferida com coincurve.
const _npubOfNsec =
    'npub10elfcs4fr0l0r8af98jlmgdh9c8tcxjvz9qkw038js35mp4dma8qzvjptg';

ProviderContainer _container(
  FakeAuthRepository repository,
  MemorySecureStorage storage,
) {
  final container = ProviderContainer(overrides: [
    authRepositoryProvider.overrideWithValue(repository),
    nostrIdentityServiceProvider
        .overrideWithValue(NostrIdentityService(storage: storage)),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('vetor: o npub esperado é o da chave do nsec de teste', () {
    final identity =
        NostrIdentityService(storage: MemorySecureStorage()).previewNsec(_nsec);
    expect(identity.npub, _npubOfNsec);
  });

  group('depois de entrar', () {
    test('1º login gera a identidade e registra o npub no backend', () async {
      final repository = FakeAuthRepository();
      final storage = MemorySecureStorage();
      final container = _container(repository, storage);
      await container.read(authControllerProvider.future);

      final ok = await container
          .read(authControllerProvider.notifier)
          .signIn(email: 'a@b.com', password: 'senha-segura');

      await pumpEventQueue();

      final secret = await storage.readNostrSecret(1);
      expect(ok, isTrue);
      expect(secret, hasLength(64));
      expect(repository.registeredNpub, startsWith('npub1'));
      expect(repository.identityCalls,
          ['me', 'npub:${repository.registeredNpub}']);
    });

    test('cadastro também gera e registra a identidade', () async {
      final repository = FakeAuthRepository();
      final container = _container(repository, MemorySecureStorage());
      await container.read(authControllerProvider.future);

      await container
          .read(authControllerProvider.notifier)
          .signUp(email: 'novo@b.com', password: 'senha-segura');

      await pumpEventQueue();

      expect(repository.calls, ['register:novo@b.com', 'login:novo@b.com']);
      expect(repository.registeredNpub, startsWith('npub1'));
    });

    test('sair e entrar de novo reutiliza a mesma identidade', () async {
      final repository = FakeAuthRepository();
      final storage = MemorySecureStorage();
      final container = _container(repository, storage);
      await container.read(authControllerProvider.future);
      final controller = container.read(authControllerProvider.notifier);

      await controller.signIn(email: 'a@b.com', password: 'senha-segura');

      await pumpEventQueue();
      final firstNpub = repository.registeredNpub;
      await controller.signOut();
      await controller.signIn(email: 'a@b.com', password: 'senha-segura');
      await pumpEventQueue();

      expect(repository.registeredNpub, firstNpub);
      // Na segunda vez o backend já tem o npub: só consulta, não registra.
      expect(repository.identityCalls.last, 'me');
      expect(repository.identityCalls.where((c) => c.startsWith('npub:')),
          hasLength(1));
    });

    test('reabrir o app com sessão salva sincroniza em segundo plano',
        () async {
      final repository = FakeAuthRepository(session: true);
      final storage = MemorySecureStorage();
      final container = _container(repository, storage);

      final state = await container.read(authControllerProvider.future);
      await pumpEventQueue();

      expect(state.isAuthenticated, isTrue);
      expect(repository.registeredNpub, isNotNull);
      expect(await storage.readNostrSecret(1), isNotNull);
    });

    test('falha ao registrar o npub não impede o login', () async {
      final repository = FakeAuthRepository()
        ..nostrIdentityError = const ApiException('Sem conexão.');
      final container = _container(repository, MemorySecureStorage());
      await container.read(authControllerProvider.future);

      final ok = await container
          .read(authControllerProvider.notifier)
          .signIn(email: 'a@b.com', password: 'senha-segura');

      await pumpEventQueue();

      expect(ok, isTrue);
      expect(container.read(authControllerProvider).value!.isAuthenticated,
          isTrue);
    });
  });

  group('importar identidade existente (RF-04)', () {
    test('nsec válido: registra o npub dele e troca a chave local', () async {
      final repository = FakeAuthRepository(session: true);
      final storage = MemorySecureStorage();
      final container = _container(repository, storage);
      await container.read(authControllerProvider.future);
      await pumpEventQueue();

      final error = await container
          .read(authControllerProvider.notifier)
          .importNostrIdentity(_nsec);

      expect(error, isNull);
      expect(repository.registeredNpub, _npubOfNsec);
      expect(await storage.readNostrSecret(1), _secHex);
    });

    test('nsec inválido: mensagem humana e nada muda', () async {
      final repository = FakeAuthRepository(session: true);
      final storage = MemorySecureStorage();
      final container = _container(repository, storage);
      await container.read(authControllerProvider.future);
      await pumpEventQueue();
      final before = await storage.readNostrSecret(1);

      final error = await container
          .read(authControllerProvider.notifier)
          .importNostrIdentity('nsec1naoeisso');

      expect(error, 'Isso não é uma identidade NOSTR (nsec) válida.');
      expect(await storage.readNostrSecret(1), before);
    });

    test('npub já de outra conta (409): a chave local não é trocada', () async {
      final repository = FakeAuthRepository(session: true);
      final storage = MemorySecureStorage();
      final container = _container(repository, storage);
      await container.read(authControllerProvider.future);
      await pumpEventQueue();
      final before = await storage.readNostrSecret(1);
      repository.nostrIdentityError = const ApiException(
        'Essa identidade NOSTR já está ligada a outra conta.',
        statusCode: 409,
      );

      final error = await container
          .read(authControllerProvider.notifier)
          .importNostrIdentity(_nsec);

      expect(error, 'Essa identidade NOSTR já está ligada a outra conta.');
      expect(await storage.readNostrSecret(1), before);
    });
  });

  group('RNF-01: a chave privada nunca sai do aparelho', () {
    test('nenhuma requisição nem log contém a chave privada', () async {
      final storage = MemorySecureStorage();
      String? registered;
      final adapter = FakeHttpAdapter((options) {
        switch (options.path) {
          case '/auth/register':
            return jsonResponse({'id': 1, 'email': 'a@b.com', 'npub': null},
                status: 201);
          case '/auth/login':
            return jsonResponse({
              'access_token': 'acc',
              'refresh_token': 'ref',
              'token_type': 'bearer',
            });
          case '/me':
            return jsonResponse(
                {'id': 1, 'email': 'a@b.com', 'npub': registered});
          case '/me/nostr-identity':
            registered = (options.data as Map)['npub'] as String;
            return jsonResponse(
                {'id': 1, 'email': 'a@b.com', 'npub': registered});
        }
        return jsonResponse({'detail': 'não encontrado'}, status: 404);
      });
      final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))
        ..httpClientAdapter = adapter;
      final client = ApiClient(storage: storage, dio: dio);
      addTearDown(client.dispose);
      final container = ProviderContainer(overrides: [
        authRepositoryProvider
            .overrideWithValue(AuthRepository(api: client, storage: storage)),
        nostrIdentityServiceProvider
            .overrideWithValue(NostrIdentityService(storage: storage)),
      ]);
      addTearDown(container.dispose);

      final logs = <String>[];
      String? generatedSecret;
      await runZoned(
        () async {
          await container.read(authControllerProvider.future);
          final controller = container.read(authControllerProvider.notifier);
          // Fluxo completo: cadastro (gera a chave) + importação (nsec colado).
          await controller.signUp(email: 'a@b.com', password: 'senha-segura');
          await pumpEventQueue();
          generatedSecret = await storage.readNostrSecret(1);
          await controller.importNostrIdentity(_nsec);
          await controller.importNostrIdentity('nsec1colado-errado');
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => logs.add(line),
        ),
      );

      final forbidden = [
        generatedSecret!,
        Nip19.encodeNsec(generatedSecret!),
        _secHex,
        _nsec,
        'nsec1',
      ];
      final traffic = [
        for (final r in adapter.requests) ...[
          r.uri.toString(),
          jsonEncode(r.headers),
          jsonEncode(r.data),
        ],
      ];
      for (final secret in forbidden) {
        for (final item in [...traffic, ...logs]) {
          expect(item, isNot(contains(secret)));
        }
      }
      // O corpo do registro é exatamente o npub, nada além.
      final registrations = adapter.requests
          .where((r) => r.path == '/me/nostr-identity')
          .map((r) => r.data)
          .toList();
      expect(registrations, isNotEmpty);
      for (final body in registrations) {
        expect((body as Map).keys, ['npub']);
      }
      expect(registered, _npubOfNsec);
    });
  });
}
