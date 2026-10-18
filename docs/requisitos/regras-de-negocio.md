# Regras de negócio (RN)

Fonte: [`docs/CONTEXTO.md` §7](../CONTEXTO.md#7-requisitos). O status de cada uma está na [matriz de rastreabilidade](rastreabilidade.md).

| ID | Regra |
|---|---|
| RN-01 | Treino sem nenhuma série registrada não pode ser publicado |
| RN-02 | PR só conta se a série for do tipo `normal` ou `failure` — aquecimento não conta |
| RN-03 | Volume = Σ (carga × repetições), apenas de séries não-aquecimento |
| RN-04 | Ranking considera apenas eventos com `created_at` dentro da semana ISO corrente |
| RN-05 | Ranking desconsidera eventos com `created_at` no futuro (> 15 min à frente do relógio do servidor) |
| RN-06 | Like é idempotente: múltiplos `kind 7` do mesmo pubkey no mesmo evento contam 1 |
| RN-07 | Carga máxima aceita 1000 kg, repetições máximo 500 — acima disso é erro de digitação ou abuso |
| RN-08 | Edição de treino já publicado gera **novo** evento; o anterior permanece (imutabilidade do protocolo) |
| RN-09 | Unidade de carga no evento é sempre **kg**; conversão para lb é apresentação |

## Por que RN-04, RN-05 e RN-07 importam na defesa

Ranking sobre dado auto-reportado e assinado por qualquer um é **inerentemente falsificável**: qualquer pessoa pode assinar "1000 kg no supino". As mitigações realistas são:

- ranking só entre perfis seguidos (RF-34);
- limites de plausibilidade (RN-07) e janela de tempo (RN-04, RN-05);
- detecção de outlier.

O ranking não é confiável, e a documentação explica por quê e o que foi feito a respeito, em vez de fingir o contrário.
