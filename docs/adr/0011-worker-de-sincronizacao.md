# ADR-0011 — Worker de sincronização com APScheduler, sem Redis

- **Status:** Aceito
- **Data:** 18/11/2026
- **Requisitos relacionados:** RF-50, RF-52, RF-53, RF-54, RNF-06, RNF-10

## Contexto

A Sprint 3 precisa de um processo em segundo plano que leia os relays e projete no Postgres o que é social: hoje, as reações `kind 7` sobre os treinos publicados (tabela `likes`, RF-52); a partir da Sprint 4, o ranking. O ADR-0004 exige que essas tabelas sejam cache reconstruível por replay (RF-53).

A questão 7 da §9 do `CONTEXTO.md` estava aberta: **APScheduler** ou **Celery + Redis**. Fatos que pesam:

- O volume é o da turma: dezenas de usuários e centenas de eventos. Uma sincronização completa cabe em segundos.
- O trabalho é **periódico** (ler o relay a cada N minutos), não uma fila de tarefas disparadas por requisição.
- O time tem 6 h por semana por pessoa, e o DevOps já é o segundo par de mãos do front-end. Cada serviço a mais no `docker compose` e no Railway é mais coisa para subir, monitorar e explicar na demo (RNF-10).
- `apscheduler` e `redis` já estão no `requirements.txt` desde a Sprint 1, mas nenhum dos dois é usado.

## Decisão

- O worker usa **APScheduler** (`BlockingScheduler`), num processo próprio com a **mesma imagem da API**: `python -m app.worker`. No `docker compose` ele vira o serviço `worker` (OPS-07).
- O intervalo é configurável por variável de ambiente (`NOSTR_SYNC_INTERVAL_SECONDS`).
- **Não usamos Redis nem Celery.** O estado do worker vive no Postgres (as próprias tabelas de cache), e cada ciclo é idempotente: rodar duas vezes dá o mesmo resultado. Por isso não precisamos de fila, lock distribuído nem broker.
- O comando de replay (RF-53) reaproveita a mesma função de sincronização do worker, sobre as tabelas vazias.
- O heatmap e as demais agregações de `/stats` são **consultas diretas** ao Postgres, sem cache em Redis. Se ficarem lentas, a primeira medida é índice, não cache.

## Alternativas consideradas

- **Celery + Redis (beat + worker)**: é o padrão para filas de tarefas e escala horizontalmente, mas exige três processos a mais (broker, beat, worker), configuração de serialização e mais um serviço no Railway. Resolve um problema de escala que não temos.
- **Agendador dentro do processo da API** (APScheduler no `lifespan` do FastAPI): dispensa um serviço, mas com mais de uma réplica ou com o `--reload` de desenvolvimento o job roda duplicado, e uma sincronização lenta disputa recursos com as requisições.
- **Cron do sistema / cron do Railway**: simples, mas fica fora do código e do `docker compose`, e é difícil de reproduzir em notebook novo.

## Consequências

- Mais fácil: um processo a mais, com a mesma imagem e as mesmas variáveis da API. O teste é uma chamada de função, sem broker.
- Mais difícil: sem fila, um ciclo que demora mais que o intervalo é pulado (o APScheduler usa `max_instances=1` e `coalesce`). Com o volume da turma, isso não deve acontecer; se acontecer, aumentamos o intervalo.
- `redis` sai do `requirements.txt` e do `docker-compose.yml`, e `REDIS_URL` sai da configuração (`config.py`, `.env.example`, `test_core.py`).
- Se o produto crescer além da turma, este ADR é substituído por um novo. A troca fica isolada em `app/worker.py`, porque a função de sincronização não depende do agendador.
