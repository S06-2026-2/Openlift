"""Worker (APScheduler/Celery) que conecta aos relays em modo LEITURA e
espelha reações (NIP-25, kind 7) sobre os `shared_events` no cache local
(`likes`), permitindo que /social/ranking seja uma query SQL rápida em vez
de uma varredura de relay a cada requisição.
"""

# TODO(Sprint 4): sync_reactions() — roda periodicamente, usa infra/nostr/relay_client.py
# TODO(Sprint 4): agendamento (APScheduler job ou Celery beat) a cada N minutos
# TODO(Sprint 5): recompute_rankings() após cada sincronização
