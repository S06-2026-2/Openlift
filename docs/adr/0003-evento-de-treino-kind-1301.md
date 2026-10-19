# ADR-0003 — Evento de treino `kind 1301` com mini-NIP próprio

- **Status:** Aceito
- **Data:** 19/10/2026 (decisão do `kind` em 17/09/2026; tags fixadas em NOSTR-01, #22)
- **Requisitos relacionados:** RF-20, RF-24, RF-51, RN-01, RN-03, RN-07, RN-08, RN-09, RNF-11, RNF-12

## Contexto

O treino publicado é a peça central da tese do produto: o histórico do usuário é dele, publicável e **legível por máquina** por qualquer cliente compatível. Para isso o evento precisa de um formato estruturado e estável, e o front (que serializa e assina) e o back (que lê, verifica e agrega) precisam do mesmo contrato.

O NOSTR tem um rascunho para isso, o [NIP-101e — Workout Events](https://github.com/nostr-protocol/nips/pull/1816) (PR aberto, `draft`), que define o `kind 1301` (registro de treino), o `kind 33401` (modelo de exercício) e o `kind 33402` (modelo de treino). Clientes de terceiros já leem e escrevem o `kind 1301`. O rascunho, porém, deixa em aberto o formato dos números, quais tags opcionais usar e como referenciar exercícios de uma biblioteca que não é NOSTR — exatamente o que o OpenLift precisa fixar para serializar de forma determinística.

Fatos que restringem a decisão:

- No rascunho, uma série é uma tag `["exercise", "33401:<pubkey>:<d>", "<relay>", <parâmetros>…]`, e a referência ao exercício é o **endereço de um `kind 33401`**.
- A biblioteca de exercícios do OpenLift está no Postgres (BE-03) e não existe como evento.
- O backend nunca assina eventos (ADR-0006); só o dispositivo do usuário assina.
- O app registra a data do treino, mas não o horário nem a duração; o rascunho exige `start` e `end`.

## Decisão

1. **Treino é `kind 1301`**, seguindo o NIP-101e. Publicar treino como `kind 1` está descartado.
2. O contrato fica num **mini-NIP** em [`docs/nips/openlift-workout-event.md`](../nips/openlift-workout-event.md), com JSON Schema e exemplo assinado. Ele é um **perfil** do NIP-101e: não cria kind nem tag; fixa formatos e escolhas. Os pontos principais:
   - Uma tag `exercise` **por série**: `[…, "<kg>", "<reps>", "<rpe>", "<set_type>"]`, números em formato canônico, carga sempre em kg (RN-09), limites do RN-07, RPE vazio quando não registrado.
   - Tag `alt` (NIP-31) **obrigatória** em todo evento que o OpenLift emite.
   - Cada exercício usado é publicado como `kind 33401` **com a chave do próprio usuário**, com `d` = UUIDv5 determinístico do nome do exercício, para que toda referência resolva num evento real sem guardar estado.
   - `start` = `end` = 12:00 do dia do treino no fuso do dispositivo, enquanto o app não mede duração.
   - Edição de treino publicado gera evento novo com o **mesmo `d`**; o leitor mostra o mais recente por `(pubkey, d)` (RN-08).
3. Kinds e nomes de tag ficam em **constante única**, e a serialização num **adapter isolado** (app) e num parser isolado (backend).
4. Na leitura, o OpenLift é tolerante com eventos de terceiros (campos opcionais, `drop`, peso corporal), mas **descarta** evento com `id` ou assinatura inválidos antes de qualquer projeção (RF-51).

## Alternativas consideradas

- **Treino como `kind 1` (nota de texto)** — qualquer cliente exibe, mas destrói a legibilidade por máquina, que é a tese do produto. Descartado desde o planejamento.
- **Kind próprio do OpenLift (ex.: `kind 31301`)** — liberdade total de formato, mas nenhum cliente de terceiros entende; perde o RNF-11 e o argumento de interoperabilidade.
- **Tags próprias dentro do `kind 1301`** (o esboço da issue #22: `["exercise", "supino-reto"]` + `["set", n, kg, reps, rpe, tipo]`) — mais compacto, mas incompatível com o que o NIP-101e define e com o que os clientes de terceiros leem. Usar o `kind` do padrão com tags fora do padrão seria o pior dos dois mundos.
- **Referência de exercício sem publicar o `33401`** (endereço "pendurado", só com o slug) — menos eventos, mas a referência não resolve em lugar nenhum e clientes de terceiros não conseguem mostrar o nome do exercício.
- **`33401` publicados por uma chave da plataforma** — uma biblioteca única para todos, mas exige que o backend tenha e use uma chave privada, o que contraria o ADR-0006 e cria um alvo de alto valor.
- **`d` do exercício como slug legível** (`supino-reto`) — mais simples, mas o NIP-101e pede UUID; o UUIDv5 do slug mantém o determinismo e respeita o rascunho.
- **`start`/`end` a partir do `created_at` do registro** — parece mais "real", mas mente quando o treino é registrado depois do dia em que aconteceu; meio-dia da data é honesto e preserva o dia para leitores a menos de 12 h de fuso do autor.

## Consequências

- **Interoperabilidade real:** o treino é legível por clientes que implementam o NIP-101e, e a `alt` cobre os que não implementam (RNF-11, S2-08).
- **Front e back têm um contrato testável:** o JSON Schema e o exemplo assinado viram teste de contrato nos dois lados.
- **Publicar um treino pode gerar mais de um evento** (os `33401` que faltam + o `1301`). O fluxo de publicação precisa lidar com falha parcial (§4 do mini-NIP).
- **O backend precisa expor `equipment` na biblioteca de exercícios** (exigido pelo `33401`) e guardar o `d` de cada treino publicado (RN-08) — trabalho das histórias de publicação.
- **Duração do treino não é publicada** até existir cronômetro (RF-18); `start == end` sinaliza "não medido".
- **Dependência de um rascunho:** se o NIP-101e mudar de forma incompatível, um novo ADR substitui este, e o adapter isolado limita o impacto no código.
