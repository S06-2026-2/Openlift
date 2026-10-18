# Requisitos funcionais (RF)

Fonte: [`docs/CONTEXTO.md` §7](../CONTEXTO.md#7-requisitos). Prioridade em MoSCoW (ver [`README.md`](README.md)). O status de cada um está na [matriz de rastreabilidade](rastreabilidade.md).

## Identidade e conta

| ID | Requisito | Pri |
|---|---|---|
| RF-01 | Cadastro e login por e-mail/senha com JWT e refresh | M |
| RF-02 | Gerar par de chaves secp256k1 no dispositivo no primeiro login, sem servidor | M |
| RF-03 | Registrar o `npub` no backend (`POST /me/nostr-identity`) | M |
| RF-04 | Importar identidade existente via `nsec` (NIP-19) — caminho avançado | S |
| RF-05 | Editar perfil (`kind 0`): nome, bio, foto | S |

## Treino

| ID | Requisito | Pri |
|---|---|---|
| RF-10 | Biblioteca de exercícios pré-carregada com grupo muscular | M |
| RF-11 | CRUD de exercício customizado | S |
| RF-12 | Criar treino: exercício, séries, repetições, carga em kg, RPE opcional | M |
| RF-13 | Marcar série como aquecimento / normal / falha | S |
| RF-14 | Listar e filtrar histórico de treinos (data, exercício, grupo muscular) | M |
| RF-15 | Editar e excluir treino local | M |
| RF-16 | Gráfico de progressão de carga por exercício | S |
| RF-17 | Detecção de PR (carga máxima, volume máximo, 1RM estimado) | S |
| RF-18 | Cronômetro de descanso entre séries | C |

## Publicação (NOSTR)

| ID | Requisito | Pri |
|---|---|---|
| RF-20 | Publicar treino como evento `kind 1301` assinado localmente | M |
| RF-21 | Escolher visibilidade por treino: privado ou publicado | M |
| RF-22 | Fila de publicação com retry quando a rede voltar | S |
| RF-23 | Configurar lista de relays | S |
| RF-24 | Deduplicação por `event.id` na ingestão | M |
| RF-25 | Indicador de status por treino: local / publicado / falhou | M |
| RF-26 | Publicar artigo de formato longo (NIP-23, `kind 30023`) | C |

## Social

| ID | Requisito | Pri |
|---|---|---|
| RF-30 | Seguir e deixar de seguir perfil (`kind 3`) | M |
| RF-31 | Feed cronológico de treinos de quem sigo | M |
| RF-32 | Curtir treino publicando reação NIP-25 (`kind 7`) | M |
| RF-33 | Ver perfil de outro usuário com estatísticas públicas | S |
| RF-34 | Ranking semanal por volume entre seguidos | S |
| RF-35 | Silenciar usuário | C |

## Dashboard

| ID | Requisito | Pri |
|---|---|---|
| RF-40 | Dashboard: volume da semana, treinos no mês, streak | M |
| RF-41 | Mapa de calor: grupo muscular × período, cor por intensidade de volume | M |
| RF-42 | Gráfico de volume semanal e mensal | M |
| RF-43 | Distribuição de volume por grupo muscular | S |

## Backend e operação

| ID | Requisito | Pri |
|---|---|---|
| RF-50 | Ingestão contínua de eventos do relay via WebSocket com reconexão | M |
| RF-51 | Verificação de assinatura de todo evento antes de qualquer projeção | M |
| RF-52 | Projeção de likes e follows para o read model em Postgres | M |
| RF-53 | **Comando de replay:** reconstruir as agregações do zero a partir dos eventos | M |
| RF-54 | Endpoints de agregação: `/stats/volume`, `/stats/muscle-groups`, `/stats/heatmap` | M |
| RF-55 | `/health` checando conexão com o banco e `/version` | M |
| RF-56 | Documentação OpenAPI com descrições e exemplos de payload | M |
| RF-60 | Relay `strfry` próprio em container, publicando a política via NIP-11 | S |
| RF-61 | Write policy plugin aceitando apenas kinds do escopo e com rate limit por pubkey | C |
