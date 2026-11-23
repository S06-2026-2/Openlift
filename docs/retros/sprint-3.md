# Retrospectiva — Sprint 3

- **Janela:** 30/10 → 09/11
- **Checkpoint:** Auxílio 3 — 09/11
- **Data da reunião:** _a preencher_ · **Presentes:** _a preencher_
- **Entrega prevista** ([`CONTEXTO.md` §3](../CONTEXTO.md#3-calendário--datas-inegociáveis)): feed social + like + worker de agregação.

> A seção **Fatos** foi levantada do repositório (`git log` de `main` e PRs) em 22/11/2026. As seções **Reunião** e **Ações** são do time e ficam para a reunião.

## Fatos

### Resultado da entrega prevista

| Item previsto | Resultado |
|---|---|
| Feed social de quem sigo | ⚠️ Entregue **depois** da janela: FE-07 (#126) em 19/11, com o follow `kind 3` (NOSTR-04, #120) em 17/11 |
| Like (`kind 7`) | ⚠️ Entregue depois da janela: FE-08 (#127) em 19/11 e `GET /social/likes` (BE-10, #124) em 17/11 |
| Worker de agregação | ⚠️ Entregue depois da janela: ADR-0011 (#121), cliente de relay (#122) e worker de likes (#123) em 17/11 |

**Dentro da janela da sprint (30/10 → 09/11) entrou 1 PR em `main`** (#98, correção do reporter de CI). Toda a entrega da Sprint 3 chegou entre 17/11 e 19/11, já dentro da Sprint 4.

### Entregue (com a data em que entrou em `main`)

| Issue | PR | Quem (GitHub) | Data |
|---|---|---|---|
| Correção: falha de comentário do reporter não quebra o CI (#97) | #98 | RodrigoTheOneAndOnly | 09/11 |
| QA-03 — critérios de aceite da Sprint 3 (#108) | #118 | Luiz Otavio Ribeiro de Paiva | 17/11 |
| TEST-02 — RNF-01 nos logs do backend e vetores adulterados (#87) | #119 | Pedro Henrique Fernandes Pereira | 17/11 |
| NOSTR-04 — seguir e deixar de seguir com `kind 3` (#107) | #120 | Luiz Otavio Ribeiro de Paiva | 17/11 |
| BE-07 — ADR-0011, worker com APScheduler (#106) | #121 | Pedro Henrique Fernandes Pereira | 17/11 |
| BE-08 — cliente de relay com verificação de assinatura (#109) | #122 | Pedro Henrique Fernandes Pereira | 17/11 |
| BE-09 — worker projeta likes no Postgres (#110) | #123 | Pedro Henrique Fernandes Pereira | 17/11 |
| BE-10 — `GET /social/likes` (#111) | #124 | Pedro Henrique Fernandes Pereira | 17/11 |
| FE-09 — RPE de 1 a 10 e histórico paginado (#114) | #125 | Luiz Otavio Ribeiro de Paiva | 19/11 |
| FE-07 — feed cronológico de quem sigo (#112) | #126 | Luiz Otavio Ribeiro de Paiva | 19/11 |
| FE-08 — curtir treino com `kind 7` (#113) | #127 | Luiz Otavio Ribeiro de Paiva | 19/11 |
| OPS-09 — gate de cobertura no CI (#117) | #128 | RodrigoTheOneAndOnly | 19/11 |

### Não entregue (e por quê)

| Issue | Situação | Motivo |
|---|---|---|
| OPS-07 — `docker compose up` completo (#115) | Entra no PR de pendências das Sprints 3 e 4 | _a preencher na reunião_ |
| OPS-08 — logs estruturados e `/health` estendido (#116) | Entra no mesmo PR; as branches `feat/structured-logging` e `feat/extended-health` não viraram PR | _a preencher na reunião_ |
| Checklist do Auxílio 3 (`docs/qa/sprint-3.md`) | _a conferir: foi rodado no dia 09/11?_ | _a preencher_ |

### Números

- **PRs mergeados na janela (30/10 → 09/11):** 1.
- **PRs da entrega da Sprint 3, somando os que entraram depois:** 12 (tabela acima).
- **Testes:** _preencher com o relatório do CI_ (o gate de cobertura só passou a existir em 19/11, #128).
- **Ações da retro anterior:** _a conferir na reunião_ (a ata da Sprint 2 foi escrita junto com esta).

### Pontos levantados durante a sprint

- **A sprint ficou parada por 19 dias** (29/10 → 17/11) em entrega de produto. A causa precisa vir da reunião: semana de provas, outra matéria, bloqueio técnico ou falta de board atualizado. O CONTEXTO §10 já listava "semana de provas" como risco alto.
- **A recuperação foi concentrada:** 11 PRs em 3 dias (17/11 → 19/11), boa parte de uma ou duas pessoas.
- **Os critérios de aceite (QA-03) foram escritos no fim**, em 17/11, e não antes da sprint, como a Definition of Done pede.
- **Infra andou em paralelo:** staging no Railway (#99, #100) e relatório semanal (#103) entraram em 13–17/11.

## Reunião

### O que foi bem
- _a preencher_

### O que atrapalhou
- _a preencher_

### Horas (regra das 6 h)
_a preencher_

## Ações

| Ação | Dono | Prazo |
|---|---|---|
| _a preencher_ | | |
