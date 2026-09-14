"""Testes do worker de sincronização NOSTR e do ranking (Sprint 4).

Usa mocks/fixtures do relay_client (respostas de WebSocket gravadas) em vez
de um relay real, para o worker de sincronização e o cálculo de score.
"""

# TODO(Sprint 4): nostr_sync_worker grava reações simuladas em `likes` sem duplicar
# TODO(Sprint 4): compute_score decai corretamente com o tempo
# TODO(Sprint 4): endpoint /social/ranking bloqueia CI abaixo de 70% de cobertura
