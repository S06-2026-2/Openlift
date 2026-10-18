# OpenLift

App de treino que registra histórico de exercícios, mostra dashboards e mapa de calor de volume por grupo muscular, e permite compartilhar treinos e artigos na rede social descentralizada [NOSTR](https://nostr.com/) — sem que o usuário precise lidar com chaves criptográficas.

Projeto acadêmico da disciplina de Produto de Software.

**Contexto completo do projeto** (decisões, requisitos, calendário, riscos, pendências): [`docs/CONTEXTO.md`](docs/CONTEXTO.md).

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

## Segurança: segredos no repositório

Todo PR passa por dois checks além do lint e dos testes:

- **Gitleaks** ([`security.yml`](.github/workflows/security.yml)): procura chaves, tokens e senhas nos commits do PR. Se achar, o PR fica vermelho. Isso protege o RNF-01: chave privada (`nsec`) nunca entra no repositório.
- **Commitlint** ([`commitlint.yml`](.github/workflows/commitlint.yml)): todo commit do PR precisa seguir Conventional Commits (`feat: …`, `fix(api): …`). Uma mensagem como `foo` é rejeitada.

Para rodar o gitleaks antes de abrir o PR, [instale o binário](https://github.com/gitleaks/gitleaks#installing) e rode na raiz: `gitleaks git --config .gitleaks.toml --redact .`

### Se o gitleaks apontar um segredo

1. **É segredo real** (senha, token, chave)? **Não libere.** Considere o segredo vazado, mesmo que o commit seja desfeito: troque-o na origem (gere outro token, troque a senha), remova do código, passe a ler de variável de ambiente (`api/.env`, que está no `.gitignore`) e avise no grupo.
2. **É falso positivo** (exemplo de documentação, valor de teste, credencial de dev local)? Escolha o menor escopo possível:
   - **Uma linha:** adicione o comentário `# gitleaks:allow` no fim da linha.
   - **Um padrão recorrente:** adicione uma regex em `regexes` no [`.gitleaks.toml`](.gitleaks.toml), com um comentário explicando por que é seguro.
   - **Um arquivo inteiro** (só para arquivos de exemplo, como `api/.env.example`): adicione o caminho em `paths`.
3. Explique a liberação na descrição do PR, para o revisor conferir.
