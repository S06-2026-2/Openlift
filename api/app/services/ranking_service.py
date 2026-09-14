"""Cálculo do ranking social: score = curtidas recentes com decaimento por
tempo, a partir do cache de `likes` mantido pelo nostr_sync_worker."""

# TODO(Sprint 4): compute_score(like_timestamps: list[datetime]) -> float
# TODO(Sprint 4): recompute_rankings(db) -> atualiza a tabela `rankings`
