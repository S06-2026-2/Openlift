---
name: validar-evento-nostr
description: Conferir se um evento NOSTR produzido ou consumido pelo OpenLift é válido — estrutura NIP-01, id e assinatura, tag alt (NIP-31), conformidade do kind 1301 com o mini-NIP em docs/nips/ e as regras de negócio (RN-01, RN-05, RN-07, RN-09). Produz um relatório; não corrige o evento sozinho.
---

# Skill — validar evento NOSTR

Use ao revisar código que **monta, assina, publica ou lê** eventos (adapter de serialização, worker de ingestão, testes com evento fixo), ou quando alguém cola um evento e pergunta se está certo.

## Fonte da verdade

- Formato do evento de treino: **mini-NIP em `docs/nips/`** (ADR-003). **Se `docs/nips/` ainda não existir, valide só a parte genérica (NIP-01 e NIP-31) e diga explicitamente que a conformidade com o `kind 1301` não pôde ser checada.** Não invente nomes de tags nem ordem de campos.
- Especificações: [NIP-01](https://github.com/nostr-protocol/nips/blob/master/01.md) (evento, id, assinatura), [NIP-31](https://github.com/nostr-protocol/nips/blob/master/31.md) (`alt`), [NIP-25](https://github.com/nostr-protocol/nips/blob/master/25.md) (`kind 7`, like).

## Checklist

### 1. Estrutura (NIP-01)
- Campos `id`, `pubkey`, `created_at`, `kind`, `tags`, `content`, `sig` — todos presentes, nenhum a mais.
- `id`: 64 caracteres hex minúsculos. `pubkey`: 64 hex minúsculos (chave pública x-only, **não** o `npub` bech32). `sig`: 128 hex minúsculos.
- `created_at`: inteiro, segundos Unix (não milissegundos).
- `kind`: inteiro. `tags`: lista de listas de strings. `content`: string.

### 2. Integridade
- O `id` é o SHA-256 da serialização `[0, pubkey, created_at, kind, tags, content]` em JSON UTF-8, **sem espaços** (`separators=(",", ":")`), sem escapar acentos.
- A `sig` é uma assinatura Schnorr (BIP-340) do `id` com a chave de `pubkey`. Na leitura, **todo** evento precisa ter a assinatura verificada antes de qualquer projeção (RF-51, RNF-02). Evento com assinatura inválida é descartado, nunca "consertado".

### 3. Interoperabilidade
- Tem a tag `["alt", "<resumo legível>"]` (NIP-31) — obrigatória no OpenLift (ADR-003). O texto deve fazer sentido para quem vê o evento num cliente que não entende o kind.
- Treino é **`kind 1301`**. Treino publicado como `kind 1` é erro (ADR-003).

### 4. Conformidade com o mini-NIP (`kind 1301`)
- Tags exatamente como o mini-NIP define: nome, tipo e ordem dos campos.
- Nenhum campo que o mini-NIP não prevê: em especial, nenhum dado pessoal (e-mail, id interno do usuário) e nenhuma localização (RNF-12).

### 5. Regras de negócio
- **RN-01:** treino sem nenhuma série não vira evento.
- **RN-07:** carga ≤ 1000 kg e repetições ≤ 500 (acima disso é erro de digitação ou abuso).
- **RN-09:** carga sempre em **kg** no evento; lb é só apresentação.
- **RN-05:** `created_at` mais de 15 minutos no futuro em relação ao relógio do servidor não entra em ranking.
- **RN-08:** edição de treino publicado gera **novo** evento (novo `id`); o antigo não é alterado.

### 6. Segurança
- Nenhum `nsec`, chave privada ou hex de 64 caracteres que não seja `id`/`pubkey`/referência de evento aparece em `content`, tags, logs ou mensagens de erro do código que gerou o evento (RNF-01).

## Formato da saída

```markdown
## Validação do evento <id curto>

| Verificação | Resultado |
|---|---|
| Estrutura NIP-01 | ✅ / ❌ motivo |
| id confere | ✅ / ❌ |
| Assinatura | ✅ / ❌ / ⚠️ não verificada (motivo) |
| Tag alt (NIP-31) | ✅ / ❌ |
| kind 1301 + mini-NIP | ✅ / ❌ / ⚠️ docs/nips/ ainda não existe |
| Regras de negócio (RN-01/05/07/09) | ✅ / ❌ qual |
| Segurança (RNF-01) | ✅ / ❌ |

**Conclusão:** válido / inválido — e o que corrigir no código que gerou o evento.
```

## Exemplo

[`examples/validar_evento.py`](examples/validar_evento.py) — script de referência que confere estrutura, recalcula o `id`, verifica a assinatura (se a biblioteca `coincurve` estiver instalada) e a tag `alt`. [`examples/evento-exemplo.json`](examples/evento-exemplo.json) — evento de entrada para testar o script. O `id` está correto, mas a assinatura é de mentira, de propósito: com `coincurve` instalado o script reprova; sem ele, avisa que a assinatura não foi verificada. Altere o `content` e rode de novo para ver o `id` não conferir.

```bash
cd .agents/skills/validar-evento-nostr/examples
python validar_evento.py evento-exemplo.json
```
