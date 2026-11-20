// Perfis da rede social na API (ADR-0012) e envio de fotos.
//
// Contrato, base /api/v1:
//   GET  /me/profile                    -> ProfileOut | 404 (ainda sem perfil)
//   PUT  /me/profile {username, ...}    -> ProfileOut | 409 username_taken
//   GET  /profiles/availability?username -> {username, available}
//   GET  /profiles/search?q             -> [ProfileOut]
//   GET  /profiles?pubkeys=a&pubkeys=b  -> [ProfileOut]
//   GET  /profiles/{username}           -> ProfileOut | 404
//   POST /media (multipart "file")      -> {url, mime_type, width, height, size_bytes, sha256}

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/profile_model.dart';

/// Foto salva na API: os campos vão na tag `imeta` (NIP-92).
class UploadedMedia {
  const UploadedMedia({
    required this.url,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.sha256,
  });

  factory UploadedMedia.fromJson(Map<String, dynamic> json) {
    final url = json['url'];
    final sha = json['sha256'];
    if (url is! String || sha is! String) {
      throw const FormatException('Resposta de mídia fora do contrato');
    }
    return UploadedMedia(
      url: url,
      mimeType: json['mime_type'] as String? ?? 'image/webp',
      width: asInt(json['width']) ?? 0,
      height: asInt(json['height']) ?? 0,
      sha256: sha,
    );
  }

  final String url;
  final String mimeType;
  final int width;
  final int height;
  final String sha256;
}

class ProfileRepository {
  ProfileRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  static const Map<int, String> _errors = {
    404: 'Perfil não encontrado.',
    409: 'Esse nome de usuário já está em uso.',
    422: 'Confira o nome de usuário: 3 a 20 letras sem acento, números, '
        '_ ou ponto.',
  };

  static const Map<int, String> _mediaErrors = {
    413: 'A foto pode ter no máximo 5 MB.',
    415: 'Envie uma foto em JPEG, PNG ou WebP.',
    422: 'Não deu para usar essa foto. Tente outra.',
  };

  /// O próprio perfil, ou `null` se a pessoa ainda não criou.
  Future<SocialProfile?> fetchMine() {
    return _guard(() async {
      try {
        final response = await _api.dio.get<dynamic>('/me/profile');
        return SocialProfile.fromJson(response.data as Map<String, dynamic>);
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) return null;
        rethrow;
      }
    });
  }

  Future<SocialProfile> saveMine(ProfileInput input) {
    return _guard(() async {
      final response = await _api.dio.put<dynamic>(
        '/me/profile',
        data: input.toJson(),
      );
      return SocialProfile.fromJson(response.data as Map<String, dynamic>);
    }, errors: {
      ..._errors,
      409: 'Esse nome de usuário já está em uso. Escolha outro.',
    });
  }

  Future<bool> isAvailable(String username) {
    return _guard(() async {
      final response = await _api.dio.get<dynamic>(
        '/profiles/availability',
        queryParameters: {'username': normalizeUsername(username)},
      );
      return (response.data as Map<String, dynamic>)['available'] == true;
    });
  }

  Future<List<SocialProfile>> search(String query) {
    return _guard(() async {
      final response = await _api.dio.get<dynamic>(
        '/profiles/search',
        queryParameters: {'q': query.trim()},
      );
      return _profiles(response.data);
    });
  }

  /// Perfis das chaves [pubkeys] (hex). Quem não tem perfil fica de fora.
  Future<List<SocialProfile>> byPubkeys(List<String> pubkeys) {
    if (pubkeys.isEmpty) return Future.value(const []);
    return _guard(() async {
      final profiles = <SocialProfile>[];
      for (var i = 0; i < pubkeys.length; i += 100) {
        final chunk = pubkeys.sublist(
          i,
          i + 100 > pubkeys.length ? pubkeys.length : i + 100,
        );
        final response = await _api.dio.get<dynamic>(
          '/profiles',
          queryParameters: {'pubkeys': chunk},
          options: Options(listFormat: ListFormat.multi),
        );
        profiles.addAll(_profiles(response.data));
      }
      return profiles;
    });
  }

  Future<SocialProfile> byUsername(String username) {
    return _guard(() async {
      final response = await _api.dio.get<dynamic>(
        '/profiles/${Uri.encodeComponent(normalizeUsername(username))}',
      );
      return SocialProfile.fromJson(response.data as Map<String, dynamic>);
    });
  }

  Future<UploadedMedia> uploadPhoto(Uint8List bytes, String filename) {
    return _guard(() async {
      final response = await _api.dio.post<dynamic>(
        '/media',
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: filename),
        }),
      );
      return UploadedMedia.fromJson(response.data as Map<String, dynamic>);
    }, errors: _mediaErrors);
  }

  static List<SocialProfile> _profiles(Object? data) {
    if (data is! List) throw const FormatException('Lista esperada');
    return [
      for (final item in data)
        SocialProfile.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<T> _guard<T>(
    Future<T> Function() action, {
    Map<int, String> errors = _errors,
  }) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw ApiException.fromDio(e, overrides: errors);
    } on ApiException {
      rethrow;
    } on Object {
      throw const ApiException('Resposta inesperada do servidor.');
    }
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(api: ref.watch(apiClientProvider)),
);
