// Postagem de foto da rede social (ADR-0012): `kind 20` (NIP-68, "foto
// primeiro"), com a foto descrita na tag `imeta` (NIP-92) e a legenda no
// `content`. Não é `kind 1`: o feed de texto do NOSTR fica de fora, e treino
// continua sendo `kind 1301` (ADR-0003).

import '../../../core/nostr/nostr_event.dart';
import '../../../core/nostr/nostr_kinds.dart';
import 'media_model.dart';

class PhotoPost {
  const PhotoPost({
    required this.eventId,
    required this.pubkey,
    required this.createdAt,
    required this.imageUrl,
    required this.caption,
    this.width,
    this.height,
  });

  /// Lê um `kind 20` já verificado. `null` se não tem foto http(s) na
  /// `imeta` (evento de outro cliente fora do formato, por exemplo).
  static PhotoPost? fromEvent(NostrEvent event) {
    if (event.kind != NostrKinds.picture) return null;
    String? url;
    int? width;
    int? height;
    for (final tag in event.tags) {
      if (tag.isEmpty || tag[0] != 'imeta') continue;
      for (final entry in tag.skip(1)) {
        final space = entry.indexOf(' ');
        if (space <= 0) continue;
        final key = entry.substring(0, space);
        final value = entry.substring(space + 1).trim();
        if (key == 'url' && url == null) url = value;
        if (key == 'dim') {
          final parts = value.split('x');
          if (parts.length == 2) {
            width = int.tryParse(parts[0]);
            height = int.tryParse(parts[1]);
          }
        }
      }
      if (url != null) break;
    }
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
      return null;
    }
    return PhotoPost(
      eventId: event.id,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      imageUrl: url!,
      caption: event.content.trim(),
      width: width,
      height: height,
    );
  }

  final String eventId;
  final String pubkey;

  /// Segundos Unix.
  final int createdAt;
  final String imageUrl;
  final String caption;
  final int? width;
  final int? height;

  /// Proporção da foto (largura / altura), para reservar o espaço certo.
  double get aspectRatio {
    final w = width;
    final h = height;
    if (w == null || h == null || w <= 0 || h <= 0) return 1;
    return (w / h).clamp(0.5, 2.0);
  }

  DateTime get publishedAt =>
      DateTime.fromMillisecondsSinceEpoch(createdAt * 1000);
}

abstract final class PhotoPostEvent {
  static const int maxCaption = 2000;

  static UnsignedNostrEvent build({
    required String pubkey,
    required UploadedMedia media,
    required String caption,
    required int createdAt,
  }) {
    final text = caption.trim();
    final alt = text.isEmpty
        ? 'Foto publicada no OpenLift'
        : 'Foto publicada no OpenLift: '
            '${text.length > 120 ? '${text.substring(0, 120)}…' : text}';
    return UnsignedNostrEvent(
      pubkey: pubkey,
      createdAt: createdAt,
      kind: NostrKinds.picture,
      tags: [
        [
          'imeta',
          'url ${media.url}',
          'm ${media.mimeType}',
          if (media.width > 0 && media.height > 0)
            'dim ${media.width}x${media.height}',
          'x ${media.sha256}',
          'alt $alt',
        ],
        ['m', media.mimeType],
        ['x', media.sha256],
        ['t', 'openlift'],
        ['alt', alt],
      ],
      content: text,
    );
  }
}
