# ADR-0007 — Relays públicos, depois relay próprio

- **Status:** Aceito
- **Data:** 17/09/2026 (registrado em arquivo em 17/10/2026)
- **Requisitos relacionados:** RF-23, RF-50, RF-60, RF-61

## Contexto

Publicar e ler treinos exige pelo menos um relay NOSTR. Relays públicos custam zero e já funcionam, mas são rede alheia: podem ficar instáveis, aplicar rate limit ou cair justamente na apresentação. Subir relay próprio cedo demais gasta tempo de DevOps que é necessário no front-end.

## Decisão

- **Até a Demo 3 (29/10):** relays públicos (`relay.damus.io`, `nos.lol`, `relay.nostr.band`).
- **A partir da Sprint 4:** relay **`strfry` próprio** no `docker compose`, publicando a política via NIP-11.
- A lista de relays é **configurável por variável de ambiente**, sem URL de relay no código.

## Alternativas consideradas

- **Relay próprio desde o início** — remove a dependência externa, mas consome tempo de DevOps nas sprints em que o front precisa de ajuda.
- **Um único relay público** — mais simples, mas um ponto único de falha.

## Consequências

- Risco inicial baixo a custo zero; a dependência de rede alheia sai antes da apresentação final.
- O código de publicação lida com sucesso e falha **por relay** desde o começo.
- Com relay próprio, dá para ativar o modo "relay da turma" com allowlist na Demo 4 (questão aberta no CONTEXTO §9) e uma write policy aceitando só os kinds do escopo (RF-61).
- Relay próprio é stretch da Sprint 4: não bloqueia nenhuma outra entrega.
