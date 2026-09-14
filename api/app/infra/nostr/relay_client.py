"""Cliente WebSocket para os relays NOSTR, usado pelo nostr_sync_worker
(modo somente leitura — o backend nunca assina nem publica eventos).
"""

# TODO(Sprint 4): connect(relay_urls: list[str])
# TODO(Sprint 4): subscribe_reactions(event_ids: list[str]) -> AsyncIterator[dict]
# TODO(Sprint 4): lista de relays vem de settings.NOSTR_RELAYS (app/core/config.py)
