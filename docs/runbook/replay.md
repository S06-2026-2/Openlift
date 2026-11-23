# Replay das agregações (RF-53)

Apaga o cache de curtidas (`likes`, e `rankings`, que também é derivado) e reconstrói tudo a partir dos eventos `kind 7` assinados que estão nos relays. Usa a mesma projeção do worker (BE-09).

É a prova do [ADR-0004](../adr/0004-onde-o-dado-vive.md): nada social vive só no Postgres. É também a demo ao vivo da Demo 4.

## Quando usar

- A contagem de curtidas parece errada ou alguém mexeu na tabela `likes` à mão.
- Mudou a regra de projeção (ex.: passou a tratar `kind 5`) e o cache antigo precisa ser refeito.
- Demonstração: apagar as curtidas e mostrar que elas voltam.

## Como rodar

Local, de dentro de `infra/docker`:

```bash
# Simulação: lê os relays, calcula e mostra o resultado sem gravar nada
docker compose run --rm -e NOSTR_RELAYS=wss://relay.damus.io,wss://nos.lol,wss://relay.primal.net \
  api python -m app.cli replay --dry-run

# Replay de verdade
docker compose run --rm -e NOSTR_RELAYS=wss://relay.damus.io,wss://nos.lol,wss://relay.primal.net \
  api python -m app.cli replay
```

No Railway (staging): abra o serviço `openlift-api` e rode `python -m app.cli replay` pelo shell do serviço (ou `railway run --service openlift-api python -m app.cli replay`). As variáveis `DATABASE_URL` e `NOSTR_RELAYS` já são as do serviço.

Saída esperada:

```
Replay concluído:
  treinos publicados: 10
  relays que responderam: 2 de 3
  reações kind 7 verificadas: 4
  likes antes: 4
  likes depois: 4
  tempo: 6.1 s
```

"Likes antes" e "likes depois" iguais significam que o cache estava certo. Diferentes significam que o replay corrigiu o cache.

## Garantias

- **Lê antes de apagar.** Se nenhum relay responder até o fim, o comando sai com erro (código 1) e não apaga nada: `Replay cancelado: Nenhum dos 3 relay(s) respondeu; nada foi apagado.`
- **Uma transação só.** Apagar e reprojetar acontecem juntos: ou fica o cache novo, ou fica o antigo.
- **Idempotente.** Rodar duas vezes dá o mesmo resultado.
- **Mesmas regras do worker:** um like por pessoa por treino (RN-06), `content` "-" ignorado, só treinos que estão em `shared_events`.
- **Tempo (RNF-06, < 5 min):** 6,1 s com os 10 treinos do ambiente local e três relays públicos, em 22/11/2026.

## Roteiro da demo

1. Mostre a curtida de um treino no app.
2. No Adminer (http://localhost:8080), apague as linhas da tabela `likes`. Recarregue o app: a contagem some.
3. Rode `python -m app.cli replay`.
4. Recarregue o app: a contagem voltou, lida dos eventos assinados nos relays.

## Limite conhecido

Um relay que estava fora do ar durante o replay não contribui com as curtidas que só ele tinha. Se a saída mostrar "relays que responderam" menor que o total, rode de novo depois.
