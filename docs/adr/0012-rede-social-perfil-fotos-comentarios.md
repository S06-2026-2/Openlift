# ADR-0012 — Rede social com perfil, fotos e comentários

- **Status:** Proposto
- **Data:** 19/11/2026
- **Requisitos relacionados:** RF-05, RF-30, RF-31, RF-33, RNF-01, RNF-12

## Contexto

Até a Sprint 3, a parte social do OpenLift é um feed de treinos (`kind 1301`) de quem a pessoa segue, com like (`kind 7`). Quem aparece no feed é só um `npub` encurtado. O PO pediu que a aba Social funcione como uma rede social de academia:

- antes de entrar, a pessoa cria um **nome de usuário**, que não pode repetir;
- o perfil tem **foto**, nome e bio;
- a pessoa **publica fotos** e compartilha treinos;
- dá para **encontrar outras pessoas pelo nome de usuário** e **comentar** nas postagens.

Fatos que pesam:

- **Relay NOSTR não garante unicidade.** O `kind 0` (perfil) aceita qualquer `name`, e duas pessoas podem usar o mesmo. A forma padrão de ter um nome verificado é a **NIP-05**: um servidor publica `/.well-known/nostr.json` ligando `nome` a `pubkey`.
- **Relay não guarda imagem.** Eventos levam só a URL da foto. Alguém precisa hospedar o arquivo.
- **Foto de celular carrega metadados.** O EXIF costuma trazer a posição GPS de onde a foto foi tirada. A RNF-12 proíbe coletar geolocalização (ADR-0009).
- **O ADR-0003 proíbe publicar treino como `kind 1`.** Uma postagem de foto não é treino, mas usar `kind 1` para ela misturaria o OpenLift com o "Twitter do NOSTR" em qualquer cliente.
- **O ADR-0004 manda que nada social exista só no Postgres.** Like e contagem vêm de evento assinado.
- **A Sprint 5 (a partir de 24/11) é congelamento.** Esta decisão entra na Sprint 4 por pedido do PO.

## Decisão

1. **Nome de usuário único no backend, publicado como NIP-05.**
   - A tabela `profiles` liga cada conta a um `username` único: 3 a 20 caracteres `a-z`, `0-9`, `_` e `.`, guardado em minúsculas.
   - Ela também guarda o nome de exibição, a bio e a URL da foto.
   - A API responde `GET /.well-known/nostr.json?name=<username>` no formato da NIP-05.
   - A busca de pessoas por nome (`GET /profiles/search`) lê essa tabela.
   - A tabela é um **diretório de nomes**, como qualquer servidor NIP-05. Ela não guarda interação social.
2. **Perfil publicado como `kind 0`.** Ao criar ou editar o perfil, o app grava na API e publica o `kind 0` assinado, com `name`, `display_name`, `about`, `picture` e `nip05 = username@domínio da API`. Qualquer cliente NOSTR passa a ver o perfil e o nome verificado.
3. **Fotos hospedadas pela nossa API.**
   - `POST /media` recebe JPEG, PNG ou WebP de até 5 MB, de usuário logado.
   - O backend **recodifica a imagem**, o que descarta o EXIF e com ele o GPS. Ele também limita o lado maior a 1600 px.
   - O arquivo é salvo com nome aleatório no diretório `MEDIA_DIR` e servido publicamente em `GET /media/{arquivo}`.
   - A tabela `media` registra dono, tipo e tamanho.
4. **Postagem de foto é `kind 20` (NIP-68)**, o evento "foto primeiro" que clientes NOSTR de imagem já leem.
   - O evento leva a tag `imeta` (NIP-92) com URL, tipo, dimensões e hash SHA-256, mais a legenda no `content`.
   - Também leva `["t", "openlift"]` e a tag `alt` (NIP-31).
   - Treino continua sendo `kind 1301` (ADR-0003). Compartilhar treino é a publicação que já existe.
5. **Comentário é `kind 1111` (NIP-22).**
   - O comentário aponta para o post ou treino comentado com as tags de raiz `E`/`K`/`P` e de pai `e`/`k`/`p`.
   - O app lê os comentários direto dos relays, com o filtro `#E`, e conta no aparelho. Nada de comentário no Postgres.
6. **Feed e perfis vêm dos relays.**
   - O feed mostra `kind 20` e `kind 1301` de quem a pessoa segue.
   - A página de perfil mostra o `kind 0`, as fotos e os treinos daquela `pubkey`.
   - Nome de usuário e foto de quem aparece no feed vêm de `GET /profiles?pubkeys=`.
7. **Entrar na aba Social exige perfil.** Sem `username`, a aba abre o cadastro de perfil, com aviso de que tudo publicado ali é público na rede aberta (RNF-12).

## Alternativas consideradas

- **Nome só no `kind 0`, sem backend.** Mais simples, mas não garante que o nome é único, que era o pedido central.
- **Fotos num servidor público de mídia NOSTR (Blossom, nostr.build).** Não exige código no backend, mas manda a foto para terceiros e não garante que o EXIF seja removido antes de sair do aparelho.
- **Postagem como `kind 1` com imagem.** É lida por mais clientes, mas mistura o OpenLift com o feed de texto do NOSTR e chega perto do que o ADR-0003 quis evitar.
- **Comentário como `kind 1` em resposta (NIP-10).** É o padrão antigo, mas a NIP-22 foi criada para comentar eventos que não são `kind 1`, que é o caso de `kind 20` e `kind 1301`.

## Consequências

- **Backend:**
  - duas tabelas novas (`profiles`, `media`) com migration;
  - as rotas `/me/profile`, `/profiles`, `/profiles/search`, `/profiles/{username}`, `/.well-known/nostr.json` e `/media`;
  - a dependência Pillow, para recodificar as imagens.
- **Infra:**
  - o staging precisa de um **volume persistente** montado em `MEDIA_DIR`; sem ele, as fotos somem a cada deploy;
  - `PUBLIC_BASE_URL` precisa apontar para a URL pública da API, porque as URLs das fotos e o NIP-05 dependem dela.
- **App:** cadastro de perfil, postagem com foto, página de perfil, busca por nome de usuário e comentários.
- **Privacidade:**
  - foto publicada fica pública na internet, e o evento assinado não se apaga dos relays (só dá para pedir exclusão com `kind 5`);
  - o aviso de consentimento da RNF-12 passa a valer também para fotos;
  - o EXIF é removido no servidor, mas a foto ainda trafega do aparelho até a API.
- **Fora do escopo agora:** moderação e denúncia, apagar post ou comentário (`kind 5`), comentário no feed de texto `kind 1`, notificações. A aba Perfil continua para a próxima sprint.
- O mini-NIP do treino (`docs/nips/`) não muda. Os novos `kind` seguem NIPs públicas (01, 05, 22, 31, 68, 92), sem tags inventadas.
