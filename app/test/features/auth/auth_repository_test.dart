// FE-01 — AuthRepository contra um adapter HTTP falso (sem rede).

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlift/core/network/api_client.dart';
import 'package:openlift/core/network/api_exception.dart';
import 'package:openlift/features/auth/data/auth_repository.dart';

import '../../helpers/fake_http_adapter.dart';

void main() {
  late FakeHttpAdapter adapter;
  late MemorySecureStorage storage;
  late ApiClient client;
  late AuthRepository repository;

  void build(RequestHandler handler, {MemorySecureStorage? withStorage}) {
    adapter = FakeHttpAdapter(handler);
    storage = withStorage ?? MemorySecureStorage();
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))
      ..httpClientAdapter = adapter;
    client = ApiClient(storage: storage, dio: dio);
    repository = AuthRepository(api: client, storage: storage);
  }

  tearDown(() => client.dispose());

  group('login', () {
    test('persiste access e refresh token', () async {
      build((_) => jsonResponse({
            'access_token': 'acc',
            'refresh_token': 'ref',
            'token_type': 'bearer',
          }));

      await repository.login(email: 'a@b.com', password: 'senha-segura');

      expect(await storage.readAccessToken(), 'acc');
      expect(await storage.readRefreshToken(), 'ref');
      expect(adapter.requests.single.data, {
        'email': 'a@b.com',
        'password': 'senha-segura',
      });
    });

    test('401 vira "e-mail ou senha incorretos"', () async {
      build((_) => jsonResponse({'detail': 'Invalid'}, status: 401));

      await expectLater(
        repository.login(email: 'a@b.com', password: 'errada-123'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'E-mail ou senha incorretos.',
          ),
        ),
      );
      expect(storage.isEmpty, isTrue);
    });

    test('resposta sem tokens vira erro humano', () async {
      build((_) => jsonResponse({'unexpected': true}));

      await expectLater(
        repository.login(email: 'a@b.com', password: 'senha-segura'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('register', () {
    test('devolve o UserModel', () async {
      build((_) => jsonResponse({
            'id': 7,
            'email': 'a@b.com',
            'npub': null,
            'created_at': '2026-10-14T12:00:00Z',
          }, status: 201));

      final user = await repository.register(
        email: 'a@b.com',
        password: 'senha-segura',
      );

      expect(user.id, 7);
      expect(user.email, 'a@b.com');
      expect(user.npub, isNull);
    });

    test('409 vira "e-mail já cadastrado"', () async {
      build((_) => jsonResponse({'detail': 'exists'}, status: 409));

      await expectLater(
        repository.register(email: 'a@b.com', password: 'senha-segura'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('já está cadastrado'),
          ),
        ),
      );
    });
  });

  group('sessão', () {
    test('hasSession reflete o token salvo', () async {
      build((_) => jsonResponse({}), withStorage: MemorySecureStorage(access: 'a'));
      expect(await repository.hasSession(), isTrue);

      await repository.logout();
      expect(await repository.hasSession(), isFalse);
      expect(storage.isEmpty, isTrue);
    });
  });
}
