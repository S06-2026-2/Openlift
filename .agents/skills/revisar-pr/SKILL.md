---
name: revisar-pr
description: Revisar um pull request do OpenLift contra as regras do projeto — escopo da issue, regras invioláveis do AGENTS.md, ADRs, padrões de backend/frontend, testes, Definition of Done e declaração de uso de IA. Produz um comentário de revisão objetivo; não aprova nem mergeia.
---

# Skill — revisar PR

Use para preparar a revisão de um PR (seu ou de outra pessoa). A saída é um **rascunho de comentário**: quem aprova é sempre uma pessoa do time, e o autor do PR não aprova o próprio PR.

## Entradas

- O número do PR ou a branch, e a issue que ele fecha (`Closes #N`).
- O diff (`git diff main...<branch>`) e a descrição do PR.

## Passo a passo

1. **Escopo.** Leia a issue e os critérios de aceite. O PR faz o que a issue pede e só isso? Arquivo alterado sem relação com a issue é apontado.
2. **Regras invioláveis** (`AGENTS.md`). Confira uma por uma, principalmente:
   - nenhuma chave privada / `nsec` / hex de 64 caracteres em código, log, teste ou payload;
   - evento de treino só como `kind 1301` com `alt`, seguindo `docs/nips/`;
   - nada social gravado só no Postgres (ADR-0004);
   - nenhum dado de geolocalização.
3. **ADRs.** Alguma mudança contradiz um ADR de `docs/adr/`? Se sim, o PR para até o grupo decidir.
4. **Código.**
   - Backend: rota fina, regra no service, `ApiError` com `{detail, code}`, filtro por `current_user.id` (404 para recurso alheio), limites do RN-07 no schema, migration revisada (CHECK e nome de FK).
   - Frontend: camadas `data/domain/presentation`, erro como `ApiException` com mensagem humana, widgets e tema do design system, sem cor solta.
5. **Testes.** Existe teste para o caminho principal e para cada critério de aceite? Os testes têm `expect`/`assert` que realmente verificam algo? Algum teste foi enfraquecido para passar?
6. **Definition of Done** (README): lint, CI verde, documentação atualizada se mudou comportamento ou instalação.
7. **Descrição do PR.** Segue o template? Tem `Closes #N`? A seção **Uso de IA** diz ferramenta, o que foi gerado **e** o que a pessoa revisou (campo vazio ou genérico é apontado)?
8. **Commits.** Conventional Commits; o título do PR também, porque vira o commit do squash.

## Formato da saída

```markdown
## Revisão — PR #N (issue #M)

**Resumo:** uma ou duas frases sobre o que o PR faz e se cumpre a issue.

### Bloqueia o merge
- `caminho/arquivo.py:42` — o problema, por que importa, e a sugestão.

### Sugestões (não bloqueiam)
- ...

### Conferido
- [x] Escopo da issue
- [x] Regras invioláveis
- [ ] Testes cobrem os critérios de aceite — falta o caso X
- [x] Uso de IA declarado
```

## Regras

- Aponte arquivo e linha. "Melhorar o código" sem local e sem motivo não é revisão.
- Separe o que **bloqueia** (bug, regra inviolável, critério de aceite sem teste, ADR violado) do que é **gosto**.
- Não reescreva o PR inteiro na revisão; sugira a menor mudança que resolve.
- Se não tiver certeza de que algo é bug, diga isso e explique o cenário que te preocupa.
- Nunca aprove, mergeie ou dê push no PR de outra pessoa sem ela pedir.

## Exemplo

[`examples/exemplo_revisao.md`](examples/exemplo_revisao.md): revisão de um PR fictício com um bloqueio e duas sugestões.
