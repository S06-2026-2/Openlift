// NOSTR-04 — Lista de quem a pessoa segue: evento kind 3 da NIP-02 (RF-30).
//
// O kind 3 é substituível: vale o mais recente de cada pubkey, e cada versão
// carrega a lista **completa**, não o que mudou. Por isso, seguir ou deixar
// de seguir publica a lista inteira de novo.
//
// A lista pode ter vindo de outro cliente NOSTR (quem importou o nsec). As
// tags `p` que já existiam, com relay e apelido, e o `content` são mantidos
// como estavam; só entra ou sai a pessoa pedida.

import '../../../core/nostr/nostr_event.dart';
import '../../../core/nostr/nostr_kinds.dart';

final RegExp _hex64 = RegExp(r'^[0-9a-f]{64}$');

class ContactList {
  const ContactList({
    this.tags = const [],
    this.content = '',
    this.createdAt = 0,
  });

  /// Lista lida de um kind 3. Tag `p` com pubkey fora do formato é ignorada,
  /// e pubkey repetida conta uma vez. As demais tags são descartadas.
  factory ContactList.fromEvent(NostrEvent event) {
    if (event.kind != NostrKinds.contacts) {
      throw ArgumentError('O evento não é uma contact list (kind 3)');
    }
    final seen = <String>{};
    return ContactList(
      tags: [
        for (final tag in event.tags)
          if (tag.length >= 2 &&
              tag[0] == 'p' &&
              _hex64.hasMatch(tag[1]) &&
              seen.add(tag[1]))
            List.unmodifiable(tag),
      ],
      content: event.content,
      createdAt: event.createdAt,
    );
  }

  /// Uma tag `p` por pessoa seguida: `["p", pubkey, relay?, apelido?]`.
  final List<List<String>> tags;

  /// Mantido como veio (alguns clientes guardam a lista de relays aqui).
  final String content;

  /// `created_at` do evento de onde a lista veio; 0 se ainda não há nenhum.
  final int createdAt;

  /// Pubkeys (hex) de quem é seguido, na ordem da lista.
  List<String> get pubkeys => [for (final tag in tags) tag[1]];

  bool get isEmpty => tags.isEmpty;

  bool contains(String pubkey) => tags.any((tag) => tag[1] == pubkey);

  /// A lista com [pubkey] no fim. Se já está, devolve a mesma lista.
  ContactList follow(String pubkey) {
    if (!_hex64.hasMatch(pubkey)) {
      throw ArgumentError('Pubkey fora do formato hex');
    }
    if (contains(pubkey)) return this;
    return ContactList(
      tags: [
        ...tags,
        ['p', pubkey],
      ],
      content: content,
      createdAt: createdAt,
    );
  }

  /// A lista sem [pubkey]. Se não está, devolve a mesma lista.
  ContactList unfollow(String pubkey) {
    if (!contains(pubkey)) return this;
    return ContactList(
      tags: [
        for (final tag in tags)
          if (tag[1] != pubkey) tag
      ],
      content: content,
      createdAt: createdAt,
    );
  }

  /// O kind 3 com a lista completa, pronto para assinar. O `created_at` é
  /// [now], ou um segundo depois da versão atual se o relógio não avançou:
  /// a nova versão precisa ser a mais recente para substituir a anterior.
  UnsignedNostrEvent toUnsignedEvent({
    required String pubkey,
    required int now,
  }) =>
      UnsignedNostrEvent(
        pubkey: pubkey,
        createdAt: now > createdAt ? now : createdAt + 1,
        kind: NostrKinds.contacts,
        tags: tags,
        content: content,
      );

  /// A versão mais recente entre os kind 3 de [pubkey] em [events]. Empate de
  /// `created_at` fica com o menor `id` (NIP-01). Evento inválido, de outro
  /// autor ou de outro kind é ignorado. Sem nenhum, devolve a lista vazia.
  static ContactList latest(Iterable<NostrEvent> events, String pubkey) {
    NostrEvent? newest;
    for (final event in events) {
      if (event.kind != NostrKinds.contacts || event.pubkey != pubkey) continue;
      if (!event.isValid) continue;
      if (newest == null ||
          event.createdAt > newest.createdAt ||
          (event.createdAt == newest.createdAt &&
              event.id.compareTo(newest.id) < 0)) {
        newest = event;
      }
    }
    return newest == null ? const ContactList() : ContactList.fromEvent(newest);
  }
}
