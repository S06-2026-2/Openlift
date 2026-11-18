# QA — Critérios de aceite da Sprint 3

**Sprint 3:** janela no [`CONTEXTO.md` §3](../CONTEXTO.md#3-calendário--datas-inegociáveis) · **Entrega:** seguir perfis, feed de quem sigo, like e worker de agregação · **Checkpoint:** Auxílio 3

Este documento é o "Pronto quando…" de cada história da Sprint 3, escrito **antes** do desenvolvimento delas (Definition of Done, item 5). O QA valida cada história contra estes critérios antes de mover o card para *Done*. Mesmo formato do [`sprint-2.md`](sprint-2.md).

**Como usar:**

1. Copie a seção da história para a issue correspondente (campo "Critérios de aceite"). O número da issue está no título de cada seção.
2. Um critério só é marcado quando dá para **mostrar**: teste automatizado, captura de tela ou passo reproduzível. "Funcionou na minha máquina" não conta.
3. Mudou o critério durante a sprint? Atualize aqui **e** na issue, e avise no grupo. Critério alterado em silêncio não vale.

> **Cadeia de dependências:** BE-07 → BE-08 → BE-09 → BE-10 → FE-08, e NOSTR-04 → FE-07 → FE-08. O like (FE-08) é a última história a fechar, porque depende das duas cadeias. FE-09, OPS-08 e OPS-09 não dependem de nada e podem andar em paralelo.

> **Regra que atravessa a sprint (ADR-0004):** follow e like nascem como **evento assinado** no relay. O Postgres só guarda cache reconstruível. Nenhum critério abaixo é aceito se o dado social existir apenas no banco.

---

## Histórias

### NOSTR-04 (#107) — Seguir e deixar de seguir perfil (`kind 3`)

**Requisitos:** RF-30 · ADR-005 · NIP-02

- [ ] Seguir e deixar de seguir publicam um **novo** `kind 3` com a lista **completa** de seguidos (não só o delta), assinado no dispositivo
- [ ] A lista de seguidos sobrevive a logout/login e é a mesma em outro dispositivo com a mesma identidade (lida do relay ao abrir o app, não do Postgres)
- [ ] Quando há mais de um `kind 3` da mesma pessoa, vale o de `created_at` mais recente (NIP-02: evento substituível)
- [ ] `npub` inválido mostra mensagem humana; seguir a si mesmo é bloqueado; seguir quem já é seguido não publica nada
- [ ] Falha ao publicar (nenhum relay aceitou) mostra mensagem humana e não altera a lista exibida
- [ ] O `kind` vem de `nostr_kinds.dart` (`NostrKinds.contacts`), sem número solto no código
- [ ] Teste unitário da serialização do `kind 3` e do parse da lista (incluindo tag `p` malformada, que é ignorada)

### FE-07 (#112) — Feed cronológico de quem sigo

**Requisitos:** RF-31 · RF-24 · RF-51 · RNF-02 · RNF-05 · RN-03 · RN-09

- [ ] O feed substitui o `ComingSoonView` e lê os `kind 1301` dos autores da contact list (NOSTR-04), do mais novo para o mais antigo
- [ ] Cada card mostra autor, data, exercícios e volume, com o volume calculado sem as séries de aquecimento (RN-03) e a carga em kg (RN-09)
- [ ] Todo evento tem a assinatura verificada no app antes de aparecer; evento adulterado é descartado (RF-51, RNF-02), com teste
- [ ] Evento duplicado vindo de relays diferentes aparece uma vez só (RF-24); de várias versões do mesmo treino (mesmo `d`), aparece só a mais recente (RN-08)
- [ ] Paginação por `until`: rolar até o fim carrega os eventos mais antigos
- [ ] Estados de vazio ("você ainda não segue ninguém"), carregando e erro de rede com "Tentar novamente"
- [ ] 200 eventos renderizam em < 2 s, com o benchmark anotado no PR (RNF-05)
- [ ] Teste de widget do feed

### FE-08 (#113) — Curtir treino (`kind 7`, NIP-25)

**Requisitos:** RF-32 · RN-06 · NIP-25

- [ ] O botão de like publica um `kind 7` com `content` "+" e as tags `e` (evento do treino) e `p` (autor), assinado no dispositivo
- [ ] Toque duplo não publica dois likes
- [ ] A contagem atualiza na hora (otimista) e é confirmada por `GET /social/likes` depois do próximo ciclo do worker
- [ ] Falha de publicação reverte o estado otimista com mensagem humana
- [ ] Curtir o próprio treino tem comportamento definido (permitido ou bloqueado) e documentado no PR
- [ ] Teste unitário do evento `kind 7` e teste de widget do botão

### FE-09 (#114) — Correção: RPE 1–10 e paginação do histórico

**Requisitos:** RF-12 · RF-14

- [ ] RPE 0 é recusado no formulário com a mensagem "De 1 a 10", alinhado com a API, com teste
- [ ] Histórico com mais de uma página carrega a página seguinte (scroll infinito ou "Carregar mais"), com teste
- [ ] Os filtros do histórico continuam funcionando com a paginação

### BE-07 (#106) — ADR-0011: worker de sincronização com APScheduler

**Requisitos:** CONTEXTO §9, questão 7

- [ ] `docs/adr/0011-worker-de-sincronizacao.md` no formato Nygard, com Status "Aceito" e o índice de `docs/adr/` atualizado
- [ ] A §5 e a §9 do `CONTEXTO.md` refletem a decisão (questão 7 marcada como fechada)
- [ ] O TODO de Redis no `docker-compose.yml` foi removido ou ajustado conforme a decisão

### BE-08 (#109) — Cliente de relay no backend com verificação de assinatura

**Requisitos:** RF-50 · RF-51 · RNF-02 · RNF-14 · ADR-007

- [ ] Teste unitário com evento válido (aceito), evento com `sig` adulterada (descartado) e evento com `id` que não bate (descartado)
- [ ] **Todo** evento passa pela verificação antes de chegar a qualquer projeção (RNF-02: 100%)
- [ ] Relay caindo → reconecta sozinho com backoff, e o teste simula a queda (RF-50)
- [ ] Nenhuma URL de relay hardcoded: vem de `settings.NOSTR_RELAYS` (ADR-007)
- [ ] Log estruturado com `event_id` no descarte (RNF-14), sem conteúdo de chave

### BE-09 (#110) — Worker: projeção de likes no Postgres

**Requisitos:** RF-52 · RF-24 · RN-06 · ADR-004

- [ ] Dois `kind 7` do mesmo pubkey no mesmo treino contam **1** (RN-06), com teste
- [ ] O mesmo evento ingerido duas vezes não duplica linha (RF-24), com teste
- [ ] Like com `content` "-" (descurtir, NIP-25) é tratado ou explicitamente ignorado, e a escolha está documentada
- [ ] O intervalo do APScheduler é configurável por variável de ambiente
- [ ] A tabela `likes` é cache: apagar e rodar o worker de novo reconstrói a mesma contagem (ADR-004)
- [ ] Teste de integração com Postgres no CI

### BE-10 (#111) — Endpoints `/social`: registrar evento e contar likes

**Requisitos:** RF-52 · RF-56

- [ ] `GET /social/likes?event_ids=...` responde `[{event_id, count, liked_by_me}]`, autenticado e documentado no Swagger com exemplo (RF-56)
- [ ] Erros no formato `{detail, code}`
- [ ] Limite de quantidade de `event_ids` por requisição, com erro claro ao passar do limite
- [ ] Decisão sobre `POST /social/shared-events` registrada no PR (mantido ou removido), sem TODO morto no código
- [ ] Testes pytest cobrindo lista vazia, contagem e `liked_by_me`

### OPS-07 (#115) — `docker compose up` completo: migrations, seed e worker

**Requisitos:** RNF-10

- [ ] Clonar em pasta nova + `docker compose up` → app usável sem nenhum comando manual (migrations e seed na subida)
- [ ] Serviço `worker` no `docker-compose.yml` (mesma imagem, comando do APScheduler), e o mesmo no Railway/staging
- [ ] O seed é idempotente: subir duas vezes não duplica exercícios
- [ ] `docs/runbook/subir-ambiente.md` e a §4 do `CONTEXTO.md` atualizados

### OPS-08 (#116) — Logs estruturados e `/health` estendido

**Requisitos:** RNF-14 · RF-55 · RNF-01

- [ ] Logs em JSON, com `event_id` quando houver
- [ ] `/health` reporta o banco e, se existir, o status do worker
- [ ] Teste de que nenhum log contém `nsec` nem hex de 64 caracteres de chave privada (RNF-01)
- [ ] Dois PRs separados (logs e health), cada um rebaseado em `main`

### OPS-09 (#117) — Gate de cobertura de 60% no CI

**Requisitos:** RNF-07 · ADR-010

- [ ] Backend: `--cov-fail-under=60` no CI; PR com cobertura abaixo de 60% fica vermelho
- [ ] Frontend: gate equivalente sobre o `flutter test --coverage` (lcov)
- [ ] O gate é check obrigatório na branch protection

---

## Fora desta sprint (para não cobrar do lugar errado)

- **RF-52 (follows):** a projeção de **follows** no Postgres não tem issue na Sprint 3; aqui o follow vive só no `kind 3` e é lido no app. Só likes são projetados (BE-09).
- **RF-53 / RNF-06 (replay):** o comando de replay é da Sprint 4. Nesta sprint basta o critério de BE-09 de que a tabela `likes` se reconstrói rodando o worker de novo.
- **RF-33, RF-34 (perfil e ranking):** Sprint 4.

---

## Checklist de validação manual — Auxílio 3 (seguir → feed → curtir)

Rodar na **véspera**, no ambiente que será apresentado (staging, não a máquina de desenvolvimento), e de novo 1 h antes. Anotar data, quem rodou e o resultado de cada passo. O ambiente segue o [`checklist-demo.md`](../runbook/checklist-demo.md).

**Preparação**

- [ ] Ambiente sobe do zero só com `docker compose up` (OPS-07, RNF-10), com o worker rodando
- [ ] Duas contas (A e B) em dispositivos ou navegadores **separados**, e B com pelo menos 2 treinos publicados
- [ ] Relays configurados respondendo (conferir em um cliente NOSTR qualquer)
- [ ] Vídeo de fallback do fluxo completo gravado

**Fluxo**

1. [ ] **A:** feed vazio mostra "você ainda não segue ninguém" (FE-07)
2. [ ] **A:** seguir B pelo `npub` → B aparece na lista de seguidos (NOSTR-04)
3. [ ] **A:** feed mostra os treinos de B, do mais novo para o mais antigo, com volume sem aquecimento (FE-07, RN-03)
4. [ ] **A:** sair e entrar de novo, ou abrir em outro navegador com a mesma conta → continua seguindo B (NOSTR-04)
5. [ ] **A:** curtir um treino de B → a contagem sobe na hora; tocar duas vezes não conta 2 (FE-08)
6. [ ] Esperar um ciclo do worker → `GET /social/likes` confirma a contagem; o like contou **1** (RN-06)
7. [ ] **Cliente de terceiros:** o `kind 3` de A e o `kind 7` aparecem (RNF-11) → tirar captura
8. [ ] **A:** deixar de seguir B → os treinos de B somem do feed

**Falhas esperadas (mostrar que o app se comporta bem)**

- [ ] Colar um `npub` inválido → mensagem humana; colar o próprio `npub` → bloqueado
- [ ] Desligar a rede e curtir → o like volta ao estado anterior com mensagem humana
- [ ] Um evento adulterado no relay não aparece no feed nem é contado pelo worker (RNF-02)

**Segurança (antes de abrir a demo)**

- [ ] Logs da API, do worker e console do navegador sem `nsec` e sem hex de 64 caracteres (RNF-01)
- [ ] Nenhuma tela mostra chave privada

## Checklist para o Auxílio 4 (herdado da Sprint 3)

O Auxílio 4 apresenta dashboard, heatmap, ranking e relay próprio (Sprint 4), que terão critérios próprios no `sprint-4.md`. Da Sprint 3, ele precisa que continue valendo:

- [ ] O fluxo do Auxílio 3 acima roda de novo, sem regressão
- [ ] Gate de cobertura de 60% ativo e verde (OPS-09)
- [ ] `/health` mostra banco e worker (OPS-08)

---

## Registro de validação

| História | Validado por | Data | Resultado | Evidência |
|---|---|---|---|---|
| NOSTR-04 | | | | |
| FE-07 | | | | |
| FE-08 | | | | |
| FE-09 | | | | |
| BE-07 | | | | |
| BE-08 | | | | |
| BE-09 | | | | |
| BE-10 | | | | |
| OPS-07 | | | | |
| OPS-08 | | | | |
| OPS-09 | | | | |
| Checklist Auxílio 3 | | | | |
