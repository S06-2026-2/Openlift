# Registro de uso de IA

Registro de onde e como a IA foi usada no desenvolvimento do OpenLift ([ADR-0008](../adr/0008-ia-como-ferramenta-de-desenvolvimento.md)). Serve para três coisas: a declaração da Definition of Done (item 7), a avaliação crítica do relatório final e a memória do que funcionou ou não.

**Como registrar:** uma linha por PR (ou por tarefa relevante feita com IA), adicionada no próprio PR. A coluna "O que a pessoa revisou" é de quem abriu o PR e precisa ser concreta ("conferi o filtro por usuário e rodei os testes"), nunca "revisei tudo". A coluna "Avaliação" registra onde a IA errou ou acertou, para o capítulo de avaliação crítica.

**Fonte das linhas:** a seção "Uso de IA" de cada PR e os trailers dos commits. Onde o PR não declarou a ferramenta, a linha diz **"não declarado"** — quem abriu o PR completa. Uma ferramenta não é atribuída a ninguém sem declaração.

## Ferramentas em uso

| Pessoa | Ferramenta / modelo | Onde está declarado |
|---|---|---|
| Luiz | Claude Code (Claude Opus 5.5) | PRs #39–#41, #43–#45, #51–#55 e IA-01 |
| Pedro | Antigravity (Claude Sonnet 5.5) | PR #37 |
| Rodrigo | ChatGPT | PRs #46 e #49 |
| Yam | GitHub Copilot Autofix; Claude Code (Claude Opus 5.5) | Trailer `Co-authored-by: Copilot Autofix` em 2 commits do PR #11; PR do NOSTR-01 (#22) |
| Matheus | — | Nenhum uso registrado até agora |

**Agente de relatório de CI:** o `ci-report-agent.yml` na `main` coleta os artefatos de lint e testes, e o perfil do agente está em `.github/agents/ci-reporter.agent.md` (formato de agente customizado do GitHub Copilot). A chamada ao modelo ainda não está na `main`: está em teste na branch `feat/copilot-reporter` (issue #20).

## Registro

| Data | Quem | Ferramenta | PR / issue | O que a IA gerou | O que a pessoa revisou/alterou | Avaliação |
|---|---|---|---|---|---|---|
| 16/09/2026 | Rodrigo | Não declarado | #1 | Pipelines de CI do front e do back com upload dos relatórios de teste | Não declarado | — |
| 17/09/2026 | Rodrigo | Não declarado | #2 (fechado sem merge) | Agente de relatório de implementações | Não declarado | O conteúdo (`ci-reporter.agent.md`, `ci-report/SKILL.md`, `ci-report-agent.yml`) entrou na `main` pelo PR #3 e foi refeito nos #18/#19; o #2 ficou obsoleto |
| 17/09/2026 | Pedro | Não declarado | #3 | Skill `generate-tests`, fixtures do `conftest.py` e testes do Sprint 1 do backend | Não declarado | A tabela de cobertura da skill segue o roadmap antigo (até 80%), não o [ADR-0010](../adr/0010-gates-de-qualidade-progressivos.md) |
| 17/09/2026 | Yam | GitHub Copilot Autofix | #11 | Ajustes em 2 trechos do `docs/CONTEXTO.md` (fixtures/skills e fonte do escopo) | Não declarado | — |
| 07/10/2026 | Rodrigo | Não declarado | #18, #19 | Reporter refeito para coletar melhor os artefatos do front e do back; correção do repositório no job | Não declarado | — |
| 14/10/2026 | Rodrigo | Não declarado | #17 | Melhoria dos artefatos de CI para o relatório | Não declarado | — |
| 14/10/2026 | Pedro | Antigravity (Claude Sonnet 5.5) | #37 (BE-01) | `security.py` (hash de senha e JWT), campos novos em `config.py` e 17 testes em `test_security.py` | Revisou o código gerado e executou os testes automatizados | — |
| 14/10/2026 | Luiz | Claude Code (Opus 5.5) | #39 (FE-01) | Camada de rede (Dio, refresh em 401), storage de sessão, `ApiException` e testes | Rodou `flutter analyze` e `flutter test`; testou login e sessão no Chrome contra a API | O primeiro `switch` sobre `DioExceptionType` não era exaustivo e quebrou o analyze; trocado por `if`s |
| 14/10/2026 | Luiz | Claude Code (Opus 5.5) | #40 (FE-02) | Telas de login/cadastro, `AuthController` e testes de widget | Testou cadastro, login, erro de senha e "Sair" no Chrome | — |
| 14/10/2026 | Luiz | Claude Code (Opus 5.5) | #41 (FE-03) | Novo Treino, histórico com filtros, modelos e validadores | Testou criar, editar, filtrar e excluir treino no Chrome | O método `update` do controller conflitou com `AsyncNotifierBase.update` (renomeado para `edit`). Botão estourava a largura no teste de widget; corrigido com `Flexible` + reticências |
| 17/10/2026 | Luiz | Claude Code (Opus 5.5) | #43 (BE-02) | `auth_service`, rotas de auth, `get_current_user`, erros `{detail, code}`, CORS e testes | Rodou a bateria do CI no Docker e testou cadastro/login pelo app no Chrome | Achou que a fixture `auth_headers` gerava token sem `type`/`iat` e seria recusada; corrigida |
| 17/10/2026 | Luiz | Claude Code (Opus 5.5) | #44 (BE-03) | Models restantes, migration 2, seed idempotente, `GET /exercises` e testes | Rodou migrations e seed no Docker; conferiu a lista de exercícios no app | `--autogenerate` não cria FK com nome; migration revisada à mão para o downgrade funcionar |
| 17/10/2026 | Rodrigo | ChatGPT | #46 (TEST-02) | Testes de integração com PostgreSQL | Passou a executar as migrations na pipeline antes de rodar os testes | — |
| 17/10/2026 | Luiz | Claude Code (Opus 5.5) | #45 (BE-04) | CRUD de treinos e séries com isolamento por usuário, migration 3 e testes | Testou o CRUD de treinos pelo app no Chrome (o PowerShell recusou `&&`; comandos separados) | CHECK constraints não saem no `--autogenerate`; escritos à mão. Apontou o desalinhamento de RPE (app aceita 0, API exige 1–10) |
| 17/10/2026 | Rodrigo | ChatGPT | #49 (OPS-04) | Job de delivery: imagem Docker da API publicada no GHCR após merge na `main` | Verificou a publicação da imagem no GitHub Packages (GHCR) | — |
| 17/10/2026 | Luiz | Claude Code (Opus 5.5) | #51 (FE-04) | Redesign visual, `AppShell` (navegação inferior/lateral) e testes de navegação | Avaliou o visual no Chrome antes de abrir a issue e o PR | `dart format` reformatou arquivos fora do escopo; revertidos para manter o PR focado |
| 17/10/2026 | Luiz | Claude Code (Opus 5.5) | #52 (OPS-02) | Workflows de gitleaks e commitlint, `.gitleaks.toml`, seção do README | Configurou a branch protection (OPS-01) exigindo os checks `Gitleaks` e `Conventional Commits` | Trocou a `gitleaks-action` pelo binário (a action exige licença em repo de organização). O primeiro teste local do commitlint falhou por BOM do PowerShell, não pela regra |
| 17/10/2026 | Luiz | Claude Code (Opus 5.5) | #53 (OPS-03) | `api/.pre-commit-config.yaml` e seções Contribuindo/DoD/Escopo do README | Conferiu as seções novas do README | Bloqueio de commit mal formatado testado num repositório descartável |
| 17/10/2026 | Luiz | Claude Code (Opus 5.5) | #54 (DOC-01) | ADRs 0001, 0002 e 0004–0010 a partir do `CONTEXTO.md` §5 | Conferiu os ADRs contra a tabela do `CONTEXTO.md` §5 | Algumas "alternativas consideradas" não estavam no CONTEXTO e foram completadas; marcadas para o grupo revisar |
| 17/10/2026 | Luiz | Claude Code (Opus 5.5) | #55 (QA-01) | Critérios de aceite da Sprint 2 e checklist da Demo 3 | Conferiu os critérios contra a entrega da Sprint 2 no `CONTEXTO.md` §3 | Critérios do `kind 1301` deixados genéricos de propósito: as tags dependem do NOSTR-01 |
| 17/10/2026 | Luiz | Claude Code (Opus 5.5) | IA-01 (#34) | `AGENTS.md`, skills `criar-endpoint-fastapi`, `gerar-teste-flutter`, `validar-evento-nostr`, `revisar-pr` e `escrever-adr`, e este registro | Conferiu as regras invioláveis do `AGENTS.md` contra os ADRs | Exemplos das skills validados: Python com ruff/black/mypy, Dart com analyze + teste rodando. O registro inicial atribuía Gemini ao reporter sem evidência; corrigido |
| 19/10/2026 | Yam | Claude Code (Opus 5.5) | NOSTR-01 (#22) | Mini-NIP, JSON Schemas, exemplos assinados e ADR-0003, a partir do texto do NIP-101e (PR nostr-protocol/nips#1816) | Delegou as escolhas de tag ao agente, pedindo a opção mais fiel ao rascunho; a revisão do contrato é a aprovação do PR pelo grupo | O esboço de tags da issue #22 não batia com o NIP-101e; o agente seguiu o rascunho e registrou o descarte no ADR. Exemplos assinados com chave descartável e conferidos por uma implementação independente (referência BIP-340 em Python) e por 15 casos negativos contra o schema |
| 27/10/2026 | Luiz | Claude Code (Opus 5.5) | FE-04 (#83) | NIP-19 (`npub`/`nsec`), `NostrIdentityService`, sincronização do `npub` depois do login, importação de `nsec` em Configurações avançadas, teste do RNF-01 e notas nos ADRs 0005/0006 | _a preencher_ | O `npub` esperado para o `nsec` de teste estava errado na primeira versão do teste; corrigido calculando com uma implementação independente (`coincurve`). Os testes de tela travaram porque o login esperava a sincronização com o armazenamento seguro real; a sincronização passou para segundo plano, o que também deixa o login mais rápido |
| 28/10/2026 | Luiz | Claude Code (Opus 5.5) | FE-05 (#84) | `NostrRelayService` (WebSocket, `OK` por relay), `WorkoutPublisher` (33401 + 1301 assinados no aparelho), status e "Tentar novamente" no histórico, seletor Privado/Publicado, consentimento na 1ª publicação, republicação após edição e testes | _a preencher_ | A pergunta "Publicar a nova versão?" vinha depois do PATCH, e a tela era reconstruída com o diálogo aberto; o teste de widget pegou e a pergunta passou para antes de salvar. Conferido também contra um relay `nostr-rs-relay` local (Docker): publicou, leu de volta com `REQ` e as assinaturas validaram, sem usar relay público |
| 28/10/2026 | Luiz | Claude Code (Opus 5.5) | FE-06 (#85) | Leitura nos relays (`REQ` até o `EOSE`, reconexão com backoff, deduplicação por `id`), `NetworkWorkoutsService` com verificação de assinatura, aba "Da rede" com o `npub` do aparelho e campo para o `npub` de outra pessoa, e testes (incl. evento adulterado e aparelho A → B) | _a preencher_ | Contra um relay local real, a leitura levou 7,7 s porque o relay fora do ar era tentado 3 vezes com o tempo limite cheio; as novas tentativas passaram a caber no tempo limite total. O fake de relay respeitava o filtro, o que tornava inútil o teste de evento de autor não pedido; ganhou um modo que ignora o filtro |

## Lições até agora

Resumo para a avaliação crítica do relatório final. Atualize a cada sprint.

- **Escopo pequeno funciona.** Pedir uma issue por vez, com o critério de aceite colado, gerou PRs revisáveis.
- **A IA erra no detalhe de ferramenta, não na arquitetura.** Os erros registrados foram de API de biblioteca (Dio, Riverpod), de comportamento do Alembic e de ambiente Windows (acento no caminho, BOM, encoding do console). Todos apareceram ao rodar lint e testes, nunca em revisão de olho.
- **Rodar a bateria do CI localmente antes do PR** pegou todos os erros acima. Sem isso, eles teriam chegado ao revisor.
- **Declaração incompleta é o ponto fraco do time.** Os PRs anteriores ao template (#1, #3, #17–#19) não dizem qual ferramenta foi usada. Desde o template (#37 em diante), todos declaram.
- **Decisão continua sendo humana.** Onde o `CONTEXTO.md` diz que algo depende do grupo (mini-NIP, alternativas de ADR), a IA deixou o ponto em aberto em vez de decidir.
