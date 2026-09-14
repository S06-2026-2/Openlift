// Sprint 2 — Geração e assinatura de identidade NOSTR local (pacote dart_nostr/ndk).
//
// Este serviço é o coração da UX "sem decorar chave": gera o par de chaves
// no primeiro login, guarda via SecureStorageService e assina eventos
// localmente (nunca envia o nsec para o backend).

class NostrIdentityService {
  // TODO(Sprint 2): generateKeyPair() -> (nsec, npub)
  // TODO(Sprint 2): ensureIdentityExists() -> garante que o device tem um par de chaves
  // TODO(Sprint 4): signEvent(Map event) -> Map assinado (kind 1 / kind 7 / kind 30023)
}
