# Retrospectiva — Sprint 2

- **Janela:** 20/10 → 29/10
- **Checkpoint:** Demo 3 — 29/10
- **Data da reunião:** _a preencher_ · **Presentes:** _a preencher_
- **Entrega prevista** ([`CONTEXTO.md` §3](../CONTEXTO.md#3-calendário--datas-inegociáveis)): identidade + treino publicado como evento no relay + lido em outro dispositivo.

> A seção **Fatos** foi levantada do repositório (`git log` de `main` e PRs) em 22/11/2026. As seções **Reunião** e **Ações** são do time e ficam para a reunião.

## Fatos

### Resultado da entrega prevista

| Item previsto | Resultado |
|---|---|
| Identidade NOSTR gerada no aparelho e `npub` registrado no backend | ✅ FE-04 (#89) e BE-05 (#74), com `pubkey_hex` e `GET /me` (#80) |
| Treino publicado como evento `kind 1301` no relay | ✅ FE-05 (#93) no app e BE-S2-03 (#90) no backend, com RN-01 (#81) |
| Treino lido em outro dispositivo | ✅ FE-06 (#94) |
| Dependência herdada: ADR-003 + mini-NIP (NOSTR-01) | ✅ Fechado em 19/10 (#68), no primeiro dia da sprint |

### Entregue

| Issue | PR | Quem (GitHub) |
|---|---|---|
| NOSTR-01 — mini-NIP do `kind 1301` e ADR-0003 (#22) | #68 | Yam Sol Bertamini |
| NOSTR-02 — núcleo NIP-01 no app (#69) | #71 | Yam Sol Bertamini |
| NOSTR-03 — adapter do treino para `kind 1301`/`33401` (#70) | #72 | Yam Sol Bertamini |
| BE-05 — `POST /me/nostr-identity` (#73) | #74 | Yam Sol Bertamini |
| DOC-07 — README com prints e Android (#75) | #76 | Yam Sol Bertamini |
| `pubkey_hex`, `GET /me` e FK nomeada (#77) | #80 | LimaDev |
| RN-01: treino sem série não publica (#78) | #81 | LimaDev |
| FE-04 — identidade invisível + importação de `nsec` (#83) | #89 | Luiz Otavio Ribeiro de Paiva |
| BE-S2-03 — registrar publicação e falha (#79) | #90 | Pedro Henrique Fernandes Pereira |
| BE-06 — equipamento dos exercícios para o `kind 33401` (#91) | #92 | Luiz Otavio Ribeiro de Paiva |
| FE-05 — publicar `kind 1301` + status por treino (#84) | #93 | Luiz Otavio Ribeiro de Paiva |
| FE-06 — ler treinos do relay em outro dispositivo (#85) | #94 | Luiz Otavio Ribeiro de Paiva |
| Correção: toque duplo em salvar (S2-04) | #95 | LimaDev |
| Correção: permissão `INTERNET` no Android | #96 | Yam Sol Bertamini |
| Agente Gemini no CI | #88 | RodrigoTheOneAndOnly |

### Não entregue (e por quê)

| Issue | Situação | Motivo |
|---|---|---|
| Servidor de staging (#16, OPS-05 #86) | Ficou para a Sprint 4 (Railway, #99 e #100, em 13–14/11) | _a preencher na reunião_ |
| Logs estruturados e `/health` estendido | Branches sem PR desde a Sprint 1 | _a preencher na reunião_ |

### Números

- **PRs mergeados na janela (20/10 → 29/10):** 10, mais 5 em 19/10 que abriram a sprint (#68, #71, #72, #74, #76).
- **Testes:** _não levantados na época; preencher se alguém tiver o relatório do CI da Demo 3_.
- **Ações da retro anterior:** "fechar NOSTR-01" ✅ (#68); "criar os cards da Sprint 2 com os critérios de `docs/qa/sprint-2.md`" _a conferir_.

### Pontos levantados durante a sprint

Observações registradas nos PRs e no registro de IA, para a discussão:

- **O ADR-003 fechou no primeiro dia** e destravou front e back ao mesmo tempo, o oposto da Sprint 1.
- **A entrega de novo concentrou no fim:** 8 dos 10 PRs da janela entraram entre 27/10 e 29/10, às vésperas da Demo 3.
- **Bugs pegos na véspera da demo:** toque duplo no "Salvar" (#95) e a permissão `INTERNET` que faltava no APK (#96).
- **Frente de front-end concentrada numa pessoa** (FE-04, FE-05, FE-06 e BE-06), como o risco da §10 do CONTEXTO previa.

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
