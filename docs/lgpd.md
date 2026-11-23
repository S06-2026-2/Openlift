# Privacidade e LGPD: o que o OpenLift faz com os dados

- **Status:** rascunho com os **fatos** do código em 22/11/2026. As seções marcadas **"Decisão do grupo"** ainda não estão escritas.
- **Requisitos:** RNF-01, RNF-12 · **ADRs:** 0004, 0005, 0006, 0009, 0012

> **Por que este documento não está pronto.** O `CONTEXTO.md` §8 diz que o `lgpd.md` é conteúdo original do time. A tensão entre o direito ao apagamento e a imutabilidade do relay é real, não tem solução técnica, e documentar isso com honestidade é o objetivo. Este rascunho lista o que o sistema faz hoje. As posições do projeto ficam para o grupo.

## 1. Onde cada dado vive

| Dado | Onde fica | Quem vê | Apagável por nós? |
|---|---|---|---|
| E-mail e senha (hash bcrypt) | Postgres (`users`) | Só o backend | Sim (hoje não há rota de exclusão de conta, ver §4) |
| Treinos, séries, carga, RPE | Postgres (`workouts`, `sets`) | Só o dono (isolamento por usuário; recurso alheio responde 404) | Sim: `DELETE /workouts/{id}` |
| Chave privada NOSTR | **Só no aparelho**: Keystore no Android; armazenamento do navegador na web (ADR-0006) | Ninguém além do aparelho | Não está conosco |
| `npub` / chave pública | Postgres (`nostr_identities`) e eventos nos relays | Público por definição | Do Postgres sim; dos relays não |
| Nome de usuário, nome de exibição, bio, URL da foto | Postgres (`profiles`) e evento `kind 0` nos relays | Público (diretório NIP-05 e busca) | Do Postgres sim; do `kind 0` já publicado não |
| Fotos | Disco da API (`MEDIA_DIR`), registro em `media`; URL pública em `GET /media/{arquivo}` com cache de 1 ano | Público para quem tiver a URL | Do disco sim; cópias em cache ou em clientes de terceiros não |
| Treino publicado (`kind 1301`), foto (`kind 20`), comentário (`kind 1111`), like (`kind 7`), seguidos (`kind 3`) | Relays NOSTR (`relay.damus.io`, `nos.lol`, `relay.primal.net`, configuráveis) | Público | **Não**: ver §3 |
| Cache de likes (`likes`) | Postgres, reconstruído a partir dos relays (ADR-0004) | Contagem pública pela API | Sim, mas volta no próximo ciclo enquanto o evento existir no relay |
| Heartbeat do worker (`worker_heartbeats`) | Postgres | Público em `/health` | Não contém dado pessoal |

## 2. O que já está implementado a favor da privacidade

- **Chave privada nunca sai do aparelho** (RNF-01, ADR-0006). O backend recusa com 422 qualquer campo de chave privada (`POST /me/nostr-identity`). Testes automatizados procuram `nsec1` e hex de 64 caracteres nos logs e nas requisições, no app e no backend (#119).
- **Logs sem dado sensível** (OPS-08). Os logs JSON não registram corpo, cabeçalhos nem query string das requisições. Qualquer `nsec1…` ou hex de 64 caracteres numa mensagem ou num traceback vira `[REDACTED]`.
- **Treino é privado por padrão.** Publicar é uma escolha por treino (RF-21). A primeira publicação mostra um consentimento explícito de que o conteúdo fica público e não pode ser apagado da rede (FE-05, RNF-12).
- **Sem geolocalização** (RNF-12, ADR-0009). O app não pede localização. O backend **recodifica toda foto** recebida, o que descarta o EXIF (onde fica o GPS), e limita a imagem a 1600 px e 5 MB (ADR-0012).
- **Entrar no Social exige perfil**, com aviso de que tudo ali é público na rede aberta (ADR-0012).
- **Série e RPE não vão para o relay como dado solto**: só entram no evento `kind 1301` quando a pessoa escolhe publicar aquele treino (ADR-0004).

## 3. A tensão: direito ao apagamento × imutabilidade do relay

Fatos técnicos, sem posição:

- A LGPD (art. 18) dá ao titular o direito de pedir a **eliminação** dos seus dados.
- Um evento NOSTR é **assinado pela chave do usuário** e replicado em relays que **não são nossos**. Não temos como apagá-lo de lá.
- A NIP-09 (`kind 5`) permite **pedir** a exclusão. Cada relay e cada cliente decide se honra o pedido. Quem já baixou o evento continua com a cópia.
- **O app hoje não emite `kind 5`** (ADR-0012, "fora do escopo agora").
- Editar um treino publicado gera um **novo** evento; o anterior continua existindo (RN-08).
- Fotos ficam no nosso servidor e podem ser apagadas do disco. A URL, porém, foi publicada num evento imutável e pode estar em cache em outros lugares.

## 4. O que ainda não existe

- Rota para o usuário **excluir a própria conta** e os dados do Postgres.
- Emissão de pedido de exclusão (`kind 5`) para treinos, fotos e comentários publicados.
- Exportação dos dados do usuário (portabilidade, art. 18, V). Hoje o que é público já está nos relays em formato aberto, mas o privado (treinos não publicados) não tem export.
- Política de retenção de logs e de fotos órfãs.

## 5. Decisão do grupo

_A escrever pelo time. Perguntas que este documento precisa responder:_

1. **Papel do projeto:** quem é o controlador dos dados num projeto acadêmico hospedado no Railway? O que dizemos na tela de cadastro?
2. **Base legal** para cada tratamento (consentimento? execução do serviço?).
3. **Pedido de exclusão:** o que prometemos? (Apagar do Postgres e do disco, emitir `kind 5` e explicar o limite, ou declarar que não atendemos nesta entrega.)
4. **Texto do consentimento** da primeira publicação e do cadastro de perfil: ele explica bem que é "para sempre"?
5. **Retenção:** por quanto tempo guardamos logs, fotos e contas inativas?
6. **Relays de terceiros:** avisamos o usuário de que o conteúdo vai para servidores fora do Brasil e fora do nosso controle?
7. **Demo 4:** usamos o modo "relay da turma" com allowlist (CONTEXTO §9, questão 8) para não publicar dado de teste em relay público?
