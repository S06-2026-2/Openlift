# ADR-0010 — Gates de qualidade progressivos

- **Status:** Aceito
- **Data:** 17/09/2026 (registrado em arquivo em 17/10/2026)
- **Requisitos relacionados:** RNF-07, RNF-08

## Contexto

O roadmap original (`implementation.md`) previa gates de cobertura de testes de até 80%. Com 6 h por semana por pessoa e um front-end sobrecarregado, prometer 80% e entregar 55% é pior do que prometer 70% e bater. Um gate bloqueante desde o primeiro dia também travaria PRs nas sprints em que a base de código ainda está sendo montada.

## Decisão

A cobertura de testes vira gate **progressivamente**:

| Período | Cobertura |
|---|---|
| Até 29/10 (Demo 3) | **Informativa**: relatada no PR, não bloqueia |
| A partir da Sprint 3 (30/10) | **Bloqueante em 60%** |
| No congelamento (Sprint 5) | **Bloqueante em 70%** |

Lint continua bloqueante desde já: zero warnings de `ruff`, `black` e `flutter analyze` no merge (RNF-08).

## Alternativas consideradas

- **80% desde o início** (roadmap original) — meta irreal para o tempo do time; vira gate ignorado ou PR travado.
- **Sem gate de cobertura** — a qualidade depende só da disciplina individual e cai perto das entregas.

## Consequências

- O CI precisa mudar duas vezes: ativar o `--cov-fail-under=60` na Sprint 3 e subir para 70 no congelamento.
- O relatório do `pytest-cov` aparece em todo PR desde já, para o time acompanhar a evolução antes de virar bloqueio.
- A meta é defensável na banca: progressiva, medida e cumprida.
