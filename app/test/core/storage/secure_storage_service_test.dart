// FE-01 — SecureStorageService: grava/lê/apaga só as chaves de sessão.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openlift/core/storage/secure_storage_service.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockSecureStorage backend;
  late SecureStorageService service;

  setUp(() {
    backend = _MockSecureStorage();
    service = SecureStorageService(storage: backend);
    when(() => backend.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenAnswer((_) async {});
    when(() => backend.delete(key: any(named: 'key')))
        .thenAnswer((_) async {});
  });

  test('saveSessionTokens grava access e refresh', () async {
    await service.saveSessionTokens(accessToken: 'a', refreshToken: 'r');

    verify(() => backend.write(
          key: SecureStorageService.accessTokenKey,
          value: 'a',
        )).called(1);
    verify(() => backend.write(
          key: SecureStorageService.refreshTokenKey,
          value: 'r',
        )).called(1);
  });

  test('read* devolvem o que o backend de storage tem', () async {
    when(() => backend.read(key: SecureStorageService.accessTokenKey))
        .thenAnswer((_) async => 'a');
    when(() => backend.read(key: SecureStorageService.refreshTokenKey))
        .thenAnswer((_) async => null);

    expect(await service.readAccessToken(), 'a');
    expect(await service.readRefreshToken(), isNull);
  });

  test('clearSession apaga somente as chaves de sessão', () async {
    await service.clearSession();

    verify(() => backend.delete(key: SecureStorageService.accessTokenKey))
        .called(1);
    verify(() => backend.delete(key: SecureStorageService.refreshTokenKey))
        .called(1);
    verifyNever(() => backend.deleteAll());
  });
}
