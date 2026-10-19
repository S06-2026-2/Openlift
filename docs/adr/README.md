# Architecture Decision Records (ADRs)

Decisões de arquitetura do OpenLift, no formato de Michael Nygard: **Status / Contexto / Decisão / Alternativas consideradas / Consequências**.

**Regra do projeto:** ADR aceito **não se reabre sem discussão no grupo**. Se uma tarefa parecer contradizer um ADR, pare e pergunte antes de implementar. Para mudar uma decisão, escreva um ADR novo que *substitui* o antigo (o antigo passa a ter status "Substituído por ADR-NNNN"), em vez de editar o texto original.

A tabela-resumo vigente fica em [`docs/CONTEXTO.md` §5](../CONTEXTO.md#5-decisões-fechadas-adrs). Este diretório guarda o registro completo de cada decisão.

| ADR | Título | Status |
|---|---|---|
| [0001](0001-frontend-flutter-web-e-apk.md) | Front-end em Flutter, entregue como web e APK | Aceito |
| [0002](0002-backend-python-fastapi-postgresql.md) | Back-end em Python, FastAPI e PostgreSQL | Aceito |
| [0003](0003-evento-de-treino-kind-1301.md) | Evento de treino `kind 1301` + mini-NIP | Aceito |
| [0004](0004-onde-o-dado-vive.md) | Onde o dado vive: Postgres x relay | Aceito |
| [0005](0005-identidade-nostr.md) | Identidade NOSTR invisível ao usuário | Aceito |
| [0006](0006-custodia-da-chave-por-plataforma.md) | Custódia da chave por plataforma | Aceito |
| [0007](0007-relays.md) | Relays públicos, depois relay próprio | Aceito |
| [0008](0008-ia-como-ferramenta-de-desenvolvimento.md) | IA é ferramenta de desenvolvimento, nunca feature | Aceito |
| [0009](0009-mapa-de-check-in-fora-do-escopo.md) | Mapa de check-in fora do escopo obrigatório | Aceito |
| [0010](0010-gates-de-qualidade-progressivos.md) | Gates de qualidade progressivos | Aceito |

## Como escrever um ADR novo

1. Copie o modelo abaixo para `docs/adr/NNNN-titulo-curto.md` (próximo número livre, título em minúsculas com hífen).
2. Abra uma issue e uma branch para ele (`docs/adr-NNNN-titulo`). Um ADR por PR.
3. Status começa como **Proposto**; vira **Aceito** quando o grupo aprova o PR.
4. Atualize a tabela acima e a §5 do `docs/CONTEXTO.md`.

Para rascunhar com IA, use a skill [`.agents/skills/escrever-adr/`](../../.agents/skills/escrever-adr/SKILL.md). O rascunho é revisado por uma pessoa antes do PR.

```markdown
# ADR-NNNN — Título da decisão

- **Status:** Proposto | Aceito | Substituído por ADR-NNNN
- **Data:** DD/MM/AAAA
- **Requisitos relacionados:** RF-xx, RNF-xx

## Contexto

Qual problema ou força obriga a decidir agora? Fatos, não opinião.

## Decisão

O que foi decidido, em voz ativa ("Usamos…", "O app faz…").

## Alternativas consideradas

- **Alternativa A** — por que não.
- **Alternativa B** — por que não.

## Consequências

O que fica mais fácil, o que fica mais difícil, e o que precisa ser feito por causa desta decisão.
```
