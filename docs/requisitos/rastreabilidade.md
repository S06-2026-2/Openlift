# Matriz de rastreabilidade

Liga cada requisito ao que foi entregue: issue, PR, código e teste. **Atualizada em 17/10/2026**, fim da Sprint 1; linhas RF-02, RF-03, RF-04 e RNF-01 revistas em 27/10/2026 (FE-04); RF-20 a RF-25, RNF-12, RN-01 e RN-08 em 28/10/2026 (FE-05). Todo PR que entrega ou avança um requisito atualiza a linha dele (ver [`README.md`](README.md)).

Legenda: ✅ feito · 🟡 parcial · ⬜ planejado · 💤 backlog (S/C sem sprint). Sprint "S2" = Sprint 2, e assim por diante. A sprint planejada segue as entregas do [`CONTEXTO.md` §3](../CONTEXTO.md#3-calendário--datas-inegociáveis).

## Resumo

| Tipo | Total | ✅ | 🟡 | ⬜ | 💤 |
|---|---|---|---|---|---|
| RF | 40 | 13 | 4 | 14 | 9 |
| RNF | 14 | 2 | 6 | 6 | 0 |
| RN | 9 | 3 | 2 | 3 | 1 |

Os requisitos **M** que ainda não estão feitos são o trabalho das Sprints 2 a 4. Os critérios de aceite da Sprint 2 estão em [`docs/qa/sprint-2.md`](../qa/sprint-2.md).

## Funcionais

| ID | Pri | Status | Issue → PR | Código | Testes |
|---|---|---|---|---|---|
| RF-01 | M | ✅ | BE-01 #23 → #37 · BE-02 #24 → #43 · FE-01 #28 → #39 · FE-02 #29 → #40 | `api/app/core/security.py`, `api/app/services/auth_service.py`, `api/app/api/v1/auth.py`, `app/lib/features/auth/`, `app/lib/core/network/api_client.dart` | `api/tests/test_security.py`, `api/tests/test_auth.py`, `app/test/features/auth/`, `app/test/core/network/api_client_test.dart` |
| RF-02 | M | ✅ | FE-04 #83 | `app/lib/features/auth/data/nostr_identity_service.dart`, `app/lib/core/nostr/nip19.dart`, sincronização em `auth_controller.dart` | `app/test/features/auth/nostr_identity_service_test.dart`, `nostr_identity_sync_test.dart`, `app/test/core/nostr/nip19_test.dart` |
| RF-03 | M | ✅ | BE-05 → #74 · FE-04 #83 | `POST /me/nostr-identity` (`api/app/api/v1/me.py`); o app registra o `npub` depois do login (`auth_repository.dart`) | `api/tests/test_nostr_identity.py`, `app/test/features/auth/nostr_identity_sync_test.dart` |
| RF-04 | S | ✅ | FE-04 #83 | Perfil → Configurações avançadas (`import_identity_sheet.dart`) | `nostr_identity_service_test.dart`, `nostr_identity_sync_test.dart` (importação) |
| RF-05 | S | 💤 | — | — | — |
| RF-10 | M | ✅ | BE-03 #25 → #44 · FE-03 #30 → #41 | `api/app/infra/db/seed.py`, `api/app/api/v1/exercises.py`, `app/lib/features/workouts/presentation/widgets/exercise_picker_sheet.dart` | `api/tests/test_exercises.py`, `app/test/features/workouts/workout_screens_test.dart` |
| RF-11 | S | 💤 | — | — | — |
| RF-12 | M | ✅ | BE-04 #26 → #45 · FE-03 #30 → #41 | `api/app/services/workout_service.py`, `api/app/api/v1/workouts.py`, `app/lib/features/workouts/presentation/workout_form_screen.dart` | `api/tests/test_workouts.py`, `app/test/features/workouts/` |
| RF-13 | S | ✅ | BE-04 #26 → #45 · FE-03 #30 → #41 | `set_type` em `api/app/domain/models/set.py`; seletor de tipo no formulário | `api/tests/test_workouts.py`, `workout_screens_test.dart` ("tipo da série") |
| RF-14 | M | 🟡 | BE-04 #26 → #45 · FE-03 #30 → #41 | API filtra por data, exercício e grupo muscular; o app filtra só por data e exercício | `api/tests/test_workouts.py`, `workout_screens_test.dart` ("filtro por exercício") |
| RF-15 | M | ✅ | BE-04 #26 → #45 · FE-03 #30 → #41 | `PATCH`/`DELETE /workouts/{id}`; edição e exclusão no histórico | `api/tests/test_workouts.py`, `workout_screens_test.dart` ("edição", "excluir") |
| RF-16 | S | 💤 | — | — | — |
| RF-17 | S | 💤 | — | — | — |
| RF-18 | C | 💤 | — | — | — |
| RF-20 | M | ✅ | NOSTR-01 #22 · BE-S2-03 #79 → #90 · FE-05 #84 | `WorkoutPublisher` monta e assina 33401 + 1301 no aparelho (`app/lib/features/social/data/workout_publisher.dart`) e envia aos relays (`nostr_relay_service.dart`); o backend registra em `shared_events` | `app/test/features/social/workout_publisher_test.dart`, `nostr_relay_service_test.dart`, `publication_flow_test.dart`; `api/tests/test_workout_publication.py` |
| RF-21 | M | ✅ | BE-04 #26 → #45 · FE-05 #84 | Seletor Privado / Publicado no formulário, só ida (`workout_form_screen.dart`); `visibility` só muda pela rota de publicação | `publication_flow_test.dart`, `api/tests/test_workouts.py` |
| RF-22 | S | 🟡 | FE-05 #84 | Resultado por relay e "Tentar novamente" manual no histórico (`publication_widgets.dart`); falta a fila automática quando a rede volta | `publication_flow_test.dart` |
| RF-23 | S | 🟡 | FE-05 #84 | Lista de relays por `--dart-define=NOSTR_RELAYS` (`app_constants.dart`), padrão do ADR-0007; sem tela de configuração | `nostr_relay_service_test.dart` |
| RF-24 | M | 🟡 S2 | BE-03 #25 → #44 | `event_id` único em `shared_events`; falta a ingestão | `api/tests/test_exercises.py` (constraints das tabelas novas) |
| RF-25 | M | ✅ | BE-04 #26 → #45 · BE-S2-03 #90 · FE-05 #84 | Status Privado / Publicado / Falha ao publicar em cada treino do histórico, vindo do `publish_status` do backend | `publication_flow_test.dart`, `api/tests/test_workout_publication.py` |
| RF-26 | C | 💤 | — | — | — |
| RF-30 | M | ⬜ S3 | — | — | — |
| RF-31 | M | ⬜ S3 | — | Tela placeholder "Social" (FE-04 #50 → #51) | — |
| RF-32 | M | ⬜ S3 | — | Tabela `likes` (BE-03 #44) | — |
| RF-33 | S | 💤 | — | — | — |
| RF-34 | S | ⬜ S4 | — | Tabela `rankings` (BE-03 #44) | — |
| RF-35 | C | 💤 | — | — | — |
| RF-40 | M | ⬜ S4 | — | Tela Início com espaço reservado (FE-04 #51) | — |
| RF-41 | M | ⬜ S4 | — | — | — |
| RF-42 | M | ⬜ S4 | — | — | — |
| RF-43 | S | ⬜ S4 | — | — | — |
| RF-50 | M | ⬜ S3 | — | — | — |
| RF-51 | M | ⬜ S2 | S2-06 (a criar) | — | Critérios em `docs/qa/sprint-2.md` |
| RF-52 | M | ⬜ S3 | — | — | — |
| RF-53 | M | ⬜ S3 | — | — | — |
| RF-54 | M | ⬜ S4 | — | — | `api/tests/test_stats.py` (só TODOs) |
| RF-55 | M | ✅ | Sprint de fundação | `/health` (faz `SELECT 1` no banco) e `/version` em `api/app/main.py` | `api/tests/test_main.py` |
| RF-56 | M | ✅ | BE-02 #24 → #43 · BE-03 #44 · BE-04 #45 | `summary`, `description`, exemplos e `error_responses()` em todas as rotas | `api/tests/test_auth.py` (OpenAPI) |
| RF-60 | S | ⬜ S4 | — | — | — |
| RF-61 | C | 💤 | — | — | — |

## Não funcionais

| ID | Status | Issue → PR | Evidência | Falta |
|---|---|---|---|---|
| RNF-01 | 🟡 S2 | OPS-02 #32 → #52 · FE-04 #83 | Gitleaks em todo PR; no app, teste do fluxo completo confere que nenhuma requisição nem `print` contém a chave privada (`nostr_identity_sync_test.dart`) | Teste com `caplog` nos logs do backend (TEST-02 #87) |
| RNF-02 | ⬜ S2 | S2-06 (a criar) | — | Teste com evento adulterado |
| RNF-03 | ⬜ | — | — | Rate limiting nos endpoints públicos (login/cadastro) |
| RNF-04 | 🟡 | FE-03 #30 → #41 | Série registrada só em estado local, sem rede até salvar | Teste de widget com timing |
| RNF-05 | ⬜ S3 | — | — | Benchmark do feed |
| RNF-06 | ⬜ S3 | — | — | Comando de replay (RF-53) + teste |
| RNF-07 | 🟡 | CI (`backend-ci.yml`) | `pytest --cov` no CI, informativo até 29/10 (ADR-0010) | Gate de 60% a partir da Sprint 3 |
| RNF-08 | ✅ | CI · OPS-03 #33 → #53 | `ruff`, `black`, `mypy` e `flutter analyze` no CI; pre-commit local | — |
| RNF-09 | ✅ | OPS-01 #31 | Branch protection: PR com 1 aprovação e checks obrigatórios | — |
| RNF-10 | 🟡 | — | `docker compose up` sobe banco, API e Adminer | Migrations e seed ainda são manuais |
| RNF-11 | ⬜ S2 | S2-08 (a criar) | — | Captura do evento num cliente de terceiros |
| RNF-12 | 🟡 S2 | ADR-0009 · FE-05 #84 | Nenhuma coleta de geolocalização no app; consentimento explícito na 1ª publicação, guardado por conta (`publication_widgets.dart`) | `docs/lgpd.md` |
| RNF-13 | 🟡 | FE-03 #30 → #41 | "Repetir última" copia a série em 1 toque (teste de widget) | Teste com 3 pessoas fora da equipe |
| RNF-14 | ⬜ | — | Branch `feat/structured-logging` em andamento, sem PR | Logs JSON correlacionáveis por `event_id` |

## Regras de negócio

| ID | Status | Issue → PR | Evidência | Falta |
|---|---|---|---|---|
| RN-01 | ✅ | FE-03 #41 · BE-S2-03 #90 · FE-05 #84 | O app não salva nem publica treino sem série; o backend recusa a publicação (422) | — |
| RN-02 | 💤 | — | — | Depende da detecção de PR (RF-17) |
| RN-03 | 🟡 | FE-03 #30 → #41 | Volume do histórico ignora aquecimento (`workout_model.dart`, teste "sem aquecimento") | Mesma regra nos endpoints de estatística (RF-54) |
| RN-04 | ⬜ S4 | — | — | Ranking por semana ISO |
| RN-05 | ⬜ S4 | — | — | Descartar `created_at` > 15 min no futuro |
| RN-06 | 🟡 S3 | BE-03 #25 → #44 | Constraint única `uq_likes_event_liker` (evento + pubkey) | Projeção de likes (RF-52) |
| RN-07 | ✅ | BE-04 #26 → #45 · FE-03 #30 → #41 | Limites nos schemas da API e nos validadores do app | — (`test_workouts.py`, `workout_screens_test.dart`) |
| RN-08 | ✅ | BE-S2-03 #90 · FE-05 #84 | Salvar treino publicado pergunta se publica a nova versão: evento novo com o mesmo `d` | — |
| RN-09 | ⬜ S2 | S2-03 (a criar) | A API já guarda a carga em `weight_kg` | Carga em kg no evento `kind 1301` |
