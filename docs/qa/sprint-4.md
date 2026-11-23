# QA — Critérios de aceite da Sprint 4

**Sprint 4:** 10/11 → 23/11 ([`CONTEXTO.md` §3](../CONTEXTO.md#3-calendário--datas-inegociáveis)) · **Entrega:** dashboard, mapa de calor, replay e rede social · **Checkpoint:** Auxílio 4 — 23/11

Este documento é o "Pronto quando…" de cada história da Sprint 4, no mesmo formato do [`sprint-3.md`](sprint-3.md). Ele foi escrito com a sprint já em andamento (Definition of Done, item 5, cumprido com atraso). Os critérios do backlog original foram mantidos, e os das histórias de rede social vêm do [ADR-0012](../adr/0012-rede-social-perfil-fotos-comentarios.md).

**Como usar:**

1. Copie a seção da história para a issue correspondente (campo "Critérios de aceite").
2. Um critério só é marcado quando dá para **mostrar**: teste automatizado, captura de tela ou passo reproduzível.
3. Mudou o critério? Atualize aqui **e** na issue, e avise no grupo.

> **Cadeias:**
> - estatísticas: BE-11 → BE-12 → BE-13 → FE-10 → FE-11;
> - replay: BE-09 (Sprint 3) → BE-14;
> - rede social: ADR-0012 → perfis e fotos no backend → perfil, posts e comentários no app.

> **Regra que atravessa a sprint (ADR-0004):**
> - estatística de treino é dado privado e vem do Postgres;
> - curtida, comentário e post nascem como **evento assinado** no relay;
> - o Postgres só guarda cache reconstruível (BE-14) e o diretório de nomes (ADR-0012).

---

## Histórias

### BE-11 — `GET /stats/volume`: volume semanal/mensal, treinos no mês e sequência

**Requisitos:** RF-40 · RF-42 · RF-54 · RN-03

- [ ] `group_by=week|month` e `periods` (1–52); semanas ISO e meses do mais antigo ao que contém `date_to`, com os períodos sem treino zerados
- [ ] Série de aquecimento não entra no volume (RN-03), com teste
- [ ] `workouts_this_month` conta os treinos do mês de `date_to`, até ele, com teste
- [ ] `streak_days` conta dias consecutivos com treino, com teste na virada de mês e de semana ISO; sem treino hoje, a sequência de ontem continua valendo
- [ ] Isolamento por usuário: outro usuário não vê meus números
- [ ] Swagger com exemplo

### BE-12 — `GET /stats/muscle-groups`: volume e frequência por grupo muscular

**Requisitos:** RF-43 · RF-54 · RN-03

- [ ] Todos os grupos do seed aparecem, com 0 quando não há volume, do mais treinado ao menos
- [ ] Traz volume, séries válidas e dias treinados por grupo
- [ ] Testes cobrindo período vazio, aquecimento e período invertido (422)

### BE-13 — `GET /stats/heatmap`: grupo muscular × período

**Requisitos:** RF-41 · RF-54

- [ ] Células `{date, muscle_group, volume}` só para dias com volume, mais a lista de grupos
- [ ] Janela máxima de 366 dias, com 422 `date_range_too_long` acima disso
- [ ] Resposta em < 500 ms com o seed de demo, anotada no PR
- [ ] Testes pytest, inclusive de isolamento por usuário

### FE-10 — Dashboard: cards de resumo e gráfico de volume

**Requisitos:** RF-40 · RF-42 · RF-43

- [ ] Cards de volume da semana (com variação), treinos no mês, sequência e músculo mais treinado
- [ ] Gráfico de barras com seletor Semanas | Meses
- [ ] Estados de carregando, vazio (usuário sem treino) e erro com "Tentar novamente"
- [ ] Valores batem com a API em um usuário de teste, com captura de tela no PR
- [ ] Teste de widget dos cards e do seletor

### FE-11 — Mapa de calor de volume por grupo muscular

**Requisitos:** RF-41

- [ ] Cor proporcional ao volume, com legenda da escala
- [ ] Seletor Semanas (8) | Meses (6), com o grupo mais treinado no topo e destacado
- [ ] Funciona em largura de celular (rolagem horizontal) e na web
- [ ] Teste de widget com dados fixos nos dois modos

### BE-14 — Replay: reconstruir agregações a partir dos eventos

**Requisitos:** RF-53 · RNF-06 · ADR-004

- [ ] `python -m app.cli replay` apaga `likes` (e `rankings`) e reprojeta os `kind 7` dos relays com a mesma função do worker
- [ ] Teste: agregação → apaga → replay → mesma contagem
- [ ] Nenhum relay respondendo → nada é apagado e o comando sai com erro
- [ ] `--dry-run` mostra o resultado sem gravar
- [ ] Roda em < 5 min com os dados da demo (RNF-06), com o tempo anotado
- [ ] Runbook `docs/runbook/replay.md`

### OPS-05 — Rate limiting nos endpoints públicos

**Requisitos:** RNF-03

- [ ] Limite por IP em `/auth/*` e nos endpoints sociais (`/social`, `/profiles`, `/media`), configurável por variável de ambiente
- [ ] Teste de integração: N+1 requisições → 429 no formato `{detail, code}` com `Retry-After`
- [ ] Atrás de proxy (staging), cada cliente tem o próprio limite (`X-Forwarded-For`)

### ADR-0012 — Rede social com perfil, fotos e comentários

- [ ] ADR em `docs/adr/` aprovado pelo grupo (status passa de "Proposto" para "Aceito")

### Perfis e fotos no backend (ADR-0012)

**Requisitos:** RF-05 · RNF-12

- [ ] Nome de usuário único (3–20 de `a-z0-9_.`, guardado em minúsculas); nome em uso → 409
- [ ] `/.well-known/nostr.json` responde no formato NIP-05
- [ ] Busca por nome de usuário e perfis por chave pública
- [ ] Foto em JPEG/PNG/WebP até 5 MB, recodificada **sem EXIF/GPS**, com teste que prova que o GPS existia e sumiu
- [ ] Migrations sobem e descem (`upgrade` → `downgrade -1` → `upgrade`)

### Rede social no app (ADR-0012)

**Requisitos:** RF-05 · RF-33 · RNF-12

- [ ] Sem perfil, a aba Social abre o cadastro (foto, nome de usuário, nome e bio), com aviso de que o conteúdo é público
- [ ] Salvar perfil publica `kind 0` com `nip05`
- [ ] Buscar pessoas pelo `@nome`, abrir o perfil e seguir
- [ ] Postar foto publica `kind 20` (NIP-68) com `imeta`, nunca `kind 1`
- [ ] Curtir foto publica `kind 7` com `k=20`; comentar publica `kind 1111` (NIP-22); os dois são lidos dos relays com assinatura verificada
- [ ] Testes de unidade dos eventos e de widget dos fluxos

### BE-15 / FE-12 — Ranking semanal · OPS-04 — Relay próprio

Candidatos a corte (S). Se entrarem, valem os critérios do backlog: RN-04, RN-05 e RN-07 testados no ranking; o relay sobe com `docker compose up` e tem runbook.

---

## Fora desta sprint (para não cobrar do lugar errado)

- A aba **Perfil** continua "em breve": os dados do perfil entram na próxima sprint.
- Moderação, denúncia e apagar post/comentário (`kind 5`) estão fora do escopo (ADR-0012).
- Sprint 5 é congelamento: nenhuma feature nova depois de 23/11.

## Checklist de validação manual — Auxílio 4

Rodar na **véspera**, no staging, e de novo 1 h antes.

**Preparação**

- [ ] Conta com pelo menos 4 semanas de treinos em grupos musculares diferentes
- [ ] Volume e variáveis do Railway configurados (`MEDIA_DIR`, `PUBLIC_BASE_URL`)
- [ ] Duas contas (A e B) em navegadores separados

**Fluxo**

1. [ ] **Início:** cards (volume da semana, treinos no mês, sequência, músculo mais treinado) batem com o histórico
2. [ ] **Início:** volume troca entre Semanas e Meses; mapa de calor troca entre Semanas e Meses
3. [ ] **A:** criar perfil com foto; tentar um nome já usado por B → recusado
4. [ ] **A:** postar foto com legenda → aparece no feed; abrir a foto → sem localização no arquivo
5. [ ] **B:** buscar A pelo `@nome`, seguir, curtir e comentar a foto
6. [ ] **Replay:** apagar `likes` no Adminer → rodar `python -m app.cli replay` → as curtidas de treino voltam
7. [ ] **Rate limiting:** 11 logins errados seguidos → mensagem "Muitas tentativas seguidas"

**Segurança**

- [ ] Logs sem `nsec` e sem hex de 64 caracteres de chave privada (RNF-01)

## Registro de validação

| História | Data | Quem validou | Resultado | Evidência |
|---|---|---|---|---|
| | | | | |
