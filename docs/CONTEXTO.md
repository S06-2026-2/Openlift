# OpenLift — Contexto do Projeto

**Atualizado:** 17/09/2026 · **Repo:** github.com/S06-2026-2/Openlift (branch `main`) · **Entrega final:** Demo 4, 03/12/2026

> **Para que serve este arquivo.** É a fonte única de contexto do projeto: o que o OpenLift é, o que já existe, o que foi decidido, o que falta fazer e o que ainda está aberto. Dois usos:
> 1. **Time** — leitura obrigatória antes de pegar tarefa. Se algo aqui estiver errado ou desatualizado, corrige aqui primeiro, depois no código.
> 2. **Agente de IA (Claude Code, Gemini, Copilot)** — cole ou aponte para este arquivo no início da sessão. Ele contém as decisões que o agente não deve reabrir sozinho.

---

## 1. O que é o OpenLift

App de registro de treino de musculação com histórico, dashboard e mapa de calor de volume por grupo muscular, cuja camada social roda sobre o protocolo aberto **NOSTR** — sem que o usuário precise lidar com chaves criptográficas.

Posicionamento de uma frase, para a defesa:

> OpenLift é um app de treino sobre protocolo aberto: o histórico do usuário é dele, publicável e legível por qualquer cliente compatível, e não propriedade da plataforma.

**Fonte histórica do escopo:** `openlift-ideacao_inicial.txt` (Drive, pasta `inatel/S06-Openlift Files`). A versão vigente para o time e os agentes é este arquivo; divergências devem ser resolvidas aqui primeiro.

---

## 2. Time e fronteiras

Cinco integrantes: Rodrigo Fraga da Costa, Pedro Henrique Fernandes Pereira, Luiz Otavio Ribeiro de Paiva, Matheus Rangel de Lima, Yam Sol Britto Bertamini.

Cada pessoa é dona de uma **fronteira** — decide, documenta e responde por ela — não de uma lista de tarefas soltas.

| Fronteira | Responsabilidade | Entrega principal |
|---|---|---|
| PO | Prioridade, escopo, board, roteiro das demos | Backlog vivo e decisão sobre corte de escopo |
| Dev NOSTR | Contrato de dados social | Módulo com interface estável que o front consome sem saber que é NOSTR por dentro |
| Back-end | Tudo que o NOSTR não faz | API FastAPI: identidade, treino, histórico, agregações |
| DevOps | Ambiente, automação e apoio ao front | `docker compose up` sobe tudo, CI verde, deploy de staging |
| QA | Critério de aceite e qualidade da demo | "Pronto quando..." escrito **antes** da sprint |
| Front-end | Experiência do usuário | Telas, em ordem rígida de prioridade |

**Duas observações de alocação que precisam ser resolvidas na reunião:**

- São seis fronteiras para cinco pessoas. O encaixe proposto é **PO acumular Dev NOSTR** (a decisão do schema de evento é caminho crítico e naturalmente de PO).
- **O front-end é o gargalo estrutural do projeto**: uma pessoa para registro de treino, feed e dashboard. Duas medidas valem como regra, não como favor: a ordem de construção é rígida (treino → feed → dashboard/heatmap) e ninguém pede tela fora de ordem; e o DevOps é o segundo par de mãos do front nas sprints de tela.

### Regra de ouro

**Este projeto não pode destruir as outras matérias de ninguém.** O plano assume **6 h por semana por pessoa**: 1 bloco de 2 h na segunda, 1 bloco de 3 h em dia livre, 1 h de reunião. Se alguém está estourando as 6 h com frequência, o escopo está errado, não a pessoa — avisa no grupo e a gente corta feature. Cortar escopo é decisão normal de PO; virar noite não é.

**Rituais:** reunião única de 45 min, segunda antes da aula (o que fiz / o que vou fazer / o que me trava). Resto é assíncrono. Regra das 24 h: ninguém fica travado mais de 24 h em silêncio. Se a tarefa não está no board do GitHub Projects, ela não existe.

---

## 3. Calendário — datas inegociáveis

Nenhuma sprint atravessa checkpoint.

| Sprint | Janela | Entrega | Checkpoint |
|---|---|---|---|
| **1** | 18/09 → 19/10 | Registro de treino ponta a ponta contra API real. ADR-003 (schema do evento) fechado na **primeira semana** | Auxílio 2 — 19/10 |
| **2** | 20/10 → 29/10 | Identidade + treino publicado como evento no relay + lido em outro dispositivo | **Demo 3 — 29/10** |
| **3** | 30/10 → 09/11 | Feed social + like + worker de agregação | Auxílio 3 — 09/11 |
| **4** | 10/11 → 23/11 | Dashboard, heatmap, ranking, relay próprio | Auxílio 4 — 23/11 |
| **5** | 24/11 → 03/12 | Congelamento, bug bash, documentação, ensaios. **Nenhuma feature nova** | **Demo 4 — 03/12** |

Já passou: Sprint de fundação (semanas 1–2) e **Demo 2 em 17/09**.

**Regra da Demo 4:** não demonstrar nada em ambiente de desenvolvimento. Ambiente de demo separado, com dados populados, testado no dia anterior, e vídeo de fallback gravado em 02/12 — Wi-Fi de sala de aula já derrubou mais apresentação do que bug.

---

## 4. Estado atual do repositório

41 commits em `main`. Estrutura:

```
OpenLift/
├── app/                        # Frontend Flutter
├── api/                        # Backend FastAPI + PostgreSQL
├── infra/docker/               # docker-compose + Dockerfiles
├── design/wireframes/sprint-1/ # Wireframes das 5 telas núcleo
├── .github/workflows/          # CI
├── implementation.md           # Roadmap original de 12 semanas
└── README.md
```

| Frente | Estado | Detalhe |
|---|---|---|
| Backend | **fechado** | FastAPI em camadas; 4 tabelas migradas de verdade no Postgres (`users`, `nostr_identities`, `workouts`, `sets`); `/health` e `/version` funcionando; schemas de auth e treino rascunhados; lint limpo |
| Frontend | **fechado** | `AppTheme` (Material 3, claro/escuro); `AppRouter` com 7 rotas navegáveis (placeholder); `main.dart`; widgets compartilhados; 8 testes passando; scaffolding nativo de todas as plataformas; testado no Chrome; wireframes de baixa fidelidade das 5 telas núcleo publicados |
| DevOps | **~50%** | Docker (Postgres + API + Adminer) funcionando ponta a ponta; repositório e convenções prontos. Falta CI/qualidade — ver §8 |
| Agente de IA | **iniciado, não fechado** | PR #2 (`workflow/agent-skill`) em aberto: agente de relatório de implementações via GitHub Actions com Gemini. Falta merge e falta a skill de geração de testes |

**Bug conhecido (ambiente, não código):** em pasta de projeto com acento no caminho, `flutter analyze` quebra. `flutter test` e `flutter run` funcionam normalmente, e o CI não tem esse problema.

### Como rodar

```bash
# Backend + banco
cd infra/docker
docker compose up -d
# http://localhost:8000/health  -> {"status":"ok"}
# http://localhost:8000/version
# http://localhost:8080         -> Adminer (usuário/senha/banco: openlift)

# Frontend — testes
cd app
flutter pub get
flutter test        # 8 testes, "All tests passed!"

# Frontend — rodando
flutter run -d chrome   # mais rápido, sem emulador
flutter run             # com Android configurado
```

Para rodar `pytest` ou `alembic` fora do Docker: `cp api/.env.example api/.env`. Para só usar `docker compose up`, não precisa — as variáveis vêm do compose.

---

## 5. Decisões fechadas (ADRs)

Estas decisões **não se reabrem sem discussão no grupo**. Cada uma vira um arquivo em `docs/adr/NNNN-titulo.md`, formato Nygard (Contexto / Decisão / Alternativas consideradas / Consequências / Status). Documentação conta nota na disciplina — e ADR escrito no momento da decisão custa 20 minutos, reconstruído três meses depois custa uma tarde e sai pior.

| ADR | Decisão | Motivo |
|---|---|---|
| **001** | **Front-end em Flutter**, entregue como build **web** (alvo primário de demo e distribuição) e **APK Android** | Substitui a decisão anterior de PWA em stack web. A Sprint 1 de Flutter já está construída e testada, e `flutter build web` + manifest entrega exatamente o benefício que motivava o PWA: abre no navegador do celular, sem loja e sem instalar |
| **002** | **Back-end:** Python 3.12 + FastAPI + PostgreSQL 16, SQLAlchemy 2.0 + Alembic, Pydantic v2 | Time domina; OpenAPI automática ajuda na entrega e na documentação |
| **003** | **Evento de treino: `kind 1301`** (rascunho NIP-101e), com as tags especificadas por nós num mini-NIP em `docs/nips/`, e tag `alt` (NIP-31) obrigatória | O rascunho não é consenso fechado, mas já tem clientes de terceiros lendo e escrevendo 1301 (Groundwork, My Fitness do Amethyst) — adotar dá interoperabilidade real de graça, e especificar as tags dá o capítulo "definimos o que o padrão não fechou". **Publicar treino como `kind 1` (nota de texto) está descartado**: destrói a legibilidade por máquina, que é a tese do produto |
| **004** | **Onde o dado vive:** Postgres guarda o privado (série, carga, RPE) e o agregável (like cache, ranking); o relay guarda o social e o portátil. **Nada social existe apenas no Postgres** — like, contagem e ranking têm origem obrigatória em evento assinado, e as tabelas de agregação são reconstruíveis por um comando de replay | Série e RPE não fazem sentido como evento público, e relay não responde bem a "top 10 mais curtidos da semana". A regra do replay é o que impede o produto de virar app fechado com um feed pendurado do lado — e é a demo ao vivo mais forte da Demo 4 |
| **005** | **Identidade:** par de chaves secp256k1 gerado localmente no primeiro uso, nunca exibido como "chave"; login por e-mail/senha desbloqueia o uso local; `npub` registrado no backend. Importação de `nsec` existente como **caminho avançado** | Cobre o público que não quer saber o que é chave (promessa do README) e o público NOSTR-nativo, com as tabelas que já existem |
| **006** | **Custódia da chave por plataforma:** Android usa Keystore via `flutter_secure_storage`; **na web o armazenamento é do navegador, não do SO**, e o caminho recomendado passa a ser signer externo (NIP-07 / NIP-46). A chave privada nunca trafega para o backend, nem em log, nem em telemetria, nem em mensagem de erro | Consequência direta do ADR-001 que precisa estar escrita com honestidade: "a chave nunca sai do device" continua verdadeiro na web, "está em armazenamento seguro do SO" não |
| **007** | **Relays:** públicos (`relay.damus.io`, `nos.lol`, `relay.nostr.band`) até a Demo 3; `strfry` próprio no compose a partir da Sprint 4. Lista configurável por variável de ambiente, sem hardcode | Reduz risco inicial a custo zero; o relay próprio remove dependência de rede alheia na apresentação final |
| **008** | **IA é ferramenta de desenvolvimento, nunca feature do produto.** Estratégia em camadas gratuitas; skills versionadas como markdown em `/.agent/skills/` (agnóstico de ferramenta), com `AGENTS.md` na raiz | Não há plano pago no time. Markdown versionado funciona em Claude Code, Gemini, Copilot e Cline sem reescrever nada |
| **009** | **Mapa de check-in em academia está fora do escopo obrigatório**, documentado como evolução futura | Não está na fonte de verdade; é uma frente inteira nova num front-end já reconhecido como gargalo; e carrega peso de LGPD com geolocalização. Vira capítulo de "evolução futura" na defesa, que é melhor do que um mapa meio pronto |
| **010** | **Gates de qualidade progressivos:** cobertura informativa até 29/10, bloqueante em 60% a partir da Sprint 3, 70% no congelamento | Prometer 80% e entregar 55% é pior que prometer 70% e bater |

---

## 6. Escopo

### Obrigatório — sem isso não há produto

- Registro de treino: criar treino, adicionar exercício, série, carga, repetição, RPE opcional
- Histórico de treinos do usuário, com filtro por data e exercício
- Identidade NOSTR gerada localmente, associada a usuário no nosso banco
- Publicar treino como evento no relay e ler treinos de outras pessoas
- Feed social com like
- Dashboard com estatística semanal e mapa de calor de volume por grupo muscular

### Desejável — entra se a sprint fechar antes

Ranking social · compartilhamento de artigos (NIP-23, `kind 30023`) · templates de treino reutilizáveis · streak · export do histórico

### Fora desta entrega — documentar como evolução futura

Mapa de check-in e qualquer localização · rastreio contínuo ao vivo · app publicado em loja · **qualquer IA dentro do produto** · mensagem direta entre usuários · dieta e macros · integração com wearables · vídeo e moderação de vídeo · pagamentos/zaps Lightning

> Escrever o escopo negativo no README é o que impede o projeto de derreter, e é sinal de maturidade que a banca reconhece.

---

## 7. Requisitos

Prioridade: **M** = Must (obrigatório) · **S** = Should · **C** = Could · **W** = Won't

### Funcionais

| ID | Requisito | Pri |
|---|---|---|
| RF-01 | Cadastro e login por e-mail/senha com JWT e refresh | M |
| RF-02 | Gerar par de chaves secp256k1 no dispositivo no primeiro login, sem servidor | M |
| RF-03 | Registrar o `npub` no backend (`POST /me/nostr-identity`) | M |
| RF-04 | Importar identidade existente via `nsec` (NIP-19) — caminho avançado | S |
| RF-05 | Editar perfil (`kind 0`): nome, bio, foto | S |
| RF-10 | Biblioteca de exercícios pré-carregada com grupo muscular | M |
| RF-11 | CRUD de exercício customizado | S |
| RF-12 | Criar treino: exercício, séries, repetições, carga em kg, RPE opcional | M |
| RF-13 | Marcar série como aquecimento / normal / falha | S |
| RF-14 | Listar e filtrar histórico de treinos (data, exercício, grupo muscular) | M |
| RF-15 | Editar e excluir treino local | M |
| RF-16 | Gráfico de progressão de carga por exercício | S |
| RF-17 | Detecção de PR (carga máxima, volume máximo, 1RM estimado) | S |
| RF-18 | Cronômetro de descanso entre séries | C |
| RF-20 | Publicar treino como evento `kind 1301` assinado localmente | M |
| RF-21 | Escolher visibilidade por treino: privado ou publicado | M |
| RF-22 | Fila de publicação com retry quando a rede voltar | S |
| RF-23 | Configurar lista de relays | S |
| RF-24 | Deduplicação por `event.id` na ingestão | M |
| RF-25 | Indicador de status por treino: local / publicado / falhou | M |
| RF-26 | Publicar artigo de formato longo (NIP-23, `kind 30023`) | C |
| RF-30 | Seguir e deixar de seguir perfil (`kind 3`) | M |
| RF-31 | Feed cronológico de treinos de quem sigo | M |
| RF-32 | Curtir treino publicando reação NIP-25 (`kind 7`) | M |
| RF-33 | Ver perfil de outro usuário com estatísticas públicas | S |
| RF-34 | Ranking semanal por volume entre seguidos | S |
| RF-35 | Silenciar usuário | C |
| RF-40 | Dashboard: volume da semana, treinos no mês, streak | M |
| RF-41 | Mapa de calor: grupo muscular × período, cor por intensidade de volume | M |
| RF-42 | Gráfico de volume semanal e mensal | M |
| RF-43 | Distribuição de volume por grupo muscular | S |
| RF-50 | Ingestão contínua de eventos do relay via WebSocket com reconexão | M |
| RF-51 | Verificação de assinatura de todo evento antes de qualquer projeção | M |
| RF-52 | Projeção de likes e follows para o read model em Postgres | M |
| RF-53 | **Comando de replay:** reconstruir as agregações do zero a partir dos eventos | M |
| RF-54 | Endpoints de agregação: `/stats/volume`, `/stats/muscle-groups`, `/stats/heatmap` | M |
| RF-55 | `/health` checando conexão com o banco e `/version` | M |
| RF-56 | Documentação OpenAPI com descrições e exemplos de payload | M |
| RF-60 | Relay `strfry` próprio em container, publicando a política via NIP-11 | S |
| RF-61 | Write policy plugin aceitando apenas kinds do escopo e com rate limit por pubkey | C |

### Não funcionais

| ID | Categoria | Requisito | Como verificar |
|---|---|---|---|
| RNF-01 | Segurança | Chave privada nunca em log, telemetria ou requisição HTTP | Teste automatizado que faz grep de `nsec` e de hex de 64 caracteres nos logs |
| RNF-02 | Segurança | 100% dos eventos consumidos têm assinatura verificada antes de projetar | Teste unitário com evento adulterado |
| RNF-03 | Segurança | Rate limiting nos endpoints públicos | Teste de integração |
| RNF-04 | Desempenho | Registro de série percebido como instantâneo (< 100 ms) | Teste de widget com timing |
| RNF-05 | Desempenho | Feed com 200 eventos renderiza em < 2 s | Benchmark manual documentado |
| RNF-06 | Recuperabilidade | Agregações reconstruíveis por replay em < 5 min | Comando + teste de integração |
| RNF-07 | Qualidade | Cobertura conforme ADR-010, com gate no CI | Relatório do `pytest-cov` no PR |
| RNF-08 | Qualidade | Zero warnings de lint no merge (`ruff`, `black`, `flutter analyze`) | CI |
| RNF-09 | Manutenibilidade | Todo merge em `main` via PR com ≥ 1 aprovação | Branch protection |
| RNF-10 | Portabilidade | Ambiente completo sobe com um `docker compose up` | Teste de "notebook novo" antes de cada demo |
| RNF-11 | Interoperabilidade | Evento publicado é legível em ≥ 1 cliente NOSTR de terceiros | Screenshot em cada demo |
| RNF-12 | Privacidade | Nenhuma coleta de geolocalização. Consentimento informado e explícito na primeira publicação | Revisão + `docs/lgpd.md` |
| RNF-13 | Usabilidade | Registrar uma série em ≤ 3 toques | Teste com 3 pessoas fora da equipe |
| RNF-14 | Observabilidade | Logs estruturados em JSON, correlacionáveis por `event_id` | Revisão de código |

### Regras de negócio

| ID | Regra |
|---|---|
| RN-01 | Treino sem nenhuma série registrada não pode ser publicado |
| RN-02 | PR só conta se a série for do tipo `normal` ou `failure` — aquecimento não conta |
| RN-03 | Volume = Σ (carga × repetições), apenas de séries não-aquecimento |
| RN-04 | Ranking considera apenas eventos com `created_at` dentro da semana ISO corrente |
| RN-05 | Ranking desconsidera eventos com `created_at` no futuro (> 15 min à frente do relógio do servidor) |
| RN-06 | Like é idempotente: múltiplos `kind 7` do mesmo pubkey no mesmo evento contam 1 |
| RN-07 | Carga máxima aceita 1000 kg, repetições máximo 500 — acima disso é erro de digitação ou abuso |
| RN-08 | Edição de treino já publicado gera **novo** evento; o anterior permanece (imutabilidade do protocolo) |
| RN-09 | Unidade de carga no evento é sempre **kg**; conversão para lb é apresentação |

> **RN-04, RN-05 e RN-07 merecem destaque na defesa:** ranking sobre dado auto-reportado e assinado por qualquer um é **inerentemente falsificável** — qualquer pessoa pode assinar "1000 kg no supino". Mitigações realistas: ranking só entre perfis seguidos, limites de plausibilidade, detecção de outlier. Não finjam que o ranking é confiável; expliquem por que não é e o que fizeram a respeito. Isso vale mais que um ranking bonito.

---

## 8. O que falta — pendências concretas

### Documentação

O repositório tem código e não tem a camada de decisão e requisito escrita. Estrutura de `docs/`:

```
docs/
  CONTEXTO.md            este arquivo
  adr/                   ADR-001 a ADR-010 (§5), formato Nygard
  requisitos/            RF / RNF / RN (§7) + matriz de rastreabilidade
  nips/                  mini-NIP do evento de treino + JSON Schema
  arquitetura/           diagrama de contêineres, diagramas de sequência
  ia/                    skills, agentes, registro de uso, avaliação crítica
  runbook/               como subir, como fazer replay, como operar o relay
  lgpd.md                análise honesta de privacidade e limitações
  prompts/               prompts que funcionaram (anexo do relatório final)
  retros/                uma ata por sprint
```

Cada item dessa lista é uma issue própria (ver issue #4, tracking), com sua própria branch e PR — não juntar múltiplos itens num único PR.

Dois itens desse conjunto são conteúdo original e não podem ser gerados por agente sem decisão humana: o **mini-NIP** (é o ADR-003 detalhado, e trava front e back ao mesmo tempo) e o **`lgpd.md`** (a tensão entre direito ao apagamento e imutabilidade de relay é real e insolúvel — documentar com honestidade é o ponto, e é bom tópico de defesa).

### DevOps

1. `.github/workflows/backend-ci.yml` — job `lint` rodando `ruff check .` e `black --check .` em todo PR que toca `api/**`
2. `.github/workflows/frontend-ci.yml` — job `analyze` rodando `flutter analyze` em todo PR que toca `app/**`
3. `api/.pre-commit-config.yaml` — hooks locais de `ruff` e `black`
4. Seção **Definition of Done** no `README.md`
5. Board no GitHub Projects (manual, interface web)
6. Branch protection em `main`: PR obrigatório, ≥ 1 aprovação, status checks obrigatórios, sem force push, squash merge
7. `gitleaks` no CI — crítico dado o RNF-01
8. Conventional Commits validados por `commitlint`

### Agente de IA

1. Fechar o PR #2 (agente de relatório de implementações)
2. `api/tests/conftest.py` — fixtures `db_session` (banco de teste isolado, criando as tabelas de `Base.metadata` antes de cada teste) e `client` (`TestClient` do FastAPI com `get_db` sobrescrito)
3. Skills em `/.agent/skills/`: `gerar-teste-pytest.md`, `gerar-teste-flutter.md`, `validar-evento-nostr.md`, `revisar-pr.md`, `criar-endpoint-fastapi.md`, `escrever-adr.md`
4. `AGENTS.md` na raiz com arquitetura, convenções e as regras invioláveis — é o que faz a IA gerar código no padrão do projeto em vez de código genérico
5. MCP locais, custo zero: Postgres (o agente consulta o schema real em vez de inventar coluna), filesystem, GitHub

### Definition of Done — vale para toda história

1. Código em `main` via PR revisado por outra pessoa
2. Lint passando
3. Teste automatizado cobrindo o caminho principal e os critérios de aceite
4. CI verde
5. QA validou contra o critério de aceite escrito **antes** da sprint
6. Documentação atualizada se mudou comportamento ou instalação
7. Uso de IA declarado no PR

### Política de uso de IA

- **IA gera, humano é responsável.** "A IA escreveu" nunca é explicação aceitável para um bug.
- Todo PR declara: ferramenta/modelo, o que foi gerado, o que foi revisado e alterado.
- Nunca colar segredo, chave privada ou dado pessoal em prompt.
- Código gerado sem teste não é aceito. Teste gerado por IA só entra depois de aprovado pelo QA.
- A maior economia não é escolher modelo, é **escopo pequeno**: uma tarefa, um arquivo, contexto explícito. "Implementa a feature inteira" queima token e entrega ruim.

---

## 9. O que falta decidir

| # | Questão | Recomendação | Quem decide |
|---|---|---|---|
| 1 | Alocação das seis fronteiras entre cinco pessoas | PO acumula Dev NOSTR; front-end ganha o segundo par de mãos do DevOps nas sprints de tela | Time, na reunião |
| 2 | Tags exatas do evento `kind 1301` — nome, tipo e ordem dos campos de exercício, série, carga, repetição, RPE, PR | Conferir o rascunho NIP-101e em `github.com/nostr-protocol/nips` (incluindo PRs abertos) e o que Groundwork e Amethyst realmente emitem, e só então fixar. **Primeira tarefa técnica da Sprint 1** | Dev NOSTR + PO |
| 3 | Alvo primário: web ou Android | Web como demo primária (abre em qualquer celular na apresentação), APK como entrega adicional | Time |
| 4 | Gerência de estado no Flutter | Riverpod, já previsto no roadmap. Não gastar mais de 1 h nisso; ambos funcionam | Front-end |
| 5 | Onde hospedar staging | Fly.io, Railway, Oracle Cloud Free Tier ou VPS da equipe | DevOps |
| 6 | Relay próprio é obrigatório ou stretch? | Stretch da Sprint 4 — não bloqueia nada | Time |
| 7 | Worker de sincronização: APScheduler ou Celery + Redis? | APScheduler, se o volume for o da turma. Celery + Redis é infra a mais para manter | Back-end |
| 8 | Modo "relay da turma" com allowlist para a demo final | Sim — reduz drasticamente o risco de conteúdo inadequado aparecer na apresentação | Time |

---

## 10. Riscos

| Risco | Impacto | O que fazemos |
|---|---|---|
| Front-end sobrecarregado (1 pessoa, 3 frentes) | Alto | Ordem de construção rígida; DevOps apoia nas sprints de tela; é o primeiro lugar a cortar escopo |
| Schema do evento atrasar | Alto | Primeira tarefa da Sprint 1. Trava front e back simultaneamente se escorregar |
| Semana de provas | Alto | Avisar no grupo com antecedência; a sprint se ajusta, a pessoa não se sacrifica |
| Rascunho NIP-101e mudar | Médio | Camada de adapter isolando a serialização; kinds em constante única |
| Relay público instável | Médio | Relay próprio no compose a partir da Sprint 4 |
| Demo falhar ao vivo | Médio | Ambiente de demo separado + vídeo de fallback gravado no dia anterior |
| Escopo crescendo | Médio | Nada entra na lista obrigatória sem sair outra coisa |
| Código gerado por IA sem entendimento gera dívida invisível | Médio | Política da §8; revisão obrigatória; auditoria de módulo na retro |

---

## Apêndice A — Histórico documental

Quatro documentos de planejamento circularam e descrevem produtos parcialmente incompatíveis. Este arquivo os consolida. Para evitar que alguém implemente a versão errada:

| Documento | Status | O que foi aproveitado / descartado |
|---|---|---|
| `openlift-ideacao_inicial.txt` | **Vigente — fonte de verdade do escopo** | Base de tudo |
| `academia.pdf` | Histórico | Apresentação da mesma ideação, sem conteúdo novo |
| `OpenLift-Roadmap-12-Semanas` (= `implementation.md`) | **Parcialmente vigente** | Conteúdo técnico das sprints aproveitado e recortado no calendário da §3. **Descartado:** compartilhar treino como `kind 1`; gates de cobertura até 80%; sprints de 2 semanas atravessando checkpoint |
| `openlift-plano-de-desenvolvimento.md` v1.0 | **Parcialmente vigente** | Aproveitado: calendário ancorado nos checkpoints, fronteiras de responsabilidade, regra das 6 h, estratégia de IA gratuita em camadas. **Descartado:** PWA (ADR-001) e mapa de check-in como obrigatório (ADR-009) |
| `PLANO-ENGENHARIA-projeto-academia-nostr.md` (agosto) | Histórico | Aproveitado: kinds NIP-101e, regra de replay do ADR-004, requisitos e regras de negócio da §7, escopo negativo. **Descartado:** CQRS/event sourcing completo com relay como fonte da verdade (ambicioso demais para 6 h/semana); 8 sprints de 16 semanas; nome ACADEMIA / Ferro Aberto |
| `implementation.md` no repo | Manter, mas marcar | Adicionar aviso no topo apontando para `docs/CONTEXTO.md` como documento vigente |
