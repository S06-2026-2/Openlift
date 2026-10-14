// FE-01 — Cliente HTTP (Dio) para falar com o backend FastAPI.
//
// - baseUrl via `--dart-define=API_URL` (padrão http://localhost:8000/api/v1);
// - anexa `Authorization: Bearer <access>` em toda rota fora de /auth/*;
// - em 401 tenta `/auth/refresh` UMA vez, repete a requisição original e, se
//   o servidor rejeitar o refresh, limpa a sessão e avisa [onSessionExpired];
// - várias requisições com 401 ao mesmo tempo compartilham um único refresh;
// - falha de REDE durante o refresh não derruba a sessão (só o servidor
//   rejeitando o refresh token desloga).

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../storage/secure_storage_service.dart';

class ApiClient {
  ApiClient({
    required SecureStorageService storage,
    String? baseUrl,
    Dio? dio,
  })  : _storage = storage,
        dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? AppConstants.apiBaseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 15),
                headers: const {'Accept': 'application/json'},
              ),
            ) {
    // Cliente "limpo" (sem interceptors) só para o refresh: evita laço
    // infinito. Reaproveita o adapter para funcionar também em testes.
    _refreshDio = Dio(BaseOptions(
      baseUrl: this.dio.options.baseUrl,
      connectTimeout: this.dio.options.connectTimeout,
      receiveTimeout: this.dio.options.receiveTimeout,
    ))
      ..httpClientAdapter = this.dio.httpClientAdapter;

    this.dio.interceptors.add(
      InterceptorsWrapper(onRequest: _onRequest, onError: _onError),
    );
  }

  /// Instância Dio configurada; os repositórios usam esta.
  final Dio dio;

  final SecureStorageService _storage;
  late final Dio _refreshDio;

  final StreamController<void> _sessionExpired =
      StreamController<void>.broadcast();
  Future<_RefreshOutcome>? _refreshing;

  static const String _retriedKey = 'auth_retried';

  /// Emite quando o servidor rejeitou o refresh token e a sessão foi limpa.
  Stream<void> get onSessionExpired => _sessionExpired.stream;

  void dispose() {
    _sessionExpired.close();
  }

  // Rotas /auth/* (login, register, refresh) nunca levam Bearer nem refresh.
  bool _isAuthPath(String path) => path.contains('/auth/');

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isAuthPath(options.path)) {
      final token = await _storage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final request = error.requestOptions;
    final is401 = error.response?.statusCode == 401;
    final alreadyRetried = request.extra[_retriedKey] == true;

    if (!is401 || _isAuthPath(request.path) || alreadyRetried) {
      return handler.next(error);
    }

    final outcome = await _refreshTokens();
    switch (outcome.status) {
      case _RefreshStatus.refreshed:
        try {
          final retried = await dio.fetch<dynamic>(
            request.copyWith(extra: {...request.extra, _retriedKey: true}),
          );
          return handler.resolve(retried);
        } on DioException catch (retryError) {
          return handler.next(retryError);
        }
      case _RefreshStatus.rejected:
        await _storage.clearSession();
        if (!_sessionExpired.isClosed) _sessionExpired.add(null);
        return handler.next(error);
      case _RefreshStatus.unavailable:
        // Sem rede/servidor fora: mantém a sessão e devolve o erro de conexão.
        return handler.next(outcome.error ?? error);
    }
  }

  Future<_RefreshOutcome> _refreshTokens() {
    final inFlight = _refreshing;
    if (inFlight != null) return inFlight;
    final future = _doRefresh().whenComplete(() => _refreshing = null);
    _refreshing = future;
    return future;
  }

  Future<_RefreshOutcome> _doRefresh() async {
    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return const _RefreshOutcome(_RefreshStatus.rejected);
    }
    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final data = response.data;
      final access = data?['access_token'];
      if (access is! String || access.isEmpty) {
        return const _RefreshOutcome(_RefreshStatus.rejected);
      }
      final newRefresh = data?['refresh_token'];
      await _storage.saveSessionTokens(
        accessToken: access,
        refreshToken: newRefresh is String && newRefresh.isNotEmpty
            ? newRefresh
            : refreshToken,
      );
      return const _RefreshOutcome(_RefreshStatus.refreshed);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status != null && status >= 400 && status < 500) {
        return const _RefreshOutcome(_RefreshStatus.rejected);
      }
      return _RefreshOutcome(_RefreshStatus.unavailable, error: e);
    }
  }
}

enum _RefreshStatus { refreshed, rejected, unavailable }

class _RefreshOutcome {
  const _RefreshOutcome(this.status, {this.error});

  final _RefreshStatus status;
  final DioException? error;
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(storage: ref.watch(secureStorageServiceProvider));
  ref.onDispose(client.dispose);
  return client;
});
