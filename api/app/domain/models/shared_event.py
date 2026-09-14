"""Model `shared_events` — referência entre um registro local (treino) e o
evento NOSTR publicado para representá-lo (kind 1 ou kind 30023).

Permite que `likes` e `rankings` apontem para algo que o backend entende,
sem duplicar o conteúdo do evento (que já vive nos relays).
"""

# TODO(Sprint 4): class SharedEvent(Base) — id, workout_id (FK, nullable p/ artigos), event_id, kind, created_at
