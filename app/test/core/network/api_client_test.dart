// FE-01 — Testes do ApiClient: Bearer, refresh em 401, sessão expirada.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlift/core/network/api_client.dart';

import '../../helpers/fake_http_adapter.dart';

void main() {
  late FakeHttpAdapter adapter;
  late MemorySecureStorage storage;
  late ApiClient client;

  ApiClient buildClient() {
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))
      ..httpClientAdapter = adapter;
    return ApiClient(storage: storage, dio: dio);
  }

  tearDown(() => client.dispose());

  group('Bearer', () {
    test('anexa o access token em rotas protegidas', () async {
      adapter = FakeHttpAdapter((_) => jsonResponse({'ok': true}));
      storage = MemorySecureStorage(access: 'acc-1', refresh: 'ref-1');
      client = buildClient();

      await client.dio.get<dynamic>('/workouts');

      expect(adapter.requests.single.headers['Authorization'], 'Bearer acc-1');
    });

    test('não anexa Bearer em /auth/login', () async {
      adapter = FakeHttpAdapter((_) => jsonResponse({'ok': true}));
      storage = MemorySecureStorage(access: 'acc-1', refresh: 'ref-1');
      client = buildClient();

      await client.dio.post<dynamic>('/auth/login', data: {'a': 1});

      expect(adapter.requests.single.headers['Authorization'], isNull);
    });

    test('sem sessão salva, não envia Authorization', () async {
      adapter = FakeHttpAdapter((_) => jsonResponse({'ok': true}));
      storage = MemorySecureStorage();
      client = buildClient();

      await client.dio.get<dynamic>('/workouts');

      expect(adapter.requests.single.headers['Authorization'], isNull);
    });
  });

  group('refresh em 401', () {
    test('renova uma vez, repete a requisição e guarda os novos tokens',
        () async {
      var workoutCalls = 0;
      adapter = FakeHttpAdapter((options) {
        if (options.path == '/auth/refresh') {
          return jsonResponse({
            'access_token': 'acc-2',
            'refresh_token': 'ref-2',
            'token_type': 'bearer',
          });
        }
        workoutCalls++;
        return workoutCalls == 1
            ? jsonResponse({'detail': 'expired'}, status: 401)
            : jsonResponse({'items': []});
      });
      storage = MemorySecureStorage(access: 'acc-1', refresh: 'ref-1');
      client = buildClient();

      final response = await client.dio.get<dynamic>('/workouts');

      expect(response.statusCode, 200);
      expect(adapter.count('POST', '/auth/refresh'), 1);
      expect(adapter.count('GET', '/workouts'), 2);
      expect(await storage.readAccessToken(), 'acc-2');
      expect(await storage.readRefreshToken(), 'ref-2');
      // A repetição já saiu com o token novo.
      expect(adapter.requests.last.headers['Authorization'], 'Bearer acc-2');
    });

    test('várias requisições com 401 compartilham um único refresh', () async {
      adapter = FakeHttpAdapter((options) async {
        if (options.path == '/auth/refresh') {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return jsonResponse(
            {'access_token': 'acc-2', 'refresh_token': 'ref-2'},
          );
        }
        // Token velho = 401; token renovado = 200.
        final stale = options.headers['Authorization'] == 'Bearer acc-1';
        return stale
            ? jsonResponse({}, status: 401)
            : jsonResponse({'ok': true});
      });
      storage = MemorySecureStorage(access: 'acc-1', refresh: 'ref-1');
      client = buildClient();

      final results = await Future.wait([
        client.dio.get<dynamic>('/workouts'),
        client.dio.get<dynamic>('/exercises'),
        client.dio.get<dynamic>('/stats'),
      ]);

      expect(results.every((r) => r.statusCode == 200), isTrue);
      expect(adapter.count('POST', '/auth/refresh'), 1);
    });

    test('refresh rejeitado limpa a sessão e emite onSessionExpired', () async {
      adapter = FakeHttpAdapter((options) {
        return options.path == '/auth/refresh'
            ? jsonResponse({'detail': 'invalid'}, status: 401)
            : jsonResponse({'detail': 'expired'}, status: 401);
      });
      storage = MemorySecureStorage(access: 'acc-1', refresh: 'ref-1');
      client = buildClient();
      final expired = client.onSessionExpired.first;

      await expectLater(
        client.dio.get<dynamic>('/workouts'),
        throwsA(isA<DioException>()),
      );

      await expired.timeout(const Duration(seconds: 1));
      expect(storage.isEmpty, isTrue);
    });

    test('falha de rede no refresh mantém a sessão', () async {
      adapter = FakeHttpAdapter((options) {
        if (options.path == '/auth/refresh') {
          throw DioException.connectionError(
            requestOptions: options,
            reason: 'offline',
          );
        }
        return jsonResponse({}, status: 401);
      });
      storage = MemorySecureStorage(access: 'acc-1', refresh: 'ref-1');
      client = buildClient();
      var expiredEmitted = false;
      final sub = client.onSessionExpired.listen((_) => expiredEmitted = true);

      await expectLater(
        client.dio.get<dynamic>('/workouts'),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.connectionError,
          ),
        ),
      );

      await Future<void>.delayed(Duration.zero);
      expect(expiredEmitted, isFalse);
      expect(await storage.readRefreshToken(), 'ref-1');
      await sub.cancel();
    });

    test('401 em /auth/login não tenta refresh', () async {
      adapter = FakeHttpAdapter((_) => jsonResponse({}, status: 401));
      storage = MemorySecureStorage(access: 'acc-1', refresh: 'ref-1');
      client = buildClient();

      await expectLater(
        client.dio.post<dynamic>('/auth/login', data: {'a': 1}),
        throwsA(isA<DioException>()),
      );

      expect(adapter.count('POST', '/auth/refresh'), 0);
      expect(await storage.readAccessToken(), 'acc-1');
    });

    test('sem refresh token salvo, desloga direto', () async {
      adapter = FakeHttpAdapter((_) => jsonResponse({}, status: 401));
      storage = MemorySecureStorage(access: 'acc-1');
      client = buildClient();
      final expired = client.onSessionExpired.first;

      await expectLater(
        client.dio.get<dynamic>('/workouts'),
        throwsA(isA<DioException>()),
      );

      await expired.timeout(const Duration(seconds: 1));
      expect(adapter.count('POST', '/auth/refresh'), 0);
    });
  });
}
