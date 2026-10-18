# Exemplo — escrever-adr

> Exemplo **didático**: a decisão abaixo é hipotética e não foi tomada pelo grupo. Serve só para mostrar o formato da entrada e da saída.

## Entrada recebida

- **Decisão:** o worker de sincronização NOSTR usa APScheduler dentro do processo da API.
- **Motivo:** volume da turma é baixo; Celery + Redis seria infraestrutura a mais para manter (CONTEXTO §9, questão 7).
- **Alternativas discutidas:** Celery + Redis.
- **Requisitos:** RF-50, RF-52, RNF-06.

## Saída: `docs/adr/0011-worker-com-apscheduler.md`

```markdown
# ADR-0011 — Worker de sincronização com APScheduler

- **Status:** Proposto
- **Data:** 20/10/2026
- **Requisitos relacionados:** RF-50, RF-52, RNF-06

## Contexto

A ingestão de eventos do relay (RF-50) e a projeção de likes e follows (RF-52)
precisam rodar em segundo plano. O volume esperado é o de uma turma: dezenas de
usuários e poucos milhares de eventos. O time tem 6 h por semana por pessoa.

## Decisão

O worker roda com APScheduler, no mesmo processo da API, com um job de ingestão
e um de projeção. O replay (RF-53) reutiliza a mesma função de projeção.

## Alternativas consideradas

- **Celery + Redis** — escala melhor, mas adiciona dois serviços ao compose e
  mais um ponto de falha para manter, sem necessidade no volume da turma.

## Consequências

- Nenhum serviço novo no compose.
- Reiniciar a API reinicia o worker; a ingestão precisa ser idempotente
  (deduplicação por `event.id`, RF-24).
- Se o volume crescer, migrar para Celery exige um ADR que substitua este.
```

## Resumo para o PR

- **Decisão:** worker NOSTR com APScheduler no processo da API.
- **Motivo:** volume da turma não justifica Celery + Redis.
- **Consequência:** ingestão precisa ser idempotente, porque reinicia junto com a API.
