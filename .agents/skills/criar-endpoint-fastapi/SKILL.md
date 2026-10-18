---
name: criar-endpoint-fastapi
description: Criar uma rota nova na API do OpenLift (FastAPI) seguindo o padrão do projeto — rota fina, regra no service, schema Pydantic com limites, erro {detail, code}, isolamento por usuário, documentação no Swagger e testes pytest.
---

# Skill — criar endpoint FastAPI

Use quando a issue pede uma rota nova (ou uma mudança de contrato) em `api/`. Não use para mudar regra de negócio sem rota nova: aí o trabalho é só no service e nos testes.

## Antes de escrever código

1. Leia a issue e os critérios de aceite (e o `docs/qa/` da sprint, se houver).
2. Leia uma rota parecida que já existe, para copiar o estilo:
   - leitura simples: `api/app/api/v1/exercises.py` + `api/app/services/exercise_service.py`
   - CRUD com isolamento por usuário: `api/app/api/v1/workouts.py` + `api/app/services/workout_service.py`
3. Confira se o contrato bate com o que o app espera (`app/lib/features/*/data/*_repository.dart`).
4. Se a rota precisa de tabela ou coluna nova, faça a migration **antes** (ver "Banco" abaixo).

## Passo a passo

1. **Schema** em `api/app/domain/schemas/<recurso>.py`:
   - `XIn` (entrada), `XUpdate` (PATCH, campos opcionais), `XOut` (saída, `from_attributes=True`).
   - Limites com `Field(ge=..., le=...)` — RN-07: carga 0–1000 kg, repetições 1–500, RPE 1–10.
   - Exemplo para o Swagger em `json_schema_extra={"examples": [...]}`.
2. **Service** em `api/app/services/<recurso>_service.py`:
   - Funções recebem `db: Session` e, se o dado for do usuário, `user: User`.
   - **Toda consulta filtra por `user.id`.** Recurso de outra pessoa → 404, igual a inexistente.
   - Erros com `ApiError(status, "frase em português.", "codigo_estavel")` de `app/core/errors.py`. Nunca `HTTPException` solta.
3. **Rota** em `api/app/api/v1/<recurso>.py`:
   - Fina: valida entrada, chama o service, converte para `XOut`. Sem regra de negócio.
   - Dependências `DbSession` e `CurrentUser` de `app/api/deps.py` (login obrigatório, a não ser que a issue diga o contrário).
   - Query params com `Annotated[tipo, Query(...)]` (o ruff recusa `Query()` como default — B008).
   - `summary`, `description` e `responses=error_responses({...})` em todo decorator.
4. **Registro:** inclua o router em `api/app/api/v1/router.py` e, se for um grupo novo, a tag em `openapi_tags` no `api/app/main.py`.
5. **Testes** em `api/tests/test_<recurso>.py` (ver a skill `generate-tests`): caminho feliz, 401 sem token, 404 de outro usuário, 422 nos limites, e o formato `{detail, code}` dos erros.
6. **Documentação:** atualize a tabela de rotas em `api/README.md`.

## Banco

- Model em `api/app/domain/models/`, importado em `api/app/domain/models/__init__.py` (sem isso o autogenerate não enxerga).
- `docker compose run --rm api alembic revision --autogenerate -m "descricao"` e **revise o script**: CHECK constraints são escritos à mão e FKs precisam de nome explícito para o downgrade funcionar.
- Teste `upgrade` → `downgrade -1` → `upgrade` antes do PR.

## Validar

```bash
cd infra/docker
docker compose run --rm --no-deps -e ENV=testing -e DATABASE_URL=sqlite:///:memory: api \
  sh -c "ruff check . && black --check . && mypy . && pytest --cov=app"
```

Depois, abra `http://localhost:8000/docs`, use **Authorize** com o `access_token` do login e teste a rota na mão.

## Não faça

- Não coloque regra de negócio na rota.
- Não retorne model SQLAlchemy direto: sempre o schema `XOut`.
- Não devolva stack trace nem mensagem em inglês ao cliente.
- Não aceite chave privada NOSTR em nenhum payload (regra inviolável do `AGENTS.md`).
- Não crie endpoint social que grave like/contagem direto no Postgres sem evento assinado (ADR-0004).

## Exemplo

[`examples/exemplo_endpoint.py`](examples/exemplo_endpoint.py): schema + service + rota + teste de um recurso fictício, no padrão do projeto.
