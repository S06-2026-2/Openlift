# Requisitos

Requisitos do OpenLift, separados por tipo, e a matriz que liga cada um ao que foi entregue.

| Arquivo | Conteúdo |
|---|---|
| [`funcionais.md`](funcionais.md) | RF — o que o sistema faz |
| [`nao-funcionais.md`](nao-funcionais.md) | RNF — como o sistema precisa se comportar, e como verificar |
| [`regras-de-negocio.md`](regras-de-negocio.md) | RN — regras do domínio que o código precisa respeitar |
| [`rastreabilidade.md`](rastreabilidade.md) | Matriz: requisito → issue/PR → código → teste → status |

**Fonte:** a lista de requisitos nasce em [`docs/CONTEXTO.md` §7](../CONTEXTO.md#7-requisitos). Os IDs são estáveis: requisito removido não tem o número reaproveitado.

## Prioridade (MoSCoW)

- **M** — Must: obrigatório, sem isso não há produto.
- **S** — Should: importante, entra se a sprint permitir.
- **C** — Could: desejável, só se sobrar tempo.
- **W** — Won't: fora desta entrega.

## Status

| Ícone | Significado |
|---|---|
| ✅ | Feito: em `main`, com teste |
| 🟡 | Parcial: parte entregue (por exemplo, só o schema do banco ou só um dos lados) |
| ⬜ | Planejado para uma sprint específica |
| 💤 | Backlog: prioridade S/C sem sprint definida |

## Como manter

1. **Todo PR que entrega ou avança um requisito atualiza a linha dele em `rastreabilidade.md`**: status, PR e teste. Sem isso, a matriz envelhece e perde o valor.
2. A issue cita os IDs que cobre (ex.: "Requisitos: RF-12, RN-07"), como já fazem as issues do board.
3. Requisito novo ou alterado: primeiro no `docs/CONTEXTO.md` §7 (discussão no grupo), depois aqui.
4. Critério de aceite de cada sprint fica em [`docs/qa/`](../qa/); a matriz aponta para lá quando o requisito ainda está em andamento.
