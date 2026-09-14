# OpenLift — Plano de Implementação

Plano de 12 semanas, dividido em 6 sprints de 2 semanas, para o desenvolvimento do OpenLift: um app de treino com registro de histórico, dashboards analíticos (incluindo mapa de calor de volume por grupo muscular) e compartilhamento social via protocolo [NOSTR](https://nostr.com/).

Projeto acadêmico da disciplina de Produto de Software — o plano equilibra entregas funcionais, boas práticas de Engenharia de Software e configuração de infraestrutura.

> Legenda das frentes de trabalho usadas abaixo: **Frontend** (Flutter), **Backend** (FastAPI), **DevOps**, **Agente de IA** (testes).

---

## Visão geral da arquitetura

O princípio central do OpenLift é: **a chave privada NOSTR nunca sai do dispositivo do usuário**, e o backend só existe para guardar o que a rede NOSTR não guarda bem.

- No primeiro acesso, o app Flutter gera um par de chaves NOSTR localmente (ex.: pacote `dart_nostr`) e guarda o `nsec` em armazenamento seguro do SO (Keychain/Keystore, via `flutter_secure_storage`). O login "tradicional" (e-mail + senha) apenas desbloqueia o uso do app nesse dispositivo — não recria nem transmite a chave.
- Cada conta interna (`users.id`) é mapeada 1:1 para uma chave pública NOSTR (`npub`), guardada em `nostr_identities` no Postgres. É essa abstração que resolve o requisito de UX: **o usuário nunca vê nem precisa copiar uma chave**.
- Toda ação social (compartilhar treino, curtir, publicar artigo) é **assinada localmente no dispositivo** e publicada como evento assinado diretamente nos relays configurados — o backend nunca assina nada em nome do usuário:
  - `kind 1` — treino/nota curta
  - `kind 30023` (NIP-23) — artigo de formato longo
  - `kind 7` (NIP-25) — reação/curtida
- O **FastAPI + Postgres** cuidam do que o NOSTR não resolve bem: dados privados e estruturados de treino (séries, cargas, RPE) que não fazem sentido como eventos públicos, e agregações que os relays não respondem bem (rankings, contagem de curtidas por período, heatmap de volume).
- Para isso, um **worker de sincronização** (parte do backend, `nostr_sync_worker`) se conecta aos mesmos relays em modo **somente leitura**, escuta reações (NIP-25) sobre os eventos publicados pelos usuários e espelha essas contagens em tabelas cache no Postgres (`likes`, `rankings`). Assim, a consulta de ranking é uma query SQL rápida, não uma varredura de relay a cada requisição.

```
┌───────────────┐   HTTPS: auth, treinos,      ┌───────────────────┐   SQL   ┌────────────┐
│   App Flutter  │──registro do npub──────────▶│      Backend       │────────▶│ PostgreSQL │
│ (assina local) │                              │ (FastAPI + Worker) │         │            │
└───────┬───────┘                              └─────────┬──────────┘   ▲    └────────────┘
        │  WSS: publica evento assinado                  │ WSS (leitura)│ grava cache
        │  (kind 1 / 7 / 30023)                          │ espelha NIP-25│
        ▼                                                 ▼              │
┌─────────────────────────────────────────────────────────────────────────┐
│                              Relays NOSTR                                │
│                relay.damus.io · nos.lol · relay.nostr.band               │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Roadmap de 12 semanas

### Sprint 1 — Semanas 1–2 — Fundamentos & setup do ambiente

**Objetivo:** time alinhado, repositório organizado, esqueleto técnico rodando localmente via Docker, banco de dados modelado.
**Entrega:** `docker compose up` sobe API + Postgres; app Flutter navega entre telas placeholder; todo PR roda lint no CI.

| Frentes | Tarefas |
|---|---|
| **Frontend** | Projeto Flutter em estrutura feature-first (`core/`, `features/{auth,workouts,dashboard,social}`); gerenciamento de estado com Riverpod; design system inicial (paleta, tipografia, componentes base); wireframes de baixa fidelidade (login, dashboard, registro de treino, perfil, feed); navegação (`go_router`) com rotas placeholder. |
| **Backend** | Scaffold FastAPI em camadas (`api/`, `domain/`, `infra/`, `schemas/`); ERD inicial (`users`, `nostr_identities`, `workouts`, `exercises`, `sets`, `muscle_groups`, `likes`, `rankings`); SQLAlchemy 2.0 + Alembic com primeira migration; endpoints `/health` e `/version`; rascunho do contrato OpenAPI. |
| **DevOps** | Repositório + convenção de branches e Conventional Commits; `Dockerfile` da API + `docker-compose.yml` (api + postgres + adminer); GitHub Actions com workflow de lint em todo PR; board do projeto e Definition of Done no README; pre-commit hooks locais (ruff, black). |
| **Agente de IA** | Preparar o terreno: skill de geração de testes configurada no Claude Code e estrutura `tests/` com fixtures de banco (SQLite in-memory). Ainda sem cobrança de cobertura. |

### Sprint 2 — Semanas 3–4 — Identidade invisível & CRUD de treinos

**Objetivo:** o usuário cria conta, ganha uma identidade NOSTR sem perceber, e registra treinos de verdade.
**Entrega:** cadastro/login ponta-a-ponta; treino criado, listado e editado via app conectado à API real.

| Frentes | Tarefas |
|---|---|
| **Frontend** | Telas de cadastro/login com validação; geração local do par de chaves NOSTR no 1º login (guardado em `flutter_secure_storage`, nunca exibido como "chave"); envio do `npub` ao backend no cadastro; tela "Novo Treino" (exercício, séries, repetições, carga, RPE opcional); lista de treinos consumindo a API (Dio + providers com estados loading/error/success). |
| **Backend** | `/auth/register`, `/auth/login`, refresh de JWT (passlib + PyJWT); tabela `nostr_identities` + `POST /me/nostr-identity`; CRUD de treinos (`/workouts`, `/workouts/{id}/sets`); validação com Pydantic v2 e tratamento de erro padronizado. |
| **DevOps** | CI: job de teste com Postgres de serviço + relatório de cobertura (`pytest-cov`); job `flutter test` (widget tests básicos); gestão de segredos (`.env.example` + secrets do GitHub Actions); `docker-compose` completo documentado no README de onboarding. |
| **Agente de IA** | A cada PR de auth/CRUD, gera testes Pytest para casos felizes e de borda (senha inválida, treino inexistente, npub duplicado). **Humano revisa e ajusta antes do merge.** Meta de cobertura: **50%** — informativa. |

### Sprint 3 — Semanas 5–6 — Dashboard, estatísticas & leitura NOSTR

**Objetivo:** o usuário vê sua evolução; o app começa a "escutar" a rede NOSTR, ainda só em modo leitura.
**Entrega:** dashboard com métricas reais de volume/frequência; conexão ativa com relays exibindo o próprio histórico.

| Frentes | Tarefas |
|---|---|
| **Frontend** | Dashboard com cards de resumo (volume da semana, treinos no mês, streak) + gráfico de volume (`fl_chart`); histórico de treinos com filtros por data/exercício/grupo muscular; conexão WebSocket com 2–3 relays padrão via `dart_nostr`, inscrição (REQ) nos próprios eventos; tela de feed (placeholder). |
| **Backend** | `/stats/volume?groupBy=week`, `/stats/muscle-groups`; taxonomia exercício → grupo muscular (seed de exercícios comuns); paginação e filtros na listagem de treinos; índices no Postgres nas colunas usadas em agregação. |
| **DevOps** | Pipeline de deploy contínuo para staging a cada merge em `main`; testes de integração no CI contra Postgres real; logging estruturado (`structlog`) e `/health` estendido. |
| **Agente de IA** | Testes para os endpoints de agregação, incluindo bordas (usuário sem treinos, divisão por zero, fuso horário). Início do acompanhamento de cobertura sprint a sprint. Meta: **60%**. |

### Sprint 4 — Semanas 7–8 — Compartilhamento NOSTR & métricas sociais

**Objetivo:** o usuário publica treinos e artigos na rede, curte publicações; o backend passa a espelhar métricas sociais.
**Entrega:** compartilhamento funcional (`kind 1` / `kind 30023`), likes via NIP-25, ranking básico calculado no backend.

| Frentes | Tarefas |
|---|---|
| **Frontend** | Tela de composição: compartilhar treino (`kind 1`) ou artigo (NIP-23, `kind 30023`), assinado localmente; publicação (EVENT) nos relays com feedback de sucesso/erro por relay; feed social lendo relays + fallback de contadores via cache do backend; botão de curtir publicando reação NIP-25 (`kind 7`). |
| **Backend** | Tabelas `shared_events` (workout ↔ event_id NOSTR) e `likes`; worker (APScheduler/Celery) que lê relays e mantém contagem cacheada no Postgres; `GET /social/ranking` (score = curtidas recentes com decaimento por tempo); rate limiting (`slowapi`) nos endpoints públicos. |
| **DevOps** | Redis + worker no `docker-compose` e no staging; lista de relays configurável por variável de ambiente; CI passa a rodar testes de integração do worker. |
| **Agente de IA** | Gera testes simulando respostas de relay (mocks de WebSocket) para validar worker e ranking. **A partir daqui a cobertura bloqueia o CI** — PR não mergeia abaixo de **70%**. |

### Sprint 5 — Semanas 9–10 — Mapa de calor de volume & performance

**Objetivo:** análise visual avançada e app pronto para uso real — dados corretos e rápidos, mesmo sob carga.
**Entrega:** heatmap de volume por grupo muscular funcional; agregações otimizadas; app revisado visualmente.

| Frentes | Tarefas |
|---|---|
| **Frontend** | Componente de heatmap (matriz grupo muscular × período, `CustomPainter`); estados vazios, skeleton loading, tratamento de erro de rede, acessibilidade; polimento visual (ícone, splash screen, microcopy). |
| **Backend** | `GET /stats/heatmap` (matriz agregada data × grupo muscular × volume); cache (Redis) para agregações pesadas; ajuste de performance (`EXPLAIN ANALYZE`, índices compostos). |
| **DevOps** | Testes de carga com Locust nos endpoints de estatísticas/heatmap; Dependabot / `pip-audit` / `flutter pub outdated`; rotina de backup automatizado do Postgres. |
| **Agente de IA** | Testes parametrizados do heatmap (intervalos de data, fusos horários) + rodada exploratória de **mutation testing** (`mutmut`) em módulo crítico. Meta: **75%**. |

### Sprint 6 — Semanas 11–12 — Hardening, documentação & entrega

**Objetivo:** fechar o MVP, documentar decisões e preparar a apresentação para a banca.
**Entrega:** build de demonstração, documentação completa, pipeline com gates obrigatórios, retrospectiva do uso de IA.

| Frentes | Tarefas |
|---|---|
| **Frontend** | Correção de bugs da rodada de QA interna; telas de estado final (erro genérico, sem internet, sessão expirada); stub da **Fase 2** (tela de avaliação/ranking de treinos com likes visíveis, sem interação completa ainda); build de release (APK assinado). |
| **Backend** | Documentação OpenAPI fechada; revisão de segurança básica (headers, CORS, exposição de erros); script de seed com dados de demonstração. |
| **DevOps** | Branch protection: PR só mergeia com lint + testes + cobertura ≥ 80%; tag de release `v1.0` + changelog; diagrama de arquitetura final, README de setup, runbook básico; roteiro da demo. |
| **Agente de IA** | Relatório final de cobertura por módulo, apontando caminhos críticos não testados, mais retrospectiva documentada (tempo poupado, testes corrigidos manualmente, lições para o relatório da disciplina). |

---

## Plano de qualidade com IA

A IA acelera a escrita do código de produção e também a escrita dos testes — mas **nunca decide sozinha o que é suficiente**. Todo teste gerado passa por revisão humana antes de entrar em `main`.

**Fluxo por PR:**

1. **PR aberto** com código novo (gerado com Claude Code/Codex ou escrito à mão).
2. **Skill de geração de testes** lê o diff e propõe testes Pytest (casos felizes + bordas) no próprio PR.
3. **Revisão humana:** desenvolvedor ajusta asserts, remove testes redundantes, aprova.
4. **Merge** só com lint + suíte completa + gate de cobertura do sprint passando no CI.

**Metas de cobertura por sprint:**

| Sprint | Semanas | Meta de cobertura | Foco do agente de testes | Gate no CI |
|---|---|---|---|---|
| 1 | 1–2 | — | Estrutura de testes e fixtures de banco | informativo |
| 2 | 3–4 | 50% | Auth e CRUD de treinos | informativo |
| 3 | 5–6 | 60% | Endpoints de agregação/estatísticas | informativo |
| 4 | 7–8 | 70% | Worker NOSTR, likes e ranking | **bloqueante** |
| 5 | 9–10 | 75% | Heatmap + spot-check de mutation testing | **bloqueante** |
| 6 | 11–12 | 80% | Auditoria final por módulo | **bloqueante** |

**Salvaguardas:**

- Cobertura é um *proxy*, não o objetivo — o gate sobe aos poucos para não travar os primeiros sprints.
- A partir do Sprint 5, um spot-check de mutation testing valida se os testes gerados realmente falham quando o código quebra, não só se "passam por cima" das linhas.
- Segunda camada: revisão de código assistida por IA (`/code-review`) em PRs relevantes, focada em bugs de lógica e simplificação — complementar à cobertura de testes, não um substituto dela.

---

## Stack tecnológico

| Camada | Tecnologia | Papel |
|---|---|---|
| Frontend | Flutter 3.x | App único Android/iOS |
| | Riverpod | Estado e injeção de dependência |
| | go_router | Navegação declarativa |
| | dart_nostr / ndk | Chaves, assinatura e relays |
| | flutter_secure_storage | Custódia local do `nsec` |
| | fl_chart | Gráficos e heatmap |
| Backend | Python 3.12 + FastAPI | API REST |
| | SQLAlchemy 2.0 + Alembic | ORM e migrations |
| | Pydantic v2 | Validação de payloads |
| | PyJWT + passlib | Autenticação |
| | APScheduler / Celery + Redis | Worker de sincronização NOSTR |
| Dados & protocolo social | PostgreSQL 16 | Dados privados e agregações |
| | Redis | Cache e fila do worker |
| | NIP-01 / NIP-25 / NIP-23 | Protocolo base, reações, artigos longos |
| DevOps & qualidade | Docker + Docker Compose | API, worker e Postgres |
| | GitHub Actions | CI/CD e gates de merge |
| | ruff + black + mypy | Lint e tipagem |
| | pytest + pytest-cov + httpx | Testes de backend |
| | flutter_test + mocktail | Testes de frontend |
| | Locust | Teste de carga |
