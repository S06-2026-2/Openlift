# Mini-NIP OpenLift — evento de treino (`kind 1301`)

`perfil` `NIP-101e` · **Decisão:** [ADR-0003](../adr/0003-evento-de-treino-kind-1301.md) · **Issue:** NOSTR-01 (#22)

Este documento é o **contrato de dados** entre o app, o backend e qualquer cliente NOSTR que queira ler treinos do OpenLift. Ele é um **perfil** do rascunho [NIP-101e — Workout Events](https://github.com/nostr-protocol/nips/pull/1816): não inventa kind nem tag nova; fixa o que o rascunho deixa em aberto (formato dos números, campos opcionais, vocabulário) para que a serialização seja determinística e testável.

Arquivos deste diretório:

| Arquivo | O que é |
|---|---|
| `openlift-workout-event.md` | Este documento |
| [`workout-event.schema.json`](workout-event.schema.json) | JSON Schema (2020-12) do `kind 1301` que o OpenLift emite |
| [`exercise-template.schema.json`](exercise-template.schema.json) | JSON Schema do `kind 33401` que o OpenLift emite |
| [`examples/workout-record.json`](examples/workout-record.json) | Treino de exemplo, assinado, válido contra o schema |
| [`examples/exercise-templates.json`](examples/exercise-templates.json) | Os dois modelos de exercício que o exemplo referencia |

Os exemplos foram assinados com uma chave descartável gerada na hora e nunca salva (RNF-01). O `id` e a `sig` validam segundo a NIP-01.

---

## 1. Kinds

| Kind | Nome | Tipo NIP-01 | Quem publica | Quando |
|---|---|---|---|---|
| `1301` | Registro de treino | regular | o usuário (chave local) | ao publicar um treino |
| `33401` | Modelo de exercício | endereçável | o usuário (chave local) | antes do primeiro `1301` que usa aquele exercício |

Os kinds ficam numa **constante única** em cada lado (app e backend). Nenhum número de kind aparece solto no código.

**Treino nunca é `kind 1`** (ADR-0003).

## 2. `kind 1301` — registro de treino

### 2.1 Campos do evento

| Campo | Valor |
|---|---|
| `kind` | `1301` |
| `created_at` | momento da **publicação** (segundos Unix). É o que o ranking usa (RN-04, RN-05) |
| `content` | `""` — o app ainda não tem campo de anotação. Leitores não devem depender dele |
| `tags` | tabela abaixo |

### 2.2 Tags

Ordem de emissão: a da tabela. Leitores não devem depender da ordem, **exceto** na ordem relativa das tags `exercise`, que é a ordem em que as séries foram registradas.

| Tag | Formato | Obrig. | Regra OpenLift |
|---|---|---|---|
| `d` | `["d", "<uuid-v4>"]` | sim | UUID v4 aleatório, gerado **uma vez por treino** e reutilizado se o mesmo treino for republicado após edição (ver §4). Nunca derivado de id interno |
| `title` | `["title", "<texto>"]` | sim | `Treino de DD/MM/AAAA` (data do treino) |
| `type` | `["type", "strength"]` | sim | sempre `strength` |
| `start` | `["start", "<unix>"]` | sim | 12:00 do dia do treino no fuso do dispositivo (ver §2.4) |
| `end` | `["end", "<unix>"]` | sim | igual a `start` (ver §2.4) |
| `completed` | `["completed", "true"]` | sim | sempre `true`: o OpenLift registra o que foi feito, não um plano |
| `exercise` | `["exercise", "33401:<pubkey>:<d>", "<relay>", "<kg>", "<reps>", "<rpe>", "<set_type>"]` | sim, ≥ 1 | **uma tag por série** (§2.3) |
| `alt` | `["alt", "<resumo>"]` | sim | NIP-31, obrigatória no OpenLift (§2.5) |

Tags do rascunho que o OpenLift **não emite** por enquanto: `template`, `rounds_completed`, `interval`, `pr` (RF-17, evolução futura), `t`.

**Proibido em qualquer tag ou no `content`:** e-mail, nome real, id interno do banco, localização de qualquer tipo (RNF-12, ADR-0009), `nsec` ou qualquer material de chave privada (RNF-01).

### 2.3 Tag `exercise` — uma série

```
["exercise", "33401:<pubkey>:<d-do-exercício>", "<relay>", "<kg>", "<reps>", "<rpe>", "<set_type>"]
   0            1                                 2          3       4         5        6
```

| Pos. | Campo | Formato | Regra |
|---|---|---|---|
| 1 | referência | `33401:<pubkey hex>:<d>` | aponta para o modelo de exercício publicado pela **mesma** pubkey (§3) |
| 2 | relay | `wss://…` ou `""` | primeiro relay da lista configurada (ADR-0007), onde o `33401` foi publicado |
| 3 | carga | decimal em **kg** (RN-09), `0` a `1000` (RN-07) | ponto como separador, no máximo 2 casas, **sem zero à direita** e sem `.` sobrando: `80`, `82.5`, `0` — nunca `80.0`, `80.50` |
| 4 | repetições | inteiro `1` a `500` (RN-07) | sem sinal, sem zero à esquerda |
| 5 | RPE | `1` a `10`, no máximo 1 casa, ou `""` | `""` quando a série não tem RPE registrado. Mesmo formato canônico: `8`, `8.5`, `10` |
| 6 | tipo | `warmup` \| `normal` \| `failure` | mapeia RF-13. O OpenLift não emite `drop` (não existe no app) |

Por que uma tag por série, e não `["set", …]`: é o que o NIP-101e define e o que os clientes de terceiros leem. O esboço de tags na descrição da issue #22 (`["exercise","supino-reto"]` + `["set", …]`) era anterior à leitura do rascunho e foi descartado.

### 2.4 `start` e `end`

O NIP-101e exige início e fim. O OpenLift ainda **não registra horário nem duração** (só a data do treino). Até isso existir (cronômetro, RF-18):

- `start` = `end` = **12:00 do dia do treino no fuso do dispositivo**, em segundos Unix.
- Meio-dia preserva a data do treino para quem lê em qualquer fuso entre UTC−12 e UTC+12; meia-noite faria o treino "mudar de dia" para leitores a oeste.
- Duração zero é a forma honesta de dizer "não medido". Leitores do OpenLift não exibem duração quando `start == end`.

### 2.5 Tag `alt` (NIP-31)

Texto para clientes que não entendem o `kind 1301`. Formato emitido pelo OpenLift:

```
Registro de treino de DD/MM/AAAA: <Exercício> (<n> séries), <Exercício> (<n> séries). Volume: <volume> kg.
```

- Exercícios na ordem da primeira aparição; "1 série" no singular.
- Volume segundo o RN-03 (Σ carga × repetições, sem aquecimento), formatado em pt-BR (`2.772,5`).
- O texto é para humanos: **nenhum leitor deve fazer parse da `alt`**.

### 2.6 Exemplo

[`examples/workout-record.json`](examples/workout-record.json) (abreviado):

```json
{
  "kind": 1301,
  "content": "",
  "tags": [
    ["d", "<uuid-v4>"],
    ["title", "Treino de 19/10/2026"],
    ["type", "strength"],
    ["start", "1792422000"],
    ["end", "1792422000"],
    ["completed", "true"],
    ["exercise", "33401:<pubkey>:9c086100-ba50-5108-bda5-98ea2d1d63c8", "wss://nos.lol", "40", "12", "", "warmup"],
    ["exercise", "33401:<pubkey>:9c086100-ba50-5108-bda5-98ea2d1d63c8", "wss://nos.lol", "80", "8", "7", "normal"],
    ["exercise", "33401:<pubkey>:9c086100-ba50-5108-bda5-98ea2d1d63c8", "wss://nos.lol", "80", "8", "8.5", "normal"],
    ["exercise", "33401:<pubkey>:9c086100-ba50-5108-bda5-98ea2d1d63c8", "wss://nos.lol", "80", "6", "10", "failure"],
    ["exercise", "33401:<pubkey>:06328c6a-abb8-516d-9631-2c2870f0b4d3", "wss://nos.lol", "100", "5", "8", "normal"],
    ["exercise", "33401:<pubkey>:06328c6a-abb8-516d-9631-2c2870f0b4d3", "wss://nos.lol", "102.5", "5", "", "normal"],
    ["alt", "Registro de treino de 19/10/2026: Supino reto (4 séries), Agachamento livre (2 séries). Volume: 2.772,5 kg."]
  ]
}
```

Volume: (80×8 + 80×8 + 80×6) + (100×5 + 102,5×5) = 2.772,5 kg — o aquecimento de 40 kg não entra (RN-03).

## 3. `kind 33401` — modelo de exercício

O NIP-101e referencia exercícios por endereço (`33401:<pubkey>:<d>`). O OpenLift publica, **com a chave do próprio usuário**, um modelo para cada exercício que ele usa, antes do primeiro `1301` que o referencia. Assim toda referência resolve num evento real, e um cliente de terceiros mostra o nome do exercício.

| Campo / tag | Valor |
|---|---|
| `kind` | `33401` (endereçável: republicar substitui o anterior) |
| `content` | `""` (instruções de execução: evolução futura) |
| `["d", "<uuid-v5>"]` | `UUIDv5(NS_OPENLIFT_EXERCISE, slug(nome))` — ver abaixo |
| `["title", "<nome>"]` | nome do exercício como está na biblioteca (`Supino reto`) |
| `["format", "weight", "reps", "rpe", "set_type"]` | fixo |
| `["format_units", "kg", "count", "0-10", "warmup\|normal\|drop\|failure"]` | fixo, literal do NIP-101e |
| `["equipment", "<tipo>"]` | `barbell` \| `dumbbell` \| `bodyweight` \| `machine` \| `cardio`, vindo da biblioteca de exercícios |
| `["t", "<grupo>"]` | grupo muscular no vocabulário da tabela abaixo |
| `["alt", "Modelo de exercício (NIP-101e): <nome>"]` | NIP-31 |

### `d` determinístico

- `NS_OPENLIFT_EXERCISE` = `1556e53f-1af3-5f85-97f3-b8a979c5e169` (= `UUIDv5(NAMESPACE_URL, "https://github.com/S06-2026-2/Openlift/nips/exercise")`).
- `slug(nome)`: decompõe Unicode (NFD), remove os acentos, passa para minúsculas, troca cada sequência de caracteres fora de `[a-z0-9]` por um `-` e apara `-` das pontas. `Supino reto` → `supino-reto`; `Leg press 45°` → `leg-press-45`.
- Consequência: o mesmo exercício tem o mesmo `d` em qualquer dispositivo, **sem guardar nada** — e republicar o modelo é idempotente.

Vetores de teste (todo lado que implementar deve bater):

| Nome | slug | `d` |
|---|---|---|
| `Supino reto` | `supino-reto` | `9c086100-ba50-5108-bda5-98ea2d1d63c8` |
| `Agachamento livre` | `agachamento-livre` | `06328c6a-abb8-516d-9631-2c2870f0b4d3` |

### Vocabulário de grupo muscular (`t`)

Em inglês, porque é o que o NIP-101e e os clientes de terceiros usam; o app traduz na exibição.

| Grupo na biblioteca | `t` |
|---|---|
| Peito | `chest` |
| Costas | `back` |
| Ombros | `shoulders` |
| Bíceps | `biceps` |
| Tríceps | `triceps` |
| Quadríceps | `quadriceps` |
| Posterior | `hamstrings` |
| Glúteos | `glutes` |
| Panturrilha | `calves` |
| Abdômen | `abs` |

## 4. Regras de publicação

1. **RN-01:** treino sem nenhuma série não vira evento. O serializador recusa.
2. **RN-07:** carga fora de 0–1000 kg ou repetições fora de 1–500 → o serializador recusa (o schema também).
3. **RN-09:** carga sempre em kg no evento; lb é só apresentação.
4. **Ordem:** primeiro os `33401` que faltam, depois o `1301`. Se um `33401` falhar em todos os relays, o `1301` não é publicado.
5. **RN-08 — edição:** editar um treino publicado e publicar de novo gera um **evento novo** (novo `id`, novo `created_at`) com o **mesmo `d`**. O evento antigo continua no relay. Leitores mostram, por par `(pubkey, d)`, o de maior `created_at`.
6. **Assinatura local:** o evento é assinado no dispositivo (BIP-340/Schnorr, NIP-01). O backend nunca assina nem recebe a chave privada (ADR-0006).

## 5. Leitura

Na leitura, o OpenLift é **tolerante** com eventos de terceiros e **estrito** com segurança:

| Situação | O que o leitor faz |
|---|---|
| `id` não confere ou `sig` inválida | **descarta** antes de qualquer projeção (RF-51, RNF-02) |
| Mesmo `id` vindo de vários relays | considera uma vez (RF-24) |
| Vários eventos com o mesmo `(pubkey, d)` | usa o de maior `created_at` (RN-08) |
| Sem `alt`, sem `title`, sem `start`/`end` | aceita; usa `created_at` como data |
| Tag `exercise` com menos de 5 posições ou repetições não numéricas | ignora **aquela série** |
| Carga `""` (peso corporal) | carga 0 |
| Carga negativa (assistido) | exibe; conta 0 no volume |
| RPE ausente, `""` ou inválido | sem RPE |
| `set_type` ausente ou desconhecido | `normal`; `drop` conta no volume como `normal` |
| Série fora do RN-07 | exibe, mas o evento **não entra** em ranking nem agregação |
| `created_at` > 15 min no futuro | **não entra** em ranking (RN-05) |
| Referência `33401` que não resolve | exibe o exercício como "Exercício desconhecido" |
| Nenhuma série válida | descarta o evento |

Volume na leitura: RN-03 (Σ carga × repetições das séries que não são `warmup`).

## 6. Mudanças no rascunho NIP-101e

O rascunho ainda pode mudar. Mitigação (risco da §10 do CONTEXTO):

- Kinds e nomes de tag em constantes únicas; toda a serialização num **adapter** isolado (app) e num **parser** isolado (backend).
- Se o rascunho mudar de forma incompatível, a mudança é um novo ADR que substitui o ADR-0003, e este documento ganha uma seção de versão.
