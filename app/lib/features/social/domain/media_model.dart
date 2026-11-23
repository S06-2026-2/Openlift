// Foto enviada para a API (POST /media, ADR-0012).

import '../../../core/utils/json_utils.dart';

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
