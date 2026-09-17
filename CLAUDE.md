# OpenLift

App de registro de treino de musculação com histórico, dashboard e mapa de calor de volume por grupo muscular, cuja camada social roda sobre o protocolo aberto **NOSTR** — sem que o usuário precise lidar com chaves criptográficas.

> OpenLift é um app de treino sobre protocolo aberto: o histórico do usuário é dele, publicável e legível por qualquer cliente compatível, e não propriedade da plataforma.

Projeto acadêmico da disciplina de Produto de Software (turma S06-2026-2).

**Fonte única de contexto:** [`docs/CONTEXTO.md`](docs/CONTEXTO.md) — decisões (ADRs), requisitos, calendário, riscos, o que falta. Se algo aqui conflitar com lá, `docs/CONTEXTO.md` vence; corrija aqui depois.

## Estrutura do repositório

```
OpenLift/
├── app/            # Frontend Flutter (mobile + web)
├── api/            # Backend FastAPI + PostgreSQL
├── infra/docker/   # docker-compose + Dockerfiles
├── design/         # Wireframes
├── docs/           # ADRs, requisitos, runbooks, contexto
└── .github/        # Workflows de CI
```

## Stack

- **Frontend:** Flutter, Riverpod, go_router
- **Backend:** Python 3.12, FastAPI, SQLAlchemy 2.0, Alembic, PostgreSQL 16, Pydantic v2
- **Protocolo social:** NOSTR (evento de treino em `kind 1301`, rascunho NIP-101e)
- **DevOps:** Docker Compose, GitHub Actions, ruff/black, flutter analyze

## Como rodar

```bash
# Backend + banco
cd infra/docker
docker compose up -d

# Frontend
cd app
flutter pub get
flutter test
flutter run -d chrome
```

## Boas práticas do projeto

Estas regras valem para qualquer contribuidor — humano ou agente de IA.

### Issues e branches

- **Toda tarefa nasce de uma issue.** Sem issue, a tarefa não existe (nem entra no board).
- **Uma issue, uma branch, um PR.** Não junte múltiplas issues ou mudanças não relacionadas num único commit ou PR — quanto mais atômico, melhor.
- Nomeie a branch pelo tipo e assunto da issue: `docs/claude-md`, `feat/nome-curto`, `fix/nome-curto`, `chore/nome-curto`.
- Commits seguem [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `style:`, `refactor:`, `test:`, `chore:`.

### Pull Requests

- Todo merge em `main` é via PR com **ao menos 1 aprovação**.
- PR referencia a issue que resolve (`Closes #N`).
- Se o PR usou IA para gerar código, declare: ferramenta/modelo usado, o que foi gerado, o que foi revisado/alterado.

### Definition of Done

Uma história só está pronta quando:

1. Código em `main` via PR revisado por outra pessoa
2. Lint passando (`ruff`, `black`, `flutter analyze`)
3. Teste automatizado cobrindo o caminho principal e os critérios de aceite
4. CI verde
5. QA validou contra o critério de aceite escrito **antes** da sprint
6. Documentação atualizada se mudou comportamento ou instalação
7. Uso de IA declarado no PR (se houver)

### Uso de IA

- **IA gera, humano é responsável.** "A IA escreveu" nunca é explicação aceitável para um bug.
- Nunca colar segredo, chave privada ou dado pessoal em prompt.
- Código gerado sem teste não é aceito.
- Escopo pequeno: uma tarefa, um arquivo, contexto explícito por vez — não peça "implementa a feature inteira".
- IA é ferramenta de desenvolvimento, nunca feature do produto (ver ADR-008 em `docs/adr/`).

### Decisões já fechadas

Os ADRs em `docs/adr/` **não se reabrem sem discussão no grupo**. Se uma tarefa parecer contradizer um ADR existente, pare e pergunte antes de implementar — não decida por conta própria.
