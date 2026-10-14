// FE-01 — Custódia local da sessão via flutter_secure_storage.
//
// Guarda o par access/refresh token da sessão. Regras:
//  - tokens NUNCA são logados, impressos nem aparecem em mensagem de erro;
//  - `clearSession()` apaga só a sessão. As chaves NOSTR (nsec/npub) terão
//    ciclo de vida próprio (ADR-005/006) e não entram no logout.

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

  // TODO(NOSTR): saveNostrKeyPair(String nsec, String npub) / readNsec() / readNpub()
  //   — fora do escopo do FE-01; depende do ADR-006 (custódia por plataforma).
}

final secureStorageServiceProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageService(),
);
