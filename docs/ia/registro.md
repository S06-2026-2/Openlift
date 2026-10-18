# Registro de uso de IA

Registro de onde e como a IA foi usada no desenvolvimento do OpenLift ([ADR-0008](../adr/0008-ia-como-ferramenta-de-desenvolvimento.md)). Serve para três coisas: a declaração da Definition of Done (item 7), a avaliação crítica do relatório final e a memória do que funcionou ou não.

**Como registrar:** uma linha por PR (ou por tarefa relevante feita com IA), adicionada no próprio PR. A coluna "O que a pessoa revisou" é de quem abriu o PR e precisa ser concreta ("conferi o filtro por usuário e rodei os testes"), nunca "revisei tudo". A coluna "Avaliação" registra onde a IA errou ou acertou, para o capítulo de avaliação crítica.

## Ferramentas em uso

| Ferramenta | Quem usa | Para quê |
|---|---|---|
| Claude Code (Claude Opus 5.5) | Luiz | Implementação de front e back, testes, documentação, CI |
| Gemini (GitHub Actions) — _confirmar_ | Rodrigo | Agente de relatório de CI (`ci-report-agent.yml`) |
| _a preencher_ | Pedro | Skill `generate-tests` e suítes de teste do backend |

Cada pessoa completa a sua linha com a ferramenta e o modelo que realmente usou.

## Registro

| Data | Quem | Ferramenta | PR / issue | O que a IA gerou | O que a pessoa revisou/alterou | Avaliação |
|---|---|---|---|---|---|---|
| 17/09/2026 | Pedro | _a preencher_ | `73d3bec` | Skill `generate-tests` e suítes de teste do backend | _a preencher_ | _a preencher_ |
| 07/10/2026 | Rodrigo | _a preencher_ | #18, #19 | Novo `ci-report-agent.yml` (relatório de CI com Gemini) | _a preencher_ | _a preencher_ |
| 14/10/2026 | Rodrigo | _a preencher_ | #17 | Artefatos de CI para o relatório | _a preencher_ | _a preencher_ |
| 14/10/2026 | Luiz | Claude Code (Opus 5.5) | #39 (FE-01) | Camada de rede (Dio, refresh em 401), storage de sessão, `ApiException` e testes | _a preencher_ | O primeiro `switch` sobre `DioExceptionType` não era exaustivo e quebrou o analyze; trocado por `if`s |
| 14/10/2026 | Luiz | Claude Code (Opus 5.5) | #40 (FE-02) | Telas de login/cadastro, `AuthController` e testes de widget | _a preencher_ | — |
| 14/10/2026 | Luiz | Claude Code (Opus 5.5) | #41 (FE-03) | Novo Treino, histórico com filtros, modelos e validadores | _a preencher_ | O método `update` do controller conflitou com `AsyncNotifierBase.update` (renomeado para `edit`). Botão estourava a largura no teste de widget; corrigido com `Flexible` + reticências |
| 17/10/2026 | Luiz | Claude Code (Opus 5.5) | #43 (BE-02) | `auth_service`, rotas de auth, `get_current_user`, erros `{detail, code}`, CORS e testes | _a preencher_ | Achou que a fixture `auth_headers` gerava token sem `type`/`iat` e seria recusada; corrigida |
| 17/10/2026 | Luiz | Claude Code (Opus 5.5) | #44 (BE-03) | Models restantes, migration 2, seed idempotente, `GET /exercises` e testes | _a preencher_ | `--autogenerate` não cria FK com nome; migration revisada à mão para o downgrade funcionar |
| 17/10/2026 | Luiz | Claude Code (Opus 5.5) | #45 (BE-04) | CRUD de treinos e séries com isolamento por usuário, migration 3 e testes | _a preencher_ | CHECK constraints não saem no `--autogenerate`; escritos à mão. Apontou o desalinhamento de RPE (app aceita 0, API exige 1–10) |
| 17/10/2026 | Luiz | Claude Code (Opus 5.5) | #51 (FE-04) | Redesign visual, `AppShell` (navegação inferior/lateral) e testes de navegação | _a preencher_ | `dart format` reformatou arquivos fora do escopo; revertidos para manter o PR focado |
| 17/10/2026 | Luiz | Claude Code (Opus 5.5) | #52 (OPS-02) | Workflows de gitleaks e commitlint, `.gitleaks.toml`, seção do README | _a preencher_ | Trocou a `gitleaks-action` pelo binário (a action exige licença em repo de organização). O primeiro teste local do commitlint falhou por BOM do PowerShell, não pela regra |
| 17/10/2026 | Luiz | Claude Code (Opus 5.5) | #53 (OPS-03) | `api/.pre-commit-config.yaml` e seções Contribuindo/DoD/Escopo do README | _a preencher_ | Bloqueio de commit mal formatado testado num repositório descartável |
| 17/10/2026 | Luiz | Claude Code (Opus 5.5) | #54 (DOC-01) | ADRs 0001, 0002 e 0004–0010 a partir do `CONTEXTO.md` §5 | _a preencher_ | Algumas "alternativas consideradas" não estavam no CONTEXTO e foram completadas; marcadas para o grupo revisar |
| 17/10/2026 | Luiz | Claude Code (Opus 5.5) | #55 (QA-01) | Critérios de aceite da Sprint 2 e checklist da Demo 3 | _a preencher_ | Critérios do `kind 1301` deixados genéricos de propósito: as tags dependem do NOSTR-01 |
| 17/10/2026 | Luiz | Claude Code (Opus 5.5) | IA-01 (#34) | `AGENTS.md`, skills `criar-endpoint-fastapi`, `gerar-teste-flutter`, `validar-evento-nostr`, `revisar-pr` e `escrever-adr`, e este registro | _a preencher_ | Exemplos das skills validados: Python com ruff/black/mypy, Dart com analyze + teste rodando |

## Lições até agora

Resumo para a avaliação crítica do relatório final. Atualize a cada sprint.

- **Escopo pequeno funciona.** Pedir uma issue por vez, com o critério de aceite colado, gerou PRs revisáveis. Pedir "a feature inteira" não foi necessário em nenhum momento.
- **A IA erra no detalhe de ferramenta, não na arquitetura.** Os erros registrados foram de API de biblioteca (Dio, Riverpod), de comportamento do Alembic e de ambiente Windows (acento no caminho, BOM, encoding do console). Todos apareceram ao rodar lint e testes, nunca em revisão de olho.
- **Rodar a bateria do CI localmente antes do PR** pegou todos os erros acima. Sem isso, eles teriam chegado ao revisor.
- **Decisão continua sendo humana.** Onde o `CONTEXTO.md` diz que algo depende do grupo (mini-NIP, alternativas de ADR), a IA deixou o ponto em aberto em vez de decidir.
