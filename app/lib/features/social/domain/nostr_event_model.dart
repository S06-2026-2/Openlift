// Sprint 3/4 — Modelo de evento NOSTR usado no feed e na composição.
//
// O evento genérico (NIP-01: id, assinatura, verificação) e os kinds ficam em
// lib/core/nostr/. Treino é kind 1301, nunca kind 1 (ADR-0003); este modelo
// cobre o que o feed exibe: kind 30023 (NIP-23, artigo) e kind 7 (NIP-25, like).

class NostrEventModel {
  // TODO(Sprint 3): campos id, pubkey, kind, content, createdAt, tags.
  // TODO(Sprint 3): fromRelayPayload (parse da mensagem EVENT do relay).
}
