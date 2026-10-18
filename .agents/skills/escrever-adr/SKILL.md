---
name: escrever-adr
description: Rascunhar um Architecture Decision Record (ADR) do OpenLift no formato Nygard, a partir de uma decisão já tomada pelo grupo. O rascunho é sempre revisado por uma pessoa antes do PR.
---

# Skill — escrever ADR

Use quando o grupo **já tomou** uma decisão de arquitetura e ela precisa ser registrada. Esta skill **não decide nada**: se a decisão ainda está em aberto, pare e liste as opções para o grupo, sem escolher.

## Entradas que você precisa receber

1. A decisão, em uma ou duas frases.
2. O motivo (de preferência a linha da tabela em `docs/CONTEXTO.md` §5, ou a ata da reunião).
3. As alternativas que foram discutidas, se houver.
4. Os requisitos afetados (RF/RNF/RN de `docs/CONTEXTO.md` §7).

Se faltar o motivo ou a decisão estiver ambígua, **pergunte** em vez de inventar.

## Passos

1. Leia `docs/adr/README.md` (modelo e próximo número livre) e `docs/CONTEXTO.md` §5 (ADRs vigentes).
2. Confira se a decisão contradiz um ADR aceito. Se sim, **não edite o ADR antigo**: o novo ADR deve dizer "Substitui ADR-NNNN", e o grupo precisa aprovar.
3. Crie `docs/adr/NNNN-titulo-curto.md` com as seções, nesta ordem:
   - **Status** (`Proposto`), **Data**, **Requisitos relacionados**
   - **Contexto** — fatos e forças que obrigam a decidir. Sem opinião.
   - **Decisão** — voz ativa, concreta ("O app faz…", "Usamos…").
   - **Alternativas consideradas** — cada uma com o motivo de não ter sido escolhida.
   - **Consequências** — o que fica mais fácil, o que fica mais difícil, e o trabalho que a decisão gera.
4. Atualize a tabela de `docs/adr/README.md`.

## Regras

- Português, frases curtas, sem jargão desnecessário.
- Não invente números, datas, ferramentas ou alternativas que não estejam nas entradas; se precisar sugerir uma alternativa, marque como *sugestão para o grupo revisar*.
- Um ADR por arquivo e por PR.
- Nunca inclua segredo, chave ou dado pessoal.
- O status só vira **Aceito** quando o PR é aprovado pelo grupo — não marque como aceito no rascunho.

## Saída

O arquivo do ADR e um resumo de 3 linhas para a descrição do PR: decisão, motivo principal e principal consequência.

## Exemplo

[`examples/exemplo-entrada-e-saida.md`](examples/exemplo-entrada-e-saida.md) mostra a entrada recebida e o ADR gerado. ADRs reais do projeto, para comparar o tom: [`docs/adr/`](../../../docs/adr/).
