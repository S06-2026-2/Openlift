// Comentário (ADR-0012): `kind 1111` (NIP-22), que serve para comentar
// eventos que não são `kind 1`, como a foto (`kind 20`) e o treino
// (`kind 1301`).
//
// Comentário direto na postagem: a raiz (`E`/`K`/`P`) e o pai (`e`/`k`/`p`)
// são o mesmo evento. O app ainda não responde comentários (sem fio).

import '../../../core/nostr/nostr_event.dart';
import '../../../core/nostr/nostr_kinds.dart';

/// O que está sendo comentado: uma foto ou um treino publicado.
class CommentTarget {
  const CommentTarget({
    required this.eventId,
    required this.pubkey,
    required this.kind,
  });

  final String eventId;
  final String pubkey;
  final int kind;
}

class Comment {
  const Comment({
    required this.eventId,
    required this.pubkey,
    required this.createdAt,
    required this.text,
    required this.rootId,
  });

  /// Lê um `kind 1111` já verificado. `null` sem raiz `E` ou sem texto.
  static Comment? fromEvent(NostrEvent event) {
    if (event.kind != NostrKinds.comment) return null;
    String? root;
    for (final tag in event.tags) {
      if (tag.length > 1 && tag[0] == 'E') {
        root = tag[1];
        break;
      }
    }
    final text = event.content.trim();
    if (root == null || text.isEmpty) return null;
    return Comment(
      eventId: event.id,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      text: text,
      rootId: root,
    );
  }

  final String eventId;
  final String pubkey;

  /// Segundos Unix.
  final int createdAt;
  final String text;

  /// Evento comentado (tag `E`).
  final String rootId;

  DateTime get publishedAt =>
      DateTime.fromMillisecondsSinceEpoch(createdAt * 1000);
}

abstract final class CommentEvent {
  static const int maxLength = 1000;

  static UnsignedNostrEvent build({
    required String pubkey,
    required CommentTarget target,
    required String text,
    required int createdAt,
    String relayHint = '',
  }) {
    final kind = '${target.kind}';
    return UnsignedNostrEvent(
      pubkey: pubkey,
      createdAt: createdAt,
      kind: NostrKinds.comment,
      tags: [
        ['E', target.eventId, relayHint, target.pubkey],
        ['K', kind],
        ['P', target.pubkey, relayHint],
        ['e', target.eventId, relayHint, target.pubkey],
        ['k', kind],
        ['p', target.pubkey, relayHint],
      ],
      content: text.trim(),
    );
  }
}
