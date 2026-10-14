// Helpers de teste: adapter HTTP programável e storage de sessão em memória.
// Permitem exercitar o ApiClient/repositórios de verdade, sem rede nem
// plugins de plataforma.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:openlift/core/storage/secure_storage_service.dart';

/// Resposta JSON pronta para o adapter.
ResponseBody jsonResponse(Object? data, {int status = 200}) {
  return ResponseBody.fromString(
    jsonEncode(data),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

typedef RequestHandler = FutureOr<ResponseBody> Function(RequestOptions options);

class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.handler);

  RequestHandler handler;

  /// Todas as requisições recebidas (já com headers dos interceptors).
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}

  int count(String method, String path) => requests
      .where((r) => r.method == method && r.path == path)
      .length;
}

/// Substitui o flutter_secure_storage por um mapa em memória.
class MemorySecureStorage extends SecureStorageService {
  MemorySecureStorage({String? access, String? refresh}) : super() {
    if (access != null) _values[SecureStorageService.accessTokenKey] = access;
    if (refresh != null) _values[SecureStorageService.refreshTokenKey] = refresh;
  }

  final Map<String, String> _values = {};

  bool get isEmpty => _values.isEmpty;

  @override
  Future<void> saveSessionTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _values[SecureStorageService.accessTokenKey] = accessToken;
    _values[SecureStorageService.refreshTokenKey] = refreshToken;
  }

  @override
  Future<String?> readAccessToken() async =>
      _values[SecureStorageService.accessTokenKey];

  @override
  Future<String?> readRefreshToken() async =>
      _values[SecureStorageService.refreshTokenKey];

  @override
  Future<void> clearSession() async {
    _values.clear();
  }
}
