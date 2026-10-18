# ADR-0005 — Identidade NOSTR invisível ao usuário

- **Status:** Aceito
- **Data:** 17/09/2026 (registrado em arquivo em 17/10/2026)
- **Requisitos relacionados:** RF-01, RF-02, RF-03, RF-04

## Contexto

No NOSTR, identidade é um par de chaves secp256k1: a chave pública (`npub`) identifica o autor e a privada (`nsec`) assina os eventos. A promessa do OpenLift é ter camada social em protocolo aberto **sem que o usuário precise lidar com chaves criptográficas**. Ao mesmo tempo, quem já usa NOSTR quer usar a própria identidade.

O banco já tem as tabelas `users` (conta por e-mail/senha) e `nostr_identities` (o `npub` associado).

## Decisão

- No **primeiro uso**, o app gera o par de chaves **localmente no dispositivo**, sem servidor.
- A chave **nunca é exibida como "chave"** no fluxo padrão.
- Login por **e-mail e senha** (JWT + refresh) desbloqueia o uso local da identidade.
- O `npub` é registrado no backend (`POST /me/nostr-identity`), associado ao usuário.
- **Importar um `nsec` existente** (NIP-19) é um **caminho avançado**, opcional.

## Alternativas consideradas

- **Login só por chave (NIP-07/`nsec`)** — natural para quem é NOSTR-nativo, mas afasta o público principal, que não sabe o que é chave.
- **Gerar e guardar a chave no servidor (custódia)** — simplifica a troca de dispositivo, mas quebra a garantia de que a chave nunca sai do dispositivo e transforma o backend em alvo de alto valor.
- **Só e-mail/senha, sem NOSTR** — perde a tese do produto.

## Consequências

- Cobre os dois públicos: quem não quer saber de chave e quem já tem identidade NOSTR.
- Trocar de dispositivo sem importar o `nsec` gera uma identidade nova; recuperação/backup da chave é um ponto a documentar com honestidade.
- O backend só conhece a chave pública. A custódia da privada depende da plataforma: ver [ADR-0006](0006-custodia-da-chave-por-plataforma.md).
