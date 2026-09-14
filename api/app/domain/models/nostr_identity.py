"""Model `nostr_identities` — mapeamento invisível user_id <-> npub.

O backend guarda apenas a chave PÚBLICA (npub). A chave privada (nsec) nunca
trafega até aqui: é gerada e assinada localmente no app Flutter.
"""

# TODO(Sprint 1): class NostrIdentity(Base) — id, user_id (FK), npub (unique), created_at
