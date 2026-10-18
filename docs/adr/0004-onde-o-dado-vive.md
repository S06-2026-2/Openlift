# ADR-0004 — Onde o dado vive: Postgres x relay

- **Status:** Aceito
- **Data:** 17/09/2026 (registrado em arquivo em 17/10/2026)
- **Requisitos relacionados:** RF-24, RF-50, RF-51, RF-52, RF-53, RF-54, RNF-06

## Contexto

O OpenLift guarda dois tipos de dado com naturezas opostas:

- **Privado e detalhado:** séries, carga, RPE, treinos não publicados. Não faz sentido como evento público.
- **Social e portátil:** treino publicado, like, follow. A tese do produto é que esse dado é do usuário e legível por qualquer cliente NOSTR.

Relays NOSTR não respondem bem a consultas agregadas como "top 10 mais curtidos da semana". Por outro lado, se o dado social existir só no nosso banco, o produto vira um app fechado com um feed pendurado do lado, e a tese se perde.

## Decisão

- **Postgres** guarda o privado (série, carga, RPE) e o **agregável** (cache de likes, ranking, estatísticas).
- **O relay** guarda o social e o portátil (eventos assinados).
- **Nada social existe apenas no Postgres.** Like, contagem e ranking têm origem obrigatória em evento assinado; as tabelas de agregação são **cache**.
- Existe um **comando de replay** que reconstrói todas as agregações do zero a partir dos eventos (RF-53).

## Alternativas consideradas

- **Tudo no Postgres, NOSTR só como "exportação"** — mais simples, mas transforma o NOSTR em enfeite e contradiz o posicionamento do produto.
- **Tudo no relay (CQRS/event sourcing completo, relay como fonte da verdade)** — previsto no `PLANO-ENGENHARIA` de agosto. Descartado por ser ambicioso demais para 6 h/semana e porque série/RPE não devem ser públicos.

## Consequências

- Toda agregação social precisa ser derivável de eventos: nenhuma coluna de contagem pode ser escrita "na mão" por endpoint.
- A ingestão verifica a assinatura de todo evento antes de projetar (RF-51) e deduplica por `event.id` (RF-24); like é idempotente por par evento + pubkey (RN-06).
- O replay precisa rodar em menos de 5 minutos (RNF-06) e é a demo ao vivo mais forte da Demo 4: apagar as tabelas de agregação e reconstruí-las.
- Dados privados nunca entram em evento; publicar é sempre ação explícita do usuário (RF-21).
