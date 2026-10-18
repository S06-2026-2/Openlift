# Arquitetura

Visão de como o OpenLift é montado: contêineres, camadas e os fluxos principais. Os diagramas são [Mermaid](https://mermaid.js.org/) e o GitHub os desenha direto no navegador.

**Atualizado em 17/10/2026**, fim da Sprint 1. Cada diagrama diz se mostra o que **existe** ou o que está **planejado**. Mudou a arquitetura? Atualize o diagrama no mesmo PR.

As decisões por trás deste desenho estão em [`docs/adr/`](../adr/): principalmente [ADR-0001](../adr/0001-frontend-flutter-web-e-apk.md) (Flutter), [ADR-0002](../adr/0002-backend-python-fastapi-postgresql.md) (FastAPI + Postgres), [ADR-0004](../adr/0004-onde-o-dado-vive.md) (onde o dado vive) e [ADR-0007](../adr/0007-relays.md) (relays).

---

## 1. Contêineres

### Hoje (fim da Sprint 1)

```mermaid
flowchart LR
    user([Usuário])
    subgraph device[Dispositivo do usuário]
        app["App Flutter<br/>web + APK<br/><i>Riverpod · go_router · Dio</i>"]
        keys[("Armazenamento seguro<br/>tokens JWT")]
    end
    subgraph compose[docker compose]
        api["API FastAPI<br/><i>Python 3.12 · SQLAlchemy 2.0</i>"]
        db[("PostgreSQL 16")]
    end
    user --> app
    app <--> keys
    app -- "HTTPS / JSON<br/>/api/v1 + Bearer JWT" --> api
    api -- SQL --> db
```

### Planejado (Sprints 2 a 4)

```mermaid
flowchart LR
    subgraph device[Dispositivo do usuário]
        app["App Flutter"]
        keys[("Chave NOSTR<br/>gerada no dispositivo")]
    end
    subgraph compose[docker compose]
        api["API FastAPI"]
        db[("PostgreSQL<br/>privado + cache social")]
        worker["Worker de sincronização<br/><i>S3</i>"]
        strfry["Relay strfry próprio<br/><i>S4</i>"]
    end
    relays[("Relays NOSTR públicos<br/><i>S2</i>")]
    other["Outros clientes NOSTR"]

    app <--> keys
    app -- "só o npub (S2)" --> api
    app -- "eventos assinados (S2)" --> relays
    app -. "S4" .-> strfry
    relays -- "ingestão (S3)" --> worker
    worker -- "projeções (S3)" --> db
    api --> db
    other -- "lê kind 1301" --> relays
```

| Contêiner | Responsabilidade | Onde está |
|---|---|---|
| App Flutter | Telas, validação de formulário, sessão, e (a partir da S2) geração da chave e assinatura de eventos **no dispositivo** | `app/` |
| API FastAPI | Conta, treino privado (séries, carga, RPE), histórico e agregações | `api/` |
| PostgreSQL | Dado privado e **cache** das agregações sociais, reconstruível por replay (ADR-0004) | `infra/docker/docker-compose.yml` |
| Relays NOSTR | Dado social e portátil: treinos publicados, likes, follows | Públicos até a Demo 3 (ADR-0007) |
| Worker | Ingestão dos eventos, verificação de assinatura e projeção no Postgres | Planejado (S3) |
| strfry | Relay próprio, para não depender de rede alheia na Demo 4 | Planejado (S4) |
| Adminer | Interface web para inspecionar o banco, **só em desenvolvimento** (`localhost:8080`) | `infra/docker/docker-compose.yml` |

**Fronteira de segurança:** a chave privada NOSTR fica no dispositivo e **nunca** atravessa a seta para a API (RNF-01, ADR-0006). A API só conhece o `npub`.

---

## 2. Camadas do backend (existe)

```mermaid
flowchart TB
    subgraph api["api/app/api/v1 — rotas finas"]
        r1[auth.py]
        r2[exercises.py]
        r3[workouts.py]
    end
    deps["api/app/api/deps.py<br/>DbSession · CurrentUser (Bearer JWT)"]
    subgraph svc["api/app/services — regras de negócio"]
        s1[auth_service]
        s2[exercise_service]
        s3[workout_service]
    end
    subgraph domain["api/app/domain"]
        schemas["schemas Pydantic<br/>entrada/saída + limites RN-07"]
        models["models SQLAlchemy"]
    end
    core["api/app/core<br/>config · security (JWT, bcrypt) · errors {detail, code}"]
    infra["api/app/infra<br/>sessão do banco · seed"]
    pg[(PostgreSQL)]

    api --> deps
    api --> svc
    api --> schemas
    svc --> models
    svc --> core
    models --> infra --> pg
```

- **Rota** valida a entrada (schema), chama o service e devolve o schema de saída. Não tem regra de negócio.
- **Service** concentra a regra e o **isolamento por usuário**: toda consulta filtra por `current_user.id`, e recurso de outra pessoa responde 404.
- **Erros** sempre como `ApiError` → `{"detail": "...", "code": "..."}`; 422 traz também `errors` com o campo.

## 3. Camadas do frontend (existe)

```mermaid
flowchart LR
    subgraph feature["app/lib/features/&lt;feature&gt;"]
        pres["presentation/<br/>telas + controller Riverpod"]
        dom["domain/<br/>models + validadores"]
        data["data/<br/>repository"]
    end
    shared["app/lib/shared/widgets<br/>design system + AppShell"]
    core["app/lib/core<br/>ApiClient (Dio) · router · tema · storage"]
    api[(API)]

    pres --> dom
    pres --> data
    pres --> shared
    data --> core --> api
```

Features hoje: `auth`, `workouts` (prontas), `dashboard` e `social` (estrutura com TODOs para as Sprints 3–5).

---

## 4. Sequência: login e renovação de sessão (existe)

```mermaid
sequenceDiagram
    autonumber
    actor U as Usuário
    participant App as App Flutter
    participant S as Armazenamento seguro
    participant API as API FastAPI
    participant DB as PostgreSQL

    U->>App: e-mail + senha
    App->>API: POST /api/v1/auth/login
    API->>DB: busca usuário por e-mail
    API->>API: confere hash bcrypt
    API-->>App: 200 {access_token, refresh_token}
    App->>S: guarda os dois tokens

    Note over App,API: Mais tarde, o access token expira
    App->>API: GET /api/v1/workouts (Bearer access)
    API-->>App: 401 token_expired
    App->>API: POST /api/v1/auth/refresh (uma vez só)
    API-->>App: 200 novo par de tokens
    App->>S: substitui os tokens
    App->>API: repete GET /api/v1/workouts
    API-->>App: 200
    Note over App: Se o refresh for recusado, o app limpa a sessão<br/>e volta para o login ("Sua sessão expirou").
```

Várias requisições com 401 ao mesmo tempo compartilham um único refresh, e falha de **rede** no refresh não derruba a sessão (`app/lib/core/network/api_client.dart`).

## 5. Sequência: registrar treino (existe)

```mermaid
sequenceDiagram
    autonumber
    actor U as Usuário
    participant App as App Flutter
    participant API as API FastAPI
    participant DB as PostgreSQL

    App->>API: GET /api/v1/exercises
    API-->>App: biblioteca com grupo muscular
    U->>App: escolhe exercícios e preenche séries
    App->>App: valida limites (RN-07) antes de enviar
    App->>API: POST /api/v1/workouts {date, sets[]}
    API->>API: valida schema (RN-07) e exercícios existentes
    API->>DB: grava treino + séries (user_id do token)
    API-->>App: 201 treino criado
    App-->>U: volta ao histórico, volume sem aquecimento (RN-03)
```

## 6. Sequência: publicar treino e ler em outro dispositivo (planejado — Sprint 2)

> **Planejado.** O formato das tags do evento depende do mini-NIP (NOSTR-01, #22), e o modo como o backend fica sabendo da publicação será definido nas histórias S2-04/S2-05 ([`docs/qa/sprint-2.md`](../qa/sprint-2.md)). O diagrama mostra só o que já está decidido nos ADRs.

```mermaid
sequenceDiagram
    autonumber
    actor A as Usuário A
    participant AppA as App (dispositivo A)
    participant R as Relays NOSTR
    participant AppB as App (dispositivo B)
    actor B as Usuário B

    A->>AppA: Publicar treino
    AppA->>AppA: consentimento na 1ª publicação (RNF-12)
    AppA->>AppA: monta kind 1301 + alt e assina com a chave local
    AppA->>R: EVENT (cada relay da lista)
    R-->>AppA: OK / erro, por relay
    AppA-->>A: status publicado / falhou (RF-25)

    B->>AppB: abre os treinos de A
    AppB->>R: REQ por pubkey de A
    R-->>AppB: eventos kind 1301
    AppB->>AppB: verifica assinatura e deduplica por id (RF-51, RF-24)
    AppB-->>B: treino de A
```
