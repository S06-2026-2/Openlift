# OpenLift API

Backend FastAPI + PostgreSQL do OpenLift. Os comandos abaixo rodam de dentro de `infra/docker/`.

## Subir o ambiente

```bash
cd infra/docker
docker compose up -d                                  # Postgres + API + Adminer
docker compose run --rm api alembic upgrade head      # aplica as migrations
docker compose run --rm api python -m app.infra.db.seed   # popula a biblioteca de exercícios
```

| Endereço | O que é |
|---|---|
| http://localhost:8000/docs | Swagger (use **Authorize** com o `access_token` do login) |
| http://localhost:8000/health | Saúde da API (checa o banco) |
| http://localhost:8080 | Adminer: sistema PostgreSQL, servidor `db`, usuário/senha/banco `openlift` |

## Seed da biblioteca de exercícios

```bash
docker compose run --rm api python -m app.infra.db.seed
```

Cria 10 grupos musculares (peito, costas, ombros, bíceps, tríceps, quadríceps, posterior, glúteos, panturrilha, abdômen) e 40 exercícios. É **idempotente**: pode rodar quantas vezes quiser, nunca duplica e corrige o grupo de um exercício que tenha mudado. A lista fica em `app/infra/db/seed.py`.

## Worker de sincronização NOSTR

```bash
docker compose run --rm api python -m app.worker
```

Processo separado da API (ADR-0011: APScheduler, sem Redis). A cada `NOSTR_SYNC_INTERVAL_SECONDS` ele lê dos relays de `NOSTR_RELAYS` os likes (`kind 7`, NIP-25) sobre os treinos publicados e projeta na tabela `likes`. Só entra evento com assinatura verificada (RF-51); um like por pessoa por treino (RN-06); `content` `"-"` (dislike) é ignorado. A tabela é cache: apagar e rodar o worker de novo reconstrói a mesma contagem (ADR-0004). O serviço `worker` do `docker compose` entra no OPS-07.

## Migrations

```bash
docker compose run --rm api alembic upgrade head        # aplica tudo
docker compose run --rm api alembic downgrade -1        # desfaz a última
docker compose run --rm api alembic revision --autogenerate -m "descricao"
```

Todo model novo precisa ser importado em `app/domain/models/__init__.py`, senão o `--autogenerate` não o enxerga. Revise sempre o script gerado antes de commitar.

## Testes e lint (mesma bateria do CI)

```bash
docker compose run --rm --no-deps -e ENV=testing -e DATABASE_URL=sqlite:///:memory: api \
  sh -c "ruff check . && black --check . && mypy . && pytest --cov=app"
```

Os testes usam SQLite em memória (`tests/conftest.py`), então não precisam do Postgres. As fixtures disponíveis são `db_session`, `client`, `auth_user` e `auth_headers`.

## Variáveis de ambiente

Veja `.env.example`. No Docker elas já vêm do `docker-compose.yml`; o `.env` só é necessário para rodar fora do container.

| Variável | Para quê |
|---|---|
| `DATABASE_URL` | Conexão com o Postgres |
| `JWT_SECRET` | Assinatura dos tokens. **Troque fora do ambiente local** |
| `JWT_EXPIRATION_MINUTES` / `JWT_REFRESH_EXPIRATION_DAYS` | Duração do access e do refresh token |
| `CORS_ORIGIN_REGEX` | Origens liberadas no CORS (padrão: qualquer porta em `localhost`) |
| `NOSTR_RELAYS` | Relays lidos pelo backend, separados por vírgula (ADR-0007). Sem valor, o backend não lê relay nenhum |
| `NOSTR_SYNC_INTERVAL_SECONDS` | Intervalo entre ciclos do worker (`python -m app.worker`), mínimo 10, padrão 300 |
| `NOSTR_RELAY_TIMEOUT_SECONDS` / `NOSTR_RELAY_MAX_RETRIES` | Espera máxima por mensagem do relay (padrão 10 s) e novas tentativas com backoff (padrão 3) |
| `PUBLIC_BASE_URL` | URL pública da API (padrão `http://localhost:8000`): domínio do NIP-05 (`usuario@host`) e base das URLs de foto (ADR-0012) |
| `MEDIA_DIR` | Pasta das fotos enviadas (padrão `media`, ignorada pelo git). **No staging, monte um volume persistente aqui**, senão as fotos somem a cada deploy (ADR-0012) |

## Rotas (`/api/v1`)

Tudo exige `Authorization: Bearer <access_token>`, exceto `/auth/*`, `/health` e `/version`.

| Método | Rota | O que faz |
|---|---|---|
| POST | `/auth/register` | Cadastro (201; e-mail duplicado → 409) |
| POST | `/auth/login` | Login (par de tokens; senha errada → 401) |
| POST | `/auth/refresh` | Troca o refresh token por um novo par |
| GET | `/me` | Usuário logado (`id`, `email`, `npub` ou `null`, `created_at`) |
| POST | `/me/nostr-identity` | Registra o `npub` gerado no app (só chave pública; idempotente; `npub` de outra conta → 409) |
| GET / PUT | `/me/profile` | Perfil da rede social (ADR-0012): sem perfil → 404 `profile_not_found`; `PUT` cria ou edita (`username` único, 3–20 de `a-z0-9_.`, guardado em minúsculas; `display_name`, `bio`, `avatar_url`). Nome em uso → 409 `username_taken`; sem `npub` registrado → 409 `nostr_identity_required` |
| GET | `/exercises` | Biblioteca com grupo muscular e equipamento do NIP-101e (`?muscle_group_id=`) |
| POST / GET | `/workouts` | Cria treino / histórico paginado (`date_from`, `date_to`, `exercise_id`, `muscle_group_id`, `limit`, `offset`) |
| GET / PATCH / DELETE | `/workouts/{id}` | Detalha, edita (`sets` enviado substitui todas as séries) e exclui |
| POST | `/workouts/{id}/sets` | Adiciona uma série |
| PATCH / DELETE | `/workouts/{id}/sets/{set_id}` | Edita ou remove uma série |
| POST | `/workouts/{id}/publication` | O app avisa que publicou o `kind 1301` (`event_id`, `pubkey`, `d_tag`): treino vira `published`. Idempotente por `event_id`; `pubkey` diferente do `npub` registrado → 403; sem série → 422 (RN-01); republicar após edição = `event_id` novo com o mesmo `d_tag` (RN-08) |
| POST | `/workouts/{id}/publication-failure` | O app avisa que nenhum relay aceitou (`event_id`, `pubkey`): treino vira `failed`. Idempotente |
| GET | `/stats/volume` | Volume semanal (RN-03, sem aquecimento) e treinos por semana ISO (`weeks` 1–52, padrão 12; `date_to`). Semanas sem treino vêm zeradas |
| GET | `/stats/muscle-groups` | Volume, séries e dias treinados por grupo muscular (`date_from`, `date_to`; padrão últimos 28 dias). Todos os grupos, do mais treinado ao menos |
| GET | `/stats/heatmap` | Matriz data × grupo × volume (`date_from`, `date_to`; padrão 8 semanas; até 366 dias) com a lista de grupos. Período invertido → 422 `invalid_date_range`; longo demais → 422 `date_range_too_long` |
| GET | `/profiles/availability` | `?username=`: `{username, available}` (nome do próprio usuário conta como livre; fora do formato → 422 `invalid_username`) |
| GET | `/profiles/search` | `?q=`: perfis cujo `username` começa com `q` ou cujo nome de exibição contém `q`, até 20 |
| GET | `/profiles` | `?pubkeys=a&pubkeys=b` (até 100): perfis dessas chaves, para nome e foto no feed |
| GET | `/profiles/{username}` | Perfil público pelo nome (com ou sem `@`); inexistente → 404 |
| GET | `/.well-known/nostr.json` | NIP-05 (fora de `/api/v1`, público, CORS `*`): `?name=ana` → `{"names": {"ana": "<pubkey hex>"}}` |
| POST | `/media` | Envia foto (multipart, campo `file`): JPEG/PNG/WebP até 5 MB, recodificada como WebP **sem EXIF/GPS**, lado maior até 1600 px. 201 com `{url, mime_type, width, height, size_bytes, sha256}` para a tag `imeta`. > 5 MB → 413; outro formato → 415 |
| GET | `/media/{arquivo}` | Foto pública (fora de `/api/v1`), com cache longo |
| GET | `/social/likes` | Curtidas por treino publicado (`?event_ids=a&event_ids=b`, até 100): `[{event_id, count, liked_by_me}]`. Vem do cache `likes` do worker (pode atrasar um ciclo); id fora do formato → 422 `invalid_event_id`; mais de 100 → 422 `too_many_event_ids` |

Limites de série (RN-07): carga 0–1000 kg, repetições 1–500, RPE 1–10 (opcional), tipo `warmup` / `normal` / `failure`. Treino de outro usuário responde **404**, igual a um inexistente.

`visibility`, `publish_status` e `d_tag` só mudam pelas rotas de publicação, nunca pelo `PATCH`. O backend não assina nem recebe chave privada: os corpos de `publication*` recusam qualquer campo extra (422). Os eventos registrados ficam em `shared_events` (um por publicação); o treino expõe só o `d_tag`.

## Erros

Toda resposta de erro segue `{"detail": "mensagem em português", "code": "identificador_estavel"}`. Erros de validação (422) também trazem `errors`, com o campo e o motivo.
