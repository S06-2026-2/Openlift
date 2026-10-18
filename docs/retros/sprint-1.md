# Retrospectiva — Sprint 1

- **Janela:** 18/09 → 19/10
- **Checkpoint:** Auxílio 2 — 19/10
- **Data da reunião:** _a preencher_ · **Presentes:** _a preencher_
- **Entrega prevista** ([`CONTEXTO.md` §3](../CONTEXTO.md#3-calendário--datas-inegociáveis)): registro de treino ponta a ponta contra API real; ADR-003 (schema do evento) fechado na **primeira semana**.

> A seção **Fatos** foi levantada do board e do repositório em 17/10/2026. As seções **Reunião** e **Ações** são do time e ficam para a reunião de fechamento.

## Fatos

### Resultado da entrega prevista

| Item previsto | Resultado |
|---|---|
| Registro de treino ponta a ponta contra API real | ✅ Cadastro, login, criar/editar/excluir treino e histórico com filtros funcionando no app contra a API e o Postgres |
| ADR-003 (schema do evento `kind 1301`) na primeira semana | ❌ Não fechado. NOSTR-01 (#22) segue aberto e é a dependência crítica da Sprint 2 |

### Entregue

| Frente | Issue → PR | Quem |
|---|---|---|
| Backend | BE-01 segurança (#23 → #37) | Pedro |
| Backend | BE-02 auth (#24 → #43), BE-03 migration 2 + seed (#25 → #44), BE-04 CRUD de treinos (#26 → #45) | Luiz |
| Frontend | FE-01 rede e sessão (#28 → #39), FE-02 login e cadastro (#29 → #40), FE-03 Novo Treino e histórico (#30 → #41), FE-04 redesign + navegação (#50 → #51) | Luiz |
| Testes | TEST-01 auth e CRUD (#27, coberto pelos PRs #43–#45) | Luiz |
| Testes | TEST-02 integração com Postgres (#47 → #46) | Rodrigo |
| DevOps | OPS-04 imagem da API no GHCR (#48 → #49) | Rodrigo |
| DevOps | Reporter de CI: artefatos (#17, #18, #19) | Rodrigo |
| DevOps | OPS-01 branch protection (#31), OPS-02 gitleaks + commitlint (#32 → #52), OPS-03 pre-commit + DoD (#33 → #53) | Luiz |
| Processo | Template de PR (#38) | Pedro |
| Docs | DOC-01 ADRs (#7 → #54), QA-01 critérios da Sprint 2 (#36 → #55) | Luiz |

### Não entregue

| Issue | Situação | Motivo |
|---|---|---|
| NOSTR-01 (#22) — ADR-003 + mini-NIP | Aberta | _a preencher na reunião_ |
| Deploy contínuo (#16) | Parcial: imagem publicada no GHCR, sem servidor de staging | Onde hospedar staging ainda é decisão aberta (CONTEXTO §9, questão 5) |
| Melhorar o Reporter (#20) | Em andamento na branch `feat/copilot-reporter` | _a preencher na reunião_ |
| IA-01 (#34), requisitos (#8), docs (#4) | PRs abertos em 17/10 | — |

### Números (17/10)

- **Testes:** backend com 125 testes e 98% de cobertura, mais os testes de integração com Postgres (#46); app com 130 testes.
- **CI:** lint, testes, gitleaks e commitlint obrigatórios em todo PR; merge só com 1 aprovação.
- **Retro anterior:** não houve (primeira ata).

### Pontos levantados durante a sprint

Observações registradas nos PRs, para a discussão:

- **ADR-003 atrasou** e passou a ser o maior risco da Sprint 2, como o `CONTEXTO.md` §10 previa ("schema do evento atrasar — trava front e back").
- **A entrega concentrou no fim:** boa parte dos PRs de backend, DevOps e docs entrou entre 14/10 e 17/10.
- **Desalinhamentos front × back** encontrados na integração: RPE 0 aceito pelo app e recusado pela API; o app não pagina o histórico.
- **Migrations e seed manuais** depois do `docker compose up` (RNF-10 parcial), um risco para a demo.
- **Declaração de IA** incompleta nos PRs anteriores ao template de PR (#1, #3, #17–#19); desde o template, todos declaram ([`docs/ia/registro.md`](../ia/registro.md)).

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
| Fechar NOSTR-01 (#22): mini-NIP e ADR-003 | _a definir_ | Início da Sprint 2 |
| Criar os cards da Sprint 2 com os critérios de `docs/qa/sprint-2.md` | _a definir_ | 20/10 |
| _a preencher_ | | |
