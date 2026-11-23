# Matriz de rastreabilidade

Liga cada requisito ao que foi entregue: issue, PR, código e teste. **Atualizada em 17/10/2026**, fim da Sprint 1; linhas RF-02, RF-03, RF-04 e RNF-01 revistas em 27/10/2026 (FE-04); RF-20 a RF-25, RNF-12, RN-01 e RN-08 em 28/10/2026 (FE-05); RF-24, RF-51 e RNF-02 em 28/10/2026 (FE-06); RF-30 em 17/11/2026 (NOSTR-04); RF-31 e RNF-05 em 17/11/2026 (FE-07); RF-32 em 17/11/2026 (FE-08); RF-12 e RF-14 em 17/11/2026 (FE-09); RF-05, RF-33, RF-41, RF-42, RF-54, RN-03 e RNF-12 em 19/11/2026 (dashboard e rede social, ADR-0012); RF-40, RF-42, RF-43, RF-53, RNF-03 e RNF-06 em 22/11/2026 (pendências da Sprint 4). Todo PR que entrega ou avança um requisito atualiza a linha dele (ver [`README.md`](README.md)).

Legenda: ✅ feito · 🟡 parcial · ⬜ planejado · 💤 backlog (S/C sem sprint). Sprint "S2" = Sprint 2, e assim por diante. A sprint planejada segue as entregas do [`CONTEXTO.md` §3](../CONTEXTO.md#3-calendário--datas-inegociáveis).

## Resumo

| Tipo | Total | ✅ | 🟡 | ⬜ | 💤 |
|---|---|---|---|---|---|
| RF | 40 | 23 | 6 | 4 | 7 |
| RNF | 14 | 5 | 7 | 2 | 0 |
| RN | 9 | 4 | 1 | 3 | 1 |

Os requisitos **M** que ainda não estão feitos são o trabalho das Sprints 2 a 4. Os critérios de aceite da Sprint 2 estão em [`docs/qa/sprint-2.md`](../qa/sprint-2.md), os da Sprint 3 em [`docs/qa/sprint-3.md`](../qa/sprint-3.md) e os da Sprint 4 em [`docs/qa/sprint-4.md`](../qa/sprint-4.md).

## Funcionais

| ID | Pri | Status | Issue → PR | Código | Testes |
|---|---|---|---|---|---|
| RF-01 | M | ✅ | BE-01 #23 → #37 · BE-02 #24 → #43 · FE-01 #28 → #39 · FE-02 #29 → #40 | `api/app/core/security.py`, `api/app/services/auth_service.py`, `api/app/api/v1/auth.py`, `app/lib/features/auth/`, `app/lib/core/network/api_client.dart` | `api/tests/test_security.py`, `api/tests/test_auth.py`, `app/test/features/auth/`, `app/test/core/network/api_client_test.dart` |
| RF-02 | M | ✅ | FE-04 #83 | `app/lib/features/auth/data/nostr_identity_service.dart`, `app/lib/core/nostr/nip19.dart`, sincronização em `auth_controller.dart` | `app/test/features/auth/nostr_identity_service_test.dart`, `nostr_identity_sync_test.dart`, `app/test/core/nostr/nip19_test.dart` |
| RF-03 | M | ✅ | BE-05 → #74 · FE-04 #83 | `POST /me/nostr-identity` (`api/app/api/v1/me.py`); o app registra o `npub` depois do login (`auth_repository.dart`) | `api/tests/test_nostr_identity.py`, `app/test/features/auth/nostr_identity_sync_test.dart` |
| RF-04 | S | ✅ | FE-04 #83 | Perfil → Configurações avançadas (`import_identity_sheet.dart`) | `nostr_identity_service_test.dart`, `nostr_identity_sync_test.dart` (importação) |
| RF-05 | S | ✅ | `feat/fe-perfil-social` · `feat/be-perfis` · `feat/be-midia` (ADR-0012) | Cadastro e edição do perfil: foto (`/media`, sem EXIF), nome de usuário único, nome e bio; salvo na API (`profiles`, NIP-05) e publicado como `kind 0` (`profile_service.dart`, `profile_form.dart`) | `app/test/features/social/profile_test.dart`, `api/tests/test_profiles.py`, `api/tests/test_media.py` |
| RF-10 | M | ✅ | BE-03 #25 → #44 · FE-03 #30 → #41 | `api/app/infra/db/seed.py`, `api/app/api/v1/exercises.py`, `app/lib/features/workouts/presentation/widgets/exercise_picker_sheet.dart` | `api/tests/test_exercises.py`, `app/test/features/workouts/workout_screens_test.dart` |
| RF-11 | S | 💤 | — | — | — |
| RF-12 | M | ✅ | BE-04 #26 → #45 · FE-03 #30 → #41 · FE-09 #114 | `api/app/services/workout_service.py`, `api/app/api/v1/workouts.py`, `app/lib/features/workouts/presentation/workout_form_screen.dart`; RPE de 1 a 10 no app e na API (`workout_validators.dart`) | `api/tests/test_workouts.py`, `app/test/features/workouts/` ("RPE 0 é recusado") |
| RF-13 | S | ✅ | BE-04 #26 → #45 · FE-03 #30 → #41 | `set_type` em `api/app/domain/models/set.py`; seletor de tipo no formulário | `api/tests/test_workouts.py`, `workout_screens_test.dart` ("tipo da série") |
| RF-14 | M | 🟡 | BE-04 #26 → #45 · FE-03 #30 → #41 · FE-09 #114 | API filtra por data, exercício e grupo muscular e pagina com `limit`/`offset`; o app filtra só por data e exercício e carrega as páginas seguintes com "Carregar mais" | `api/tests/test_workouts.py`, `workout_screens_test.dart` ("filtro por exercício", "Carregar mais"), `workout_controller_test.dart` (paginação) |
| RF-15 | M | ✅ | BE-04 #26 → #45 · FE-03 #30 → #41 | `PATCH`/`DELETE /workouts/{id}`; edição e exclusão no histórico | `api/tests/test_workouts.py`, `workout_screens_test.dart` ("edição", "excluir") |
| RF-16 | S | 💤 | — | — | — |
| RF-17 | S | 💤 | — | — | — |
| RF-18 | C | 💤 | — | — | — |
| RF-20 | M | ✅ | NOSTR-01 #22 · BE-S2-03 #79 → #90 · FE-05 #84 | `WorkoutPublisher` monta e assina 33401 + 1301 no aparelho (`app/lib/features/social/data/workout_publisher.dart`) e envia aos relays (`nostr_relay_service.dart`); o backend registra em `shared_events` | `app/test/features/social/workout_publisher_test.dart`, `nostr_relay_service_test.dart`, `publication_flow_test.dart`; `api/tests/test_workout_publication.py` |
| RF-21 | M | ✅ | BE-04 #26 → #45 · FE-05 #84 | Seletor Privado / Publicado no formulário, só ida (`workout_form_screen.dart`); `visibility` só muda pela rota de publicação | `publication_flow_test.dart`, `api/tests/test_workouts.py` |
| RF-22 | S | 🟡 | FE-05 #84 | Resultado por relay e "Tentar novamente" manual no histórico (`publication_widgets.dart`); falta a fila automática quando a rede volta | `publication_flow_test.dart` |
| RF-23 | S | 🟡 | FE-05 #84 | Lista de relays por `--dart-define=NOSTR_RELAYS` (`app_constants.dart`), padrão do ADR-0007; sem tela de configuração | `nostr_relay_service_test.dart` |
| RF-24 | M | 🟡 S2 | BE-03 #25 → #44 · FE-06 #85 | `event_id` único em `shared_events`; o app lê dos relays um evento por `id` (`nostr_relay_service.dart`, `query`); falta a ingestão no backend | `api/tests/test_exercises.py`; `app/test/features/social/nostr_relay_service_test.dart`, `network_workouts_service_test.dart` |
| RF-25 | M | ✅ | BE-04 #26 → #45 · BE-S2-03 #90 · FE-05 #84 | Status Privado / Publicado / Falha ao publicar em cada treino do histórico, vindo do `publish_status` do backend | `publication_flow_test.dart`, `api/tests/test_workout_publication.py` |
| RF-26 | C | 💤 | — | — | — |
| RF-30 | M | ✅ | NOSTR-04 #107 | Contact list `kind 3` (NIP-02) lida do relay e republicada inteira a cada mudança, assinada no aparelho (`app/lib/features/social/domain/contact_list.dart`, `data/follow_service.dart`); seguir e deixar de seguir na aba "Da rede" | `app/test/features/social/contact_list_test.dart`, `follow_flow_test.dart` |
| RF-31 | M | ✅ | FE-07 #112 | Aba Social: treinos (`kind 1301`) de quem a pessoa segue, lidos dos relays com assinatura verificada, mais novos primeiro e paginados por `until` (`feed_controller.dart`, `feed_screen.dart`) | `app/test/features/social/feed_test.dart` |
| RF-32 | M | ✅ | FE-08 #113 · BE-09 #123 · BE-10 #124 | Botão de curtir no card do feed publica um `kind 7` (NIP-25) assinado no aparelho (`like_service.dart`, `domain/like_model.dart`); contagem de `GET /social/likes` com atualização otimista (`likes_controller.dart`) | `app/test/features/social/like_test.dart`, `feed_test.dart` (grupo "curtir") |
| RF-33 | S | 🟡 | `feat/fe-perfil-social` · `feat/fe-posts` (ADR-0012) | Página de perfil por `@nome`: foto, bio, nome verificado, Seguir, grade de fotos (`kind 20`) e treinos publicados (`profile_screens.dart`). Faltam as estatísticas públicas | `app/test/features/social/profile_test.dart`, `posts_test.dart` |
| RF-34 | S | ⬜ S4 | — | Tabela `rankings` (BE-03 #44) | — |
| RF-35 | C | 💤 | — | — | — |
| RF-40 | M | ✅ | `feat/be-stats` · `feat/sprint4-pendencias` (BE-11, FE-10) | Cards do Início: volume da semana com variação, treinos no mês e sequência (streak), de `GET /stats/volume` (`dashboard_overview.dart`, `stats_service.py`) | `api/tests/test_stats.py` (streak na virada de mês e semana), `app/test/features/dashboard/dashboard_test.dart` |
| RF-41 | M | ✅ | `feat/be-stats` · `feat/fe-dashboard` | Mapa de calor grupo muscular × semana (8 semanas) no Início, com o grupo mais treinado no topo (`volume_heatmap_widget.dart`) | `app/test/features/dashboard/dashboard_test.dart`, `api/tests/test_stats.py` |
| RF-42 | M | ✅ | `feat/be-stats` · `feat/fe-dashboard` · `feat/sprint4-pendencias` | Volume em barras com seletor Semanas (8) \| Meses (6), de `GET /stats/volume?group_by=week\|month` (`volume_chart.dart`) | `api/tests/test_stats.py`, `app/test/features/dashboard/dashboard_test.dart` |
| RF-43 | S | ✅ | `feat/be-stats` · `feat/fe-dashboard` (BE-12) | `GET /stats/muscle-groups` com volume, séries e dias treinados por grupo; frequência por grupo e mapa de calor no Início (`muscle_frequency_chart.dart`) | `api/tests/test_stats.py`, `app/test/features/dashboard/dashboard_test.dart` |
| RF-50 | M | ⬜ S3 | — | — | — |
| RF-51 | M | 🟡 S2 | FE-06 #85 | O app verifica `id` e assinatura de todo evento lido antes de exibir (`network_workouts_service.dart`); falta a ingestão no backend (RF-50, S3) | `network_workouts_service_test.dart`, `network_feed_test.dart` (evento adulterado) |
| RF-52 | M | ⬜ S3 | — | — | — |
| RF-53 | M | ✅ | `feat/sprint4-pendencias` (BE-14) | `python -m app.cli replay [--dry-run]`: apaga `likes`/`rankings` e reprojeta os `kind 7` dos relays com a projeção do worker; não apaga nada se nenhum relay responder (`replay_service.py`, `cli.py`, `docs/runbook/replay.md`) | `api/tests/test_replay.py` |
| RF-54 | M | ✅ | `feat/be-stats` | `GET /stats/volume`, `/stats/muscle-groups` e `/stats/heatmap`, consulta direta ao Postgres sem cache (ADR-0011) (`stats_service.py`) | `api/tests/test_stats.py` |
| RF-55 | M | ✅ | Sprint de fundação | `/health` (faz `SELECT 1` no banco) e `/version` em `api/app/main.py` | `api/tests/test_main.py` |
| RF-56 | M | ✅ | BE-02 #24 → #43 · BE-03 #44 · BE-04 #45 | `summary`, `description`, exemplos e `error_responses()` em todas as rotas | `api/tests/test_auth.py` (OpenAPI) |
| RF-60 | S | ⬜ S4 | — | — | — |
| RF-61 | C | 💤 | — | — | — |

## Não funcionais

| ID | Status | Issue → PR | Evidência | Falta |
|---|---|---|---|---|
| RNF-01 | 🟡 S2 | OPS-02 #32 → #52 · FE-04 #83 | Gitleaks em todo PR; no app, teste do fluxo completo confere que nenhuma requisição nem `print` contém a chave privada (`nostr_identity_sync_test.dart`) | Teste com `caplog` nos logs do backend (TEST-02 #87) |
| RNF-02 | 🟡 S2 | FE-06 #85 | No app, evento adulterado é descartado e contado na aba "Da rede" (`network_workouts_service_test.dart`, `network_feed_test.dart`) | O mesmo na ingestão do backend (S3) |
| RNF-03 | ✅ | `feat/sprint4-pendencias` (OPS-05) | Limite por IP em `/auth` (10/min) e em `/social`, `/profiles`, `/media` (120/min), 429 `rate_limited` com `Retry-After` (`core/rate_limit.py`, `api/tests/test_rate_limit.py`) | — |
| RNF-04 | 🟡 | FE-03 #30 → #41 | Série registrada só em estado local, sem rede até salvar | Teste de widget com timing |
| RNF-05 | ✅ | FE-07 #112 | 200 eventos do feed renderizados em 284 ms no `flutter test` (teste "RNF-05" em `feed_test.dart`), com `ListView.builder` | Repetir a medição num aparelho real antes da Demo 4 |
| RNF-06 | ✅ | `feat/sprint4-pendencias` (BE-14) | Replay em 6,1 s com 10 treinos e três relays públicos (22/11/2026, `docs/runbook/replay.md`) | Repetir a medição com o seed da demo |
| RNF-07 | 🟡 | CI (`backend-ci.yml`) | `pytest --cov` no CI, informativo até 29/10 (ADR-0010) | Gate de 60% a partir da Sprint 3 |
| RNF-08 | ✅ | CI · OPS-03 #33 → #53 | `ruff`, `black`, `mypy` e `flutter analyze` no CI; pre-commit local | — |
| RNF-09 | ✅ | OPS-01 #31 | Branch protection: PR com 1 aprovação e checks obrigatórios | — |
| RNF-10 | 🟡 | — | `docker compose up` sobe banco, API e Adminer | Migrations e seed ainda são manuais |
| RNF-11 | ⬜ S2 | S2-08 (a criar) | — | Captura do evento num cliente de terceiros |
| RNF-12 | 🟡 S2 | ADR-0009 · FE-05 #84 · ADR-0012 | Nenhuma coleta de geolocalização no app; consentimento explícito na 1ª publicação, guardado por conta (`publication_widgets.dart`); fotos recodificadas sem EXIF/GPS na API (`media_service.py`) e aviso de que o perfil e as fotos são públicos | `docs/lgpd.md`, `api/tests/test_media.py` ("remove EXIF e GPS") |
| RNF-13 | 🟡 | FE-03 #30 → #41 | "Repetir última" copia a série em 1 toque (teste de widget) | Teste com 3 pessoas fora da equipe |
| RNF-14 | ⬜ | — | Branch `feat/structured-logging` em andamento, sem PR | Logs JSON correlacionáveis por `event_id` |

## Regras de negócio

| ID | Status | Issue → PR | Evidência | Falta |
|---|---|---|---|---|
| RN-01 | ✅ | FE-03 #41 · BE-S2-03 #90 · FE-05 #84 | O app não salva nem publica treino sem série; o backend recusa a publicação (422) | — |
| RN-02 | 💤 | — | — | Depende da detecção de PR (RF-17) |
| RN-03 | ✅ | FE-03 #30 → #41 · `feat/be-stats` | Volume do histórico e dos endpoints de estatística ignora aquecimento (`workout_model.dart`, `stats_service.py`) | `api/tests/test_stats.py` ("sem aquecimento"), testes do histórico |
| RN-04 | ⬜ S4 | — | — | Ranking por semana ISO |
| RN-05 | ⬜ S4 | — | — | Descartar `created_at` > 15 min no futuro |
| RN-06 | 🟡 S3 | BE-03 #25 → #44 | Constraint única `uq_likes_event_liker` (evento + pubkey) | Projeção de likes (RF-52) |
| RN-07 | ✅ | BE-04 #26 → #45 · FE-03 #30 → #41 | Limites nos schemas da API e nos validadores do app | — (`test_workouts.py`, `workout_screens_test.dart`) |
| RN-08 | ✅ | BE-S2-03 #90 · FE-05 #84 | Salvar treino publicado pergunta se publica a nova versão: evento novo com o mesmo `d` | — |
| RN-09 | ⬜ S2 | S2-03 (a criar) | A API já guarda a carga em `weight_kg` | Carga em kg no evento `kind 1301` |
