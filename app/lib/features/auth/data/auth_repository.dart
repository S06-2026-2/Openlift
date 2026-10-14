// FE-01 — Chamadas de autenticação à API (register, login) e custódia da
// sessão. O refresh de token é responsabilidade do interceptor do ApiClient.
//
// Contrato esperado do backend (BE-02):
//   POST /auth/register  {email, password}  -> UserOut
//   POST /auth/login     {email, password}  -> {access_token, refresh_token, token_type}
//   POST /auth/refresh   {refresh_token}    -> {access_token, refresh_token}
//
// TODO(NOSTR): registerNostrIdentity(npub) -> POST /me/nostr-identity.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../domain/user_model.dart';

class AuthRepository {
  AuthRepository({
    required ApiClient api,
    required SecureStorageService storage,
  })  : _api = api,
        _storage = storage;

  final ApiClient _api;
  final SecureStorageService _storage;

  /// Emite quando o servidor rejeitou o refresh e a sessão foi encerrada.
  Stream<void> get sessionExpired => _api.onSessionExpired;

  Future<UserModel> register({
    required String email,
    required String password,
  }) async {
    final data = await _post(
      '/auth/register',
      {'email': email, 'password': password},
      overrides: const {409: 'Este e-mail já está cadastrado. Tente entrar.'},
    );
    try {
      return UserModel.fromJson(data);
    } on Object {
      throw const ApiException('Resposta inesperada do servidor.');
    }
  }

  /// Autentica e persiste os tokens de sessão.
  Future<void> login({required String email, required String password}) async {
    final data = await _post(
      '/auth/login',
      {'email': email, 'password': password},
      overrides: const {401: 'E-mail ou senha incorretos.'},
    );
    final access = data['access_token'];
    final refresh = data['refresh_token'];
    if (access is! String || refresh is! String) {
      throw const ApiException('Resposta inesperada do servidor.');
    }
    await _storage.saveSessionTokens(accessToken: access, refreshToken: refresh);
  }

  /// Há sessão salva no dispositivo? (restaura o login ao reiniciar o app)
  Future<bool> hasSession() async {
    final token = await _storage.readAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// Logout: limpa os tokens do dispositivo.
  Future<void> logout() => _storage.clearSession();

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    Map<int, String> overrides = const {},
  }) async {
    try {
      final response = await _api.dio.post<Map<String, dynamic>>(
        path,
        data: body,
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException('Resposta inesperada do servidor.');
      }
      return data;
    } on DioException catch (e) {
      throw ApiException.fromDio(e, overrides: overrides);
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    api: ref.watch(apiClientProvider),
    storage: ref.watch(secureStorageServiceProvider),
  );
});
