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

## Notas de implementação

Registro do que foi feito para cumprir esta decisão. Não muda a decisão acima.

### FE-04 (#83) — spike da biblioteca e chave local (27/10/2026)

- **Biblioteca escolhida:** `bip340` + `crypto` (Dart puro), a mesma do núcleo NIP-01 do NOSTR-02 (#71), com codificação NIP-19 (`npub`/`nsec`) própria em `app/lib/core/nostr/nip19.dart`. É a opção "secp256k1 + BIP-340 próprio" prevista no FE-04.
- **Por que não `dart_nostr` nem `ndk`:** geração de chave, assinatura e verificação já estavam resolvidas e testadas com `bip340` (vetores da NIP-01 e da NIP-19, evento adulterado reprovado). Trazer um SDK completo só para isso aumentaria dependências sem ganho. `dart_nostr` e `ndk` **não foram testados** neste spike; a escolha do cliente de relay (WebSocket) fica para o FE-05.
- **Web:** um programa de spike rodado no Chrome com `flutter run -d chrome` passou em 6 verificações: gerar chave, assinar e verificar um evento, reprovar evento adulterado, codificar `npub` com o vetor oficial da NIP-19, e salvar a identidade no armazenamento do navegador e reutilizá-la. (O `flutter test --platform chrome` travou no carregamento neste ambiente, por isso o spike foi feito com o app rodando.) Os testes automatizados rodam na VM do Dart, como no CI.
- **Android:** a biblioteca é Dart puro, sem código nativo. A validação em aparelho real fica no teste da Demo 3.
- **Fluxo:** depois do login ou cadastro, e ao reabrir o app com sessão salva, o app consulta `GET /me`, gera a chave da conta **neste aparelho** se ainda não existir e registra o `npub` em `POST /me/nostr-identity` quando ele for diferente do que o servidor tem. Isso roda em segundo plano: falha de rede não impede o login e a sincronização é refeita na próxima abertura.
- **Uma chave por conta no aparelho**, guardada em `nostr.secret.<id do usuário>` no armazenamento seguro. O logout **não** apaga a chave, então entrar de novo reutiliza a mesma identidade.
- **Importação de `nsec` (RF-04):** Perfil → "Configurações avançadas". O `npub` é registrado no servidor **antes** de trocar a chave local, para app e servidor nunca ficarem com identidades diferentes.
- **RNF-01:** teste automatizado executa cadastro e importação e confere que nenhuma requisição (URL, cabeçalhos, corpo) nem saída de `print` contém a chave privada; o corpo do registro tem só o campo `npub`.
