// FE-01 — Custódia local da sessão via flutter_secure_storage.
//
// Guarda o par access/refresh token da sessão. Regras:
//  - tokens NUNCA são logados, impressos nem aparecem em mensagem de erro;
//  - `clearSession()` apaga só a sessão. A chave NOSTR tem ciclo de vida
//    próprio (ADR-005/006) e não entra no logout.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String accessTokenKey = 'session.access_token';
  static const String refreshTokenKey = 'session.refresh_token';

  final FlutterSecureStorage _storage;

  Future<void> saveSessionTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: accessTokenKey, value: accessToken);
    await _storage.write(key: refreshTokenKey, value: refreshToken);
  }

  Future<String?> readAccessToken() => _storage.read(key: accessTokenKey);

  Future<String?> readRefreshToken() => _storage.read(key: refreshTokenKey);

  /// Logout: remove access e refresh token do dispositivo.
  Future<void> clearSession() async {
    await _storage.delete(key: accessTokenKey);
    await _storage.delete(key: refreshTokenKey);
  }

  // ---- identidade NOSTR (FE-04, ADR-0005/0006) ----------------------------
  //
  // Uma chave privada por conta (o mesmo aparelho pode ter mais de um
  // usuário). Ela NÃO é apagada no logout: reabrir o app ou entrar de novo
  // reutiliza a mesma identidade. Na web, o "armazenamento seguro" é o do
  // navegador, não o do sistema operacional (ADR-0006).

  static String nostrSecretKey(int userId) => 'nostr.secret.$userId';

  Future<void> saveNostrSecret(int userId, String secretHex) =>
      _storage.write(key: nostrSecretKey(userId), value: secretHex);

  Future<String?> readNostrSecret(int userId) =>
      _storage.read(key: nostrSecretKey(userId));
}

final secureStorageServiceProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageService(),
);
