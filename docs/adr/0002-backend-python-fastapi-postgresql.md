# ADR-0002 — Back-end em Python, FastAPI e PostgreSQL

- **Status:** Aceito
- **Data:** 17/09/2026 (registrado em arquivo em 17/10/2026)
- **Requisitos relacionados:** RF-01, RF-54, RF-55, RF-56, RNF-10

## Contexto

O back-end cuida de tudo que o NOSTR não faz: conta do usuário, treino privado (séries, carga, RPE), histórico e agregações (volume, heatmap, ranking). O time tem cerca de 6 h por semana por pessoa, então a stack precisa ser algo que o time já domina, com pouca cerimônia e boa documentação automática para a entrega acadêmica.

## Decisão

- **Python 3.12 + FastAPI** para a API, em camadas (`api` → `services` → `domain`/`infra`).
- **PostgreSQL 16** como banco.
- **SQLAlchemy 2.0 + Alembic** para modelos e migrations.
- **Pydantic v2** para validação de entrada e saída.
- Ambiente sobe com `docker compose up` (Postgres + API + Adminer).

## Alternativas consideradas

- **Node.js (Express/NestJS)** — mesma linguagem de alguns clientes NOSTR, mas o time tem mais domínio de Python e perderia tempo em ferramentas novas.
- **Django + DRF** — mais completo, porém mais pesado e opinativo do que o necessário para uma API pequena; a OpenAPI automática do FastAPI sai de graça.
- **Banco NoSQL / só relay** — não responde bem a consultas agregadas ("volume por grupo muscular na semana") e não tem integridade relacional para treino e série. Ver [ADR-0004](0004-onde-o-dado-vive.md).

## Consequências

- OpenAPI/Swagger gerado automaticamente em `/docs`, usado na entrega e no teste manual (RF-56).
- Migrations versionadas: todo model novo precisa ser importado em `app/domain/models/__init__.py` para o `--autogenerate` enxergar, e o script gerado é sempre revisado.
- Testes rodam em SQLite em memória (rápidos) e há testes de integração contra Postgres real.
- Lint e tipagem no CI: `ruff`, `black`, `mypy` e `pytest`.
