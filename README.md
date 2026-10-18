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
# Variáveis de ambiente (só para rodar pytest/alembic fora do Docker;
# no docker compose elas já vêm do compose)
cp api/.env.example api/.env

# Backend + banco de dados
cd infra/docker
docker compose up --build
docker compose run --rm api alembic upgrade head          # migrations
docker compose run --rm api python -m app.infra.db.seed   # biblioteca de exercícios

# Frontend
cd app
flutter pub get
flutter run -d chrome
```

Veja `api/.env.example` para as variáveis de ambiente e [`api/README.md`](api/README.md) para rotas, testes e migrations do backend.

## Contribuindo

Regras completas em [`CLAUDE.md`](CLAUDE.md) (valem para humanos e agentes de IA). O essencial:

- **Toda tarefa nasce de uma issue.** Uma issue, uma branch, um PR (`feat/…`, `fix/…`, `docs/…`, `chore/…`).
- Commits em [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `style:`, `refactor:`, `test:`, `chore:`.
- Merge em `main` só via PR com **ao menos 1 aprovação** de outra pessoa; o PR referencia a issue (`Closes #N`) e declara o uso de IA.
- ADRs em [`docs/adr/`](docs/adr/) não se reabrem sem discussão no grupo.

### Hooks locais (pre-commit)

O backend tem hooks de `ruff` e `black` que barram commit mal formatado antes de chegar no CI. Instale uma vez por clone, a partir da raiz do repositório:

```bash
pip install pre-commit
pre-commit install --config api/.pre-commit-config.yaml
```

A partir daí, todo `git commit` que toca `api/` roda os dois hooks. Se eles corrigirem algum arquivo, o commit é interrompido: confira a mudança, faça `git add` de novo e repita o commit. Para rodar em tudo manualmente: `pre-commit run --all-files --config api/.pre-commit-config.yaml`.

### Definition of Done

Uma história só está pronta quando:

1. Código em `main` via PR revisado por outra pessoa
2. Lint passando (`ruff`, `black`, `flutter analyze`)
3. Teste automatizado cobrindo o caminho principal e os critérios de aceite
4. CI verde
5. QA validou contra o critério de aceite escrito **antes** da sprint
6. Documentação atualizada se mudou comportamento ou instalação
7. Uso de IA declarado no PR (se houver)

## Escopo

**Obrigatório:** registro de treino (exercício, série, carga, repetições, RPE opcional) · histórico com filtro por data e exercício · identidade NOSTR gerada localmente · publicar treino como evento no relay e ler treinos de outras pessoas · feed social com like · dashboard com estatística semanal e mapa de calor de volume por grupo muscular.

**Desejável** (entra se a sprint fechar antes): ranking social · artigos (NIP-23) · templates de treino · streak · export do histórico.

**Fora desta entrega** (documentado como evolução futura): mapa de check-in e qualquer localização · rastreio contínuo ao vivo · app publicado em loja · **qualquer IA dentro do produto** · mensagem direta entre usuários · dieta e macros · integração com wearables · vídeo e moderação de vídeo · pagamentos/zaps Lightning.

Detalhes e motivos em [`docs/CONTEXTO.md` §6](docs/CONTEXTO.md#6-escopo).

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
