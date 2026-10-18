# QA — Critérios de aceite da Sprint 2

**Sprint 2:** 20/10 → 29/10 · **Entrega:** identidade + treino publicado como evento no relay + lido em outro dispositivo · **Checkpoint:** Demo 3 — 29/10

Este documento é o "Pronto quando…" de cada história da Sprint 2, escrito **antes** da sprint começar (Definition of Done, item 5). O QA valida cada história contra estes critérios antes de mover o card para *Done*.

**Como usar:**

1. Ao criar o card de cada história no board, copie a seção correspondente para a issue (campo "Critérios de aceite").
2. Um critério só é marcado quando dá para **mostrar**: teste automatizado, captura de tela ou passo reproduzível. "Funcionou na minha máquina" não conta.
3. Mudou o critério durante a sprint? Atualize aqui **e** na issue, e avise no grupo. Critério alterado em silêncio não vale.

> **Dependência crítica:** S2-03, S2-04 e S2-06 dependem do mini-NIP do evento `kind 1301` (NOSTR-01, #22). Enquanto ele não fechar, os critérios abaixo citam "o mini-NIP" sem fixar nomes de tags, de propósito: a decisão é do Dev NOSTR + PO (ADR-003), não do QA.

---

## Histórias

### S2-01 — Identidade NOSTR gerada no dispositivo

**Requisitos:** RF-02 · ADR-005 · ADR-006 · RNF-01

- [ ] No primeiro login de um usuário sem identidade, o app gera um par de chaves secp256k1 **no dispositivo**, sem chamada ao servidor para gerar a chave
- [ ] Logins seguintes reutilizam o mesmo par: o `npub` exibido/registrado não muda entre sessões no mesmo dispositivo
- [ ] Em nenhuma tela do fluxo padrão aparece a palavra "chave", `nsec` ou hex da chave privada (a identidade é invisível ao usuário comum)
- [ ] A chave privada fica no armazenamento seguro da plataforma (`flutter_secure_storage`; na web, armazenamento do navegador, conforme ADR-006) e nunca é enviada ao backend
- [ ] Teste automatizado comprova que a chave privada não aparece em log nem em requisição HTTP (RNF-01: grep de `nsec` e de hex de 64 caracteres)

### S2-02 — Registro do `npub` no backend

**Requisitos:** RF-03 · ADR-005

- [ ] `POST /api/v1/me/nostr-identity` com usuário autenticado registra o `npub` e responde com o `UserOut` já contendo o `npub`
- [ ] Sem token → 401 no formato padrão `{detail, code}`; `npub` malformado → 422 com o campo indicado
- [ ] O corpo da requisição aceita **somente** a chave pública: enviar qualquer campo de chave privada é recusado (422), e o teste cobre isso
- [ ] Repetir o registro com o mesmo `npub` é idempotente (não duplica linha em `nostr_identities`)
- [ ] Endpoint documentado no Swagger com exemplo de payload (RF-56) e testes no pytest

### S2-03 — Treino serializado como evento `kind 1301`

**Requisitos:** RF-20 · ADR-003 · RN-01 · RN-03 · RN-09

- [ ] Um treino com séries vira um evento `kind 1301` cujas tags seguem **exatamente** o mini-NIP em `docs/nips/`, incluindo a tag `alt` (NIP-31)
- [ ] Carga sempre em **kg** no evento (RN-09); séries de aquecimento são identificadas pelo tipo, conforme o mini-NIP
- [ ] Treino sem nenhuma série **não** gera evento: o app bloqueia a publicação com mensagem humana (RN-01)
- [ ] O evento é assinado localmente e o `id`/`sig` validam segundo a NIP-01 (teste unitário com evento conhecido)
- [ ] A serialização fica isolada num adapter único, com o `kind` numa constante (mitigação do risco "rascunho NIP-101e mudar")

### S2-04 — Publicar treino nos relays

**Requisitos:** RF-20 · RF-23 · ADR-007

- [ ] Botão "Publicar" no treino envia o evento assinado aos relays configurados; o usuário vê sucesso ou falha **por relay**
- [ ] A lista de relays vem de configuração (variável de ambiente/constante única), sem URL de relay espalhada no código (ADR-007)
- [ ] Relay fora do ar não trava a tela: timeout com mensagem humana e os demais relays continuam
- [ ] Publicar o mesmo treino duas vezes não gera dois eventos diferentes para o mesmo conteúdo sem o usuário pedir (sem duplicata acidental por toque duplo)
- [ ] O `event_id` publicado fica salvo no treino (`shared_events`), para a leitura e o replay futuros (ADR-004)

### S2-05 — Visibilidade e status de publicação

**Requisitos:** RF-21 · RF-25 · RN-08

- [ ] Todo treino nasce **privado**; só é publicado por ação explícita do usuário (RF-21)
- [ ] Cada treino mostra um indicador de status: local / publicado / falhou (RF-25), e o status sobrevive a fechar e abrir o app
- [ ] Treino com status "falhou" oferece "Tentar novamente"
- [ ] Editar um treino já publicado e publicar de novo gera um **novo** evento; o anterior permanece (RN-08), e o app avisa isso antes de publicar
- [ ] O backend aceita alterar `publish_status` só pelos fluxos de publicação, não por edição comum do treino

### S2-06 — Ler treinos publicados em outro dispositivo

**Requisitos:** RF-50 (parcial) · RF-51 · RNF-02 · RF-24

- [ ] No dispositivo B, logado com outra conta, é possível ver o treino publicado no dispositivo A (leitura por pubkey nos relays)
- [ ] Todo evento lido tem a assinatura **verificada** antes de ser exibido; evento adulterado é descartado (teste unitário com evento adulterado — RNF-02)
- [ ] Eventos repetidos vindos de relays diferentes aparecem uma vez só (deduplicação por `event.id`, RF-24)
- [ ] O treino lido mostra data, exercícios, séries e volume calculado igual ao do dispositivo A (RN-03)
- [ ] Sem relay disponível, a tela mostra estado de erro humano com "Tentar novamente", não lista vazia silenciosa

### S2-07 — Consentimento na primeira publicação

**Requisitos:** RNF-12

- [ ] Na **primeira** publicação, o app explica em linguagem simples que o treino ficará público e permanente na rede aberta, e só publica após confirmação explícita
- [ ] Recusar o consentimento cancela a publicação; o treino continua local
- [ ] O aceite fica registrado (não pergunta de novo a cada publicação), e o teste de widget cobre aceitar e recusar
- [ ] Nenhuma geolocalização é coletada ou incluída no evento

### S2-08 — Interoperabilidade com cliente de terceiros

**Requisitos:** RNF-11 · ADR-003

- [ ] O treino publicado pelo OpenLift aparece em pelo menos **um** cliente NOSTR de terceiros (Groundwork ou My Fitness do Amethyst, por exemplo), com a captura de tela anexada à issue
- [ ] Clientes que não entendem `kind 1301` exibem o texto da tag `alt`, legível por humanos
- [ ] Captura registrada para a Demo 3 em `docs/qa/evidencias/` (ou anexada à issue)

---

## Checklist de validação manual — Demo 3 (publicar em A, ler em B)

Rodar no dia **28/10** (véspera), no ambiente que será apresentado, e de novo 1 h antes da demo. Anotar data, quem rodou e o resultado de cada passo.

**Preparação**

- [ ] Ambiente sobe do zero com `docker compose up -d` + `alembic upgrade head` + seed (RNF-10)
- [ ] Dois dispositivos ou navegadores **separados** (A e B, por exemplo Chrome e uma janela anônima ou outro celular), cada um com uma conta diferente
- [ ] Relays configurados respondendo (conferir em um cliente NOSTR qualquer)
- [ ] Vídeo de fallback do fluxo completo gravado

**Fluxo**

1. [ ] **A:** criar conta nova → entra direto no app, sem nenhuma menção a chave
2. [ ] **A:** registrar um treino com 2 exercícios e 3 séries (uma de aquecimento) → aparece no histórico como **local**
3. [ ] **A:** publicar → aparece o consentimento (primeira vez) → aceitar → status muda para **publicado**, com retorno por relay
4. [ ] **A:** fechar e reabrir o app → treino continua **publicado**
5. [ ] **B:** entrar com a outra conta → localizar os treinos de A → o treino aparece com as mesmas séries e o mesmo volume (aquecimento fora do volume)
6. [ ] **Cliente de terceiros:** o mesmo evento aparece (RNF-11) → tirar captura
7. [ ] **A:** editar o treino e publicar de novo → avisa que gera novo evento → B passa a ver a versão nova; o evento antigo continua existindo (RN-08)
8. [ ] **A:** tentar publicar um treino sem séries → bloqueado com mensagem humana (RN-01)

**Falhas esperadas (mostrar que o app se comporta bem)**

- [ ] Desligar a rede em A e publicar → status **falhou** + "Tentar novamente"; religar e tentar → **publicado**
- [ ] Um relay da lista fora do ar → os demais publicam e o app mostra qual falhou

**Segurança (antes de abrir a demo)**

- [ ] Logs da API e console do navegador sem `nsec` e sem hex de 64 caracteres (RNF-01)
- [ ] Nenhuma tela mostra chave privada

---

## Registro de validação

| História | Validado por | Data | Resultado | Evidência |
|---|---|---|---|---|
| S2-01 | | | | |
| S2-02 | | | | |
| S2-03 | | | | |
| S2-04 | | | | |
| S2-05 | | | | |
| S2-06 | | | | |
| S2-07 | | | | |
| S2-08 | | | | |
| Checklist Demo 3 | | | | |
