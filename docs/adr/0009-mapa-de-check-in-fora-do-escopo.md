# ADR-0009 — Mapa de check-in fora do escopo obrigatório

- **Status:** Aceito
- **Data:** 17/09/2026 (registrado em arquivo em 17/10/2026)
- **Requisitos relacionados:** RNF-12

## Contexto

O `openlift-plano-de-desenvolvimento.md` v1.0 incluía um mapa de check-in em academias como item obrigatório. Esse item:

- não está na fonte de verdade do escopo (`openlift-ideacao_inicial.txt`);
- é uma frente inteira nova (mapa, geolocalização, cadastro de academias) num front-end já reconhecido como gargalo;
- carrega peso de LGPD, porque envolve geolocalização de pessoas.

## Decisão

O mapa de check-in em academia **está fora do escopo obrigatório** desta entrega e fica documentado como **evolução futura**. O app **não coleta geolocalização** de nenhuma forma (RNF-12).

## Alternativas consideradas

- **Manter o mapa como obrigatório** — compromete as entregas centrais (treino, feed, dashboard) em troca de uma funcionalidade fora da tese.
- **Versão simplificada (check-in sem mapa)** — ainda exige localização e o tratamento de LGPD correspondente.

## Consequências

- O front-end mantém a ordem rígida: treino → feed → dashboard/heatmap.
- A análise de privacidade (`docs/lgpd.md`) fica mais simples: não há dado de localização.
- Na defesa, o mapa vira capítulo de "evolução futura", o que é melhor do que um mapa meio pronto.
