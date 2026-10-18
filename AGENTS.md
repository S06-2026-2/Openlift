# AGENTS.md — OpenLift

Instruções para agentes de IA (Claude Code, Gemini, Copilot, Cline, Codex) que trabalham neste repositório. Vale junto com o [`CLAUDE.md`](CLAUDE.md) (regras do time) e o [`docs/CONTEXTO.md`](docs/CONTEXTO.md) (fonte única de contexto). Em caso de conflito, `docs/CONTEXTO.md` e os ADRs em [`docs/adr/`](docs/adr/) vencem.

> **Antes de qualquer tarefa:** leia a issue, confira se ela contradiz algum ADR e trabalhe só no escopo dela. Na dúvida, **pergunte** em vez de decidir.

## O produto em uma frase

App de registro de treino de musculação (histórico, dashboard, mapa de calor de volume por grupo muscular) cuja camada social roda sobre o protocolo aberto **NOSTR**, sem que o usuário precise lidar com chaves criptográficas.

## Regras invioláveis

Quebrar qualquer uma delas é motivo para o PR ser recusado, mesmo com testes passando.

1. **A chave privada NOSTR nunca vai para o backend.** Nem em requisição HTTP, nem em log, nem em telemetria, nem em mensagem de erro, nem em teste (RNF-01, [ADR-0006](docs/adr/0006-custodia-da-chave-por-plataforma.md)). O backend só conhece o `npub`.
2. **Evento de treino é `kind 1301`**, com as tags do mini-NIP em `docs/nips/` e a tag `alt` (NIP-31) obrigatória. **Nunca publique treino como `kind 1`** (ADR-003). Se `docs/nips/` ainda não existir, não invente tags: pare e avise.
3. **ADR aceito não se reabre.** Se a tarefa parecer contradizer um ADR, pare e pergunte. Mudança de decisão é um ADR novo que substitui o antigo, aprovado pelo grupo.
4. **Nada social existe só no Postgres.** Like, contagem e ranking vêm de evento assinado; as tabelas de agregação são cache reconstruível por replay ([ADR-0004](docs/adr/0004-onde-o-dado-vive.md)).
5. **Escopo pequeno.** Uma issue, uma branch, um PR. Não junte mudanças não relacionadas, não refatore "de brinde", não adicione feature que a issue não pede.
6. **IA é ferramenta, nunca feature.** Nada de IA dentro do produto ([ADR-0008](docs/adr/0008-ia-como-ferramenta-de-desenvolvimento.md)).
7. **Nunca coloque segredo, chave ou dado pessoal** em código, prompt, log ou teste. O CI roda gitleaks.
8. **Código sem teste não entra.** Todo comportamento novo vem com teste do caminho principal e dos critérios de aceite.
9. **Sem geolocalização** de nenhum tipo (RNF-12, [ADR-0009](docs/adr/0009-mapa-de-check-in-fora-do-escopo.md)).

## Estrutura

```
OpenLift/
├── app/                 Frontend Flutter (web + APK)
│   ├── lib/core/        rede (Dio), roteador (go_router), tema, storage, utils
│   ├── lib/features/    auth · workouts · dashboard · social  (data / domain / presentation)
│   ├── lib/shared/      widgets do design system (AppButton, AppTextField, AppShell...)
│   └── test/            testes de widget e unidade; fakes em test/helpers/
├── api/                 Backend FastAPI
│   ├── app/api/v1/      rotas finas (auth, exercises, workouts)
│   ├── app/services/    regras de negócio
│   ├── app/domain/      models SQLAlchemy + schemas Pydantic
│   ├── app/core/        config, segurança (JWT/bcrypt), erros
│   ├── app/infra/       banco, seed
│   ├── alembic/         migrations
│   └── tests/           pytest (SQLite em memória) + tests/integration (Postgres)
├── infra/docker/        docker-compose (Postgres + API + Adminer)
├── docs/                CONTEXTO, adr/, qa/, ia/
├── .agents/skills/      skills deste projeto (ver abaixo)
└── .github/workflows/   CI (lint, testes, gitleaks, commitlint) e CD
```

## Stack

- **Frontend:** Flutter, Riverpod (`AsyncNotifier`), go_router, Dio, flutter_secure_storage.
- **Backend:** Python 3.12, FastAPI, SQLAlchemy 2.0, Alembic, Pydantic v2, PostgreSQL 16.
- **Protocolo:** NOSTR — `kind 1301` (treino), `kind 7` (like, NIP-25), `kind 3` (follow).
- **Qualidade:** ruff, black, mypy, pytest-cov, flutter analyze, flutter test, gitleaks, commitlint.

## Comandos

```bash
# Subir tudo
cd infra/docker && docker compose up -d
docker compose run --rm api alembic upgrade head
docker compose run --rm api python -m app.infra.db.seed

# Backend: mesma bateria do CI (de dentro de infra/docker)
docker compose run --rm --no-deps -e ENV=testing -e DATABASE_URL=sqlite:///:memory: api \
  sh -c "ruff check . && black --check . && mypy . && pytest --cov=app"

# Frontend
cd app && flutter pub get && flutter analyze && flutter test
flutter run -d chrome
```

`flutter analyze` quebra quando o caminho do projeto tem acento (bug de ambiente). No CI funciona normalmente.

## Convenções

### Gerais
- **Commits:** Conventional Commits (`feat(api): …`, `fix: …`, `docs: …`). O CI recusa mensagem fora do padrão.
- **Branches:** `feat/…`, `fix/…`, `docs/…`, `chore/…`, `ci/…`, `style/…`.
- **PR:** template em `.github/pull_request_template.md`, com `Closes #N` e a declaração de uso de IA (ferramenta, o que gerou, o que a pessoa revisou). Merge por squash; o título do PR vira o commit.
- **Idioma:** código e identificadores em inglês; comentários, mensagens ao usuário, docs e commits em português.

### Backend
- Rotas finas em `app/api/v1/`; regra de negócio em `app/services/`; validação em `app/domain/schemas/`.
- Erros sempre no formato `{"detail": "frase em português", "code": "identificador_estavel"}`: lance `ApiError(status, detail, code)` de `app/core/errors.py`, nunca `HTTPException` solta. Documente com `error_responses()` de `app/api/responses.py`.
- Dependências: `DbSession` e `CurrentUser` de `app/api/deps.py`. Query params com `Annotated[..., Query(...)]`.
- **Isolamento por usuário:** toda consulta de dado do usuário filtra por `current_user.id`; recurso de outra pessoa responde **404** (não vaza existência).
- Limites do RN-07 no schema: carga 0–1000 kg, repetições 1–500, RPE 1–10.
- Model novo: importar em `app/domain/models/__init__.py`, gerar migration com `--autogenerate` e **revisar o script** (CHECK constraints são escritos à mão; FKs com nome explícito).

### Frontend
- Camadas por feature: `data/` (repository + Dio) → `domain/` (models, validadores) → `presentation/` (controller Riverpod + telas).
- Erros de rede viram `ApiException` com mensagem humana; a UI nunca mostra stack trace.
- Use os widgets de `lib/shared/widgets/` e o tema de `AppTheme`; não crie cores soltas.
- Rotas em `AppRoutes`; as 4 áreas principais ficam dentro da `AppShell`.
- Testes de widget sobem o `OpenLiftApp` com `ProviderScope` e fakes de `test/helpers/` (sem rede, sem plugin de plataforma).

## Skills

Instruções passo a passo para tarefas recorrentes, em [`.agents/skills/`](.agents/skills/). Cada skill é uma pasta com `SKILL.md` (frontmatter `name` + `description`) e um exemplo. **Quando a tarefa bater com uma skill, leia o `SKILL.md` dela antes de começar.**

| Skill | Quando usar |
|---|---|
| [`criar-endpoint-fastapi`](.agents/skills/criar-endpoint-fastapi/SKILL.md) | Nova rota na API |
| [`generate-tests`](.agents/skills/generate-tests/SKILL.md) | Testes pytest do backend |
| [`gerar-teste-flutter`](.agents/skills/gerar-teste-flutter/SKILL.md) | Testes de widget/unidade do app |
| [`validar-evento-nostr`](.agents/skills/validar-evento-nostr/SKILL.md) | Conferir um evento NOSTR (estrutura, assinatura, mini-NIP) |
| [`revisar-pr`](.agents/skills/revisar-pr/SKILL.md) | Revisar um PR contra as regras do projeto |
| [`escrever-adr`](.agents/skills/escrever-adr/SKILL.md) | Rascunhar um ADR de decisão já tomada |

## Uso de IA

- **IA gera, humano é responsável.** "A IA escreveu" nunca explica um bug.
- Registre o uso relevante em [`docs/ia/registro.md`](docs/ia/registro.md).
- Teste gerado por IA só entra depois de revisado (e aprovado pelo QA quando for critério de aceite).
