# Subir o ambiente

Do zero até o app abrindo no Chrome, falando com a API e o banco.

## Pré-requisitos

| Ferramenta | Versão | Para quê |
|---|---|---|
| Docker Desktop | qualquer recente, **aberto** | Postgres + API + worker NOSTR + Adminer |
| Flutter | 3.x (canal stable) | App |
| Git | qualquer | — |
| Python 3.12 | só se for rodar `pytest`/`alembic` fora do Docker ou usar o pre-commit | — |

## 1. Backend e banco

```bash
cd infra/docker
docker compose up -d --build
```

Só isso (OPS-07, RNF-10). Ao subir, a API aplica as migrations (`alembic upgrade head`) e roda o seed da biblioteca de exercícios, pelo `infra/docker/entrypoint.sh`. O serviço `worker` (sincronização NOSTR, ADR-0011) sobe depois que a API responde `/health`. Para acompanhar:

```bash
docker compose ps            # api "healthy", worker "Up"
docker compose logs -f api   # logs em JSON, uma linha por requisição
```

Os relays vêm de `NOSTR_RELAYS` do ambiente ou da lista padrão do compose. Os comandos manuais continuam funcionando, se precisar:

```bash
docker compose run --rm api alembic upgrade head
docker compose run --rm api python -m app.infra.db.seed
```

> **PowerShell (Windows):** não use `&&` para encadear comandos; ele não existe no PowerShell 5.1. Rode um por linha ou separe com `;`.

O seed é idempotente: subir de novo responde "0 criados" e não duplica nada.

### Conferir

| O quê | Onde | Esperado |
|---|---|---|
| API viva, banco e worker | http://localhost:8000/health | `"status":"ok"`, `"database":"ok"` e `worker.status` `ok` depois do 1º ciclo (`unknown` se o worker não subiu) |
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

### Android (celular via USB)

Precisa do Android SDK (`flutter doctor` mostra o que falta).

1. No celular, ative as *Opções do desenvolvedor* (Configurações → Sobre o telefone → toque 7× em "Número da versão") e ligue a *Depuração USB*.
2. Conecte o cabo, aceite a permissão no celular e confira com `adb devices`.
3. Faça o `localhost` do celular apontar para o seu PC e rode:

```bash
adb reverse tcp:8000 tcp:8000
cd app
flutter run
```

Sem cabo (Wi-Fi), aponte direto para o IP do PC: `flutter run --dart-define=API_URL=http://<ip-do-pc>:8000/api/v1`.

### Windows (desktop)

```bash
cd app
flutter run -d windows
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
docker compose up -d          # migrations e seed rodam sozinhos na subida
```

Para desfazer só a última migration: `docker compose run --rm api alembic downgrade -1`.

## Staging no Railway

A imagem da API publicada no GHCR usa o mesmo entrypoint: a cada deploy, o serviço da API aplica as migrations e o seed antes de subir o uvicorn. O worker precisa de um **segundo serviço** no Railway, configurado à mão no painel:

| Campo | Valor |
|---|---|
| Imagem | a mesma do serviço da API (`openlift-api`) |
| Start command | `python -m app.worker` |
| Variáveis | as mesmas da API (`DATABASE_URL`, `NOSTR_RELAYS`...) **mais** `RUN_MIGRATIONS=false` |

Sem esse serviço, o `/health` do staging mostra `worker.status: unknown` e os likes não são projetados.

## 5. Parar

```bash
cd infra/docker
docker compose down           # para os containers e mantém os dados
```

Se o app foi aberto com `flutter run`, pressione `q` no terminal dele.
