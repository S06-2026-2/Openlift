"""Endpoints de métricas sociais que não cabem puramente no NOSTR.

POST /social/shared-events   — registra referência (workout local <-> event_id NOSTR)
GET  /social/likes           — contagem cacheada de curtidas por event_id
GET  /social/ranking         — ranking com decaimento por tempo
"""

# TODO(Sprint 4): register_shared_event(payload: schemas.social.SharedEventIn)
# TODO(Sprint 4): get_like_counts(event_ids: list[str])
# TODO(Sprint 4): get_ranking() — usa app/services/ranking_service.py
