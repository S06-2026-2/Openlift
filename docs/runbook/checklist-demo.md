# Checklist de demo

Regras do [`CONTEXTO.md` §3](../CONTEXTO.md#3-calendário--datas-inegociáveis): **não demonstrar em ambiente de desenvolvimento**, ambiente de demo separado com dados populados, testado no dia anterior, e vídeo de fallback gravado. Wi-Fi de sala de aula já derrubou mais apresentação do que bug.

O roteiro funcional de cada demo (o que mostrar e os critérios) fica em [`docs/qa/`](../qa/); para a Demo 3, ver o [checklist de "publicar em A, ler em B"](../qa/sprint-2.md#checklist-de-validação-manual--demo-3-publicar-em-a-ler-em-b). Este arquivo cobre o **ambiente**.

## Véspera (D-1)

### Teste de "notebook novo" (RNF-10)

Num computador que **não** é o de quem desenvolve (ou num clone limpo em outra pasta):

- [ ] `git clone` da `main` atual
- [ ] Seguir [`subir-ambiente.md`](subir-ambiente.md) **ao pé da letra**, sem atalho de memória
- [ ] Anotar todo passo que precisou de algo fora do documento, e corrigir o documento
- [ ] `/health` responde `{"status":"ok"}`
- [ ] Bateria de testes do backend e `flutter test` verdes

### Ambiente da demo

- [ ] Banco zerado (`docker compose down -v`) e migrations + seed aplicados
- [ ] Contas de demo criadas, com nomes óbvios (`demo-a@openlift.dev`, `demo-b@openlift.dev`) e senha anotada **fora** do repositório
- [ ] Treinos de exemplo registrados nas contas, para o histórico não aparecer vazio
- [ ] Se o app for aberto pelo celular: `API_URL` apontando para o IP da máquina e `CORS_ORIGIN_REGEX` liberando essa origem (ver [problemas comuns](problemas-comuns.md#app--api))
- [ ] Relays configurados respondendo (a partir da Demo 3)
- [ ] Fluxo completo da demo executado uma vez, do início ao fim, por quem vai apresentar

### Plano B

- [ ] Vídeo do fluxo completo gravado (Demo 4: gravar em 02/12)
- [ ] Vídeo salvo **localmente** no notebook da apresentação e num pendrive, não só na nuvem
- [ ] Hotspot do celular testado como alternativa ao Wi-Fi da sala

## Dia da demo (D-0)

- [ ] 1 h antes: rodar o fluxo de novo no ambiente da apresentação
- [ ] Docker Desktop aberto e containers de pé antes de entrar na sala
- [ ] Notificações do sistema desligadas e abas pessoais fechadas
- [ ] Zoom do navegador em 125–150% para a projeção
- [ ] Nenhum terminal mostrando `.env`, token ou senha na tela

## Depois

- [ ] Registrar o que falhou ou quase falhou em `docs/retros/` e, se for problema de ambiente, em [`problemas-comuns.md`](problemas-comuns.md)
