# Subir o ambiente

Do zero até o app abrindo no Chrome, falando com a API e o banco.

## Pré-requisitos

| Ferramenta | Versão | Para quê |
|---|---|---|
| Docker Desktop | qualquer recente, **aberto** | Postgres + API + Adminer |
| Flutter | 3.x (canal stable) | App |
| Git | qualquer | — |
| Python 3.12 | só se for rodar `pytest`/`alembic` fora do Docker ou usar o pre-commit | — |

## 1. Backend e banco

```bash
cd infra/docker
docker compose up -d --build
docker compose run --rm api alembic upgrade head          # cria/atualiza as tabelas
docker compose run --rm api python -m app.infra.db.seed   # biblioteca de exercícios
```

> **PowerShell (Windows):** não use `&&` para encadear comandos; ele não existe no PowerShell 5.1. Rode um por linha ou separe com `;`.

O seed é idempotente: rodar de novo responde "0 criados" e não duplica nada.

### Conferir

| O quê | Onde | Esperado |
|---|---|---|
| API viva e falando com o banco | http://localhost:8000/health | `{"status":"ok"}` |
| Versão e ambiente | http://localhost:8000/version | `env: development` |
| Swagger | http://localhost:8000/docs | Lista de rotas; **Authorize** com o `access_token` do login |
| Banco | http://localhost:8080 (Adminer) | Sistema **PostgreSQL**, servidor `db`, usuário/senha/banco `openlift` |

No Adminer, o servidor é `db` (nome do serviço no compose), e não `localhost`.

## 2. App

```bash
cd app
flutter pub get
flutter run -d chrome
```

O app usa `http://localhost:8000/api/v1` por padrão. Para outra API:

```bash
flutter run -d chrome --dart-define=API_URL=http://192.168.0.10:8000/api/v1
```

## 3. Testes (mesma bateria do CI)

```bash
# Backend, de dentro de infra/docker (não precisa do Postgres: usa SQLite em memória)
docker compose run --rm --no-deps -e ENV=testing -e DATABASE_URL=sqlite:///:memory: api \
  sh -c "ruff check . && black --check . && mypy . && pytest --cov=app"

# Frontend
cd app
flutter analyze
flutter test
```

O `-e ENV=testing -e DATABASE_URL=...` é necessário porque o compose injeta `ENV=development` e a URL do Postgres no container.

## 4. Resetar o banco

Apaga **todos** os dados locais (contas e treinos de teste) e recomeça do zero:

```bash
cd infra/docker
docker compose down -v        # o -v apaga o volume do Postgres
docker compose up -d
docker compose run --rm api alembic upgrade head
docker compose run --rm api python -m app.infra.db.seed
```

Para desfazer só a última migration: `docker compose run --rm api alembic downgrade -1`.

## 5. Parar

```bash
cd infra/docker
docker compose down           # para os containers e mantém os dados
```

Se o app foi aberto com `flutter run`, pressione `q` no terminal dele.
