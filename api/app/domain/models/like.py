"""Model `likes` — cache local das reações NIP-25 (kind 7) lidas dos relays
pelo worker de sincronização. Existe para permitir contagens rápidas via SQL
em vez de varrer relays a cada requisição.
"""

# TODO(Sprint 4): class Like(Base) — id, event_id, liker_pubkey, created_at
# TODO(Sprint 4): índice único (event_id, liker_pubkey) para evitar duplicidade na sincronização
