# OpenLift

App de treino que registra histórico de exercícios, mostra dashboards e mapa de calor de volume por grupo muscular, e permite compartilhar treinos e artigos na rede social descentralizada [NOSTR](https://nostr.com/) — sem que o usuário precise lidar com chaves criptográficas.

Projeto acadêmico da disciplina de Produto de Software.

## Estrutura do repositório

```
OpenLift/
├── app/            # Frontend Flutter (mobile)
├── api/            # Backend FastAPI + PostgreSQL
├── infra/          # Docker Compose e Dockerfiles
├── .github/        # Workflows de CI/CD
└── implementation.md   # Plano de implementação (roadmap de 12 semanas)
```

## Plano de implementação

O roadmap completo de 12 semanas, dividido em 6 sprints (Frontend, Backend, DevOps e o plano de testes assistidos por IA), está em [`implementation.md`](implementation.md).

## Wireframes

Wireframes de baixa fidelidade das 5 telas núcleo (Login, Dashboard, Novo Treino, Feed Social, Perfil): [ver/editar no canvas](https://claude.ai/code/artifact/c7884706-27b6-4ee2-894c-95cf89851ffe) · fonte em [`design/wireframes/sprint-1/`](design/wireframes/sprint-1/).

## Rodando localmente

```bash
# Backend + banco de dados
cd infra/docker
docker compose up --build

# Frontend
cd app
flutter pub get
flutter run
```

Veja `api/.env.example` para as variáveis de ambiente necessárias.

## Stack

- **Frontend:** Flutter, Riverpod, go_router, dart_nostr
- **Backend:** FastAPI, SQLAlchemy 2.0, Alembic, PostgreSQL, Redis
- **Protocolo social:** NOSTR (NIP-01, NIP-23, NIP-25)
- **DevOps:** Docker, GitHub Actions, ruff/black/mypy, pytest, flutter_test
