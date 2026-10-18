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

## Erros

Toda resposta de erro segue `{"detail": "mensagem em português", "code": "identificador_estavel"}`. Erros de validação (422) também trazem `errors`, com o campo e o motivo.
