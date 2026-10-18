# Prompts que funcionaram

Prompts usados no desenvolvimento do OpenLift que deram bom resultado, e alguns que precisaram de ajuste. Vai como **anexo do relatório final** e serve de atalho para o time: antes de inventar um prompt, veja se já existe um que funciona.

Complementa o [`docs/ia/registro.md`](../ia/registro.md) (o que foi gerado em cada PR) e as skills em [`.agents/skills/`](../../.agents/skills/) (passo a passo que o agente segue).

## Como registrar

Uma entrada por prompt, no formato abaixo. Não copie segredo, token, senha ou dado pessoal para cá (nem para o prompt).

```markdown
### Título curto do que o prompt resolve

- **Quem / ferramenta:** nome · ferramenta e modelo
- **Quando usar:** em que situação esse prompt serve
- **Prompt:** (texto, com <marcadores> no lugar do que muda)
- **Por que funcionou:** o que no prompt fez a diferença
- **Resultado:** PR ou issue que saiu dele
```

## Modelo base

O formato que mais funcionou no projeto. Ele segue a regra de **escopo pequeno** do [ADR-0008](../adr/0008-ia-como-ferramenta-de-desenvolvimento.md): uma tarefa, contexto explícito, critério de pronto.

```text
Tarefa: <issue #N — título>

<cole aqui o texto da issue: passo a passo e critérios de aceite>

Regras: siga o AGENTS.md. Uma branch para esta issue (<tipo>/<nome-curto>),
commits em Conventional Commits, sem mexer em nada fora do escopo.
Antes de abrir o PR, rode a bateria do CI (lint + testes) e me diga o resultado.
No fim, me passe o título e a descrição do PR no template do repositório.
```

---

## Prompts

### Implementar uma issue a partir do texto dela

- **Quem / ferramenta:** Luiz · Claude Code (Claude Opus 5.5)
- **Quando usar:** qualquer issue do board com passo a passo e critério de aceite escritos
- **Prompt:**
  > Vamos começar por elas. Vou te mandar a descrição de cada uma para podermos fazer: `<texto da issue BE-02>` `<texto da BE-03>` `<texto da BE-04>`
- **Por que funcionou:** o texto da issue já traz escopo, passo a passo e critério de aceite, então o agente não precisou adivinhar o que era "pronto". Cada issue virou uma branch e um PR.
- **Resultado:** PRs #43, #44 e #45 (BE-02, BE-03, BE-04)

### Repetir o padrão de PR que já deu certo

- **Quem / ferramenta:** Luiz · Claude Code (Claude Opus 5.5)
- **Quando usar:** depois de ter um PR aprovado que serve de modelo
- **Prompt:**
  > Funcionou aqui. Agora faça da mesma forma que o último dos FE: o mesmo jeito de PR e descrição.
- **Por que funcionou:** apontar um exemplo concreto ("igual ao último") é mais preciso do que descrever o formato de novo.
- **Resultado:** descrições dos PRs #43–#45 no mesmo template dos #39–#41

### Triagem do board a partir do histórico

- **Quem / ferramenta:** Luiz · Claude Code (Claude Opus 5.5)
- **Quando usar:** início de ciclo, para decidir o que pegar
- **Prompt:**
  > Ainda temos essas tasks para fazer `<captura do board>`. Verifique os últimos commits para ver se já foi feito algo que está aí e ainda não foi concluído. Caso contrário, me fale o que seria ideal fazer no momento.
- **Por que funcionou:** pede para **conferir contra o repositório** (commits, branches, arquivos) antes de opinar. A resposta achou trabalho parcial (deploy no GHCR, reporter em branch) e priorizou pelo calendário das demos.
- **Resultado:** ordem QA-01 → DOC-01 → OPS-03/OPS-02 (PRs #52–#55)

### Passo a passo de configuração manual

- **Quem / ferramenta:** Luiz · Claude Code (Claude Opus 5.5)
- **Quando usar:** tarefa feita na interface do GitHub (sem código), como branch protection
- **Prompt:**
  > Me fale o passo a passo desse: `<texto da issue OPS-01>`
- **Por que funcionou:** o agente leu os workflows para dar os **nomes exatos** dos checks a marcar como obrigatórios, em vez de nomes genéricos.
- **Resultado:** OPS-01 (#31) configurado

## Prompts que precisaram de ajuste

Também entram no relatório: mostram onde a IA precisa de mais contexto.

### Pedido de visual vago

- **Prompt original:** "Vamos mudar todo esse layout do front-end, quero algo minimalista e profissional, estou achando muito amador."
- **O que aconteceu:** funcionou porque o agente leu o tema, as telas e os testes antes de mudar, e manteve todos os textos que os testes procuram. Mesmo assim, a direção visual (paleta neutra, sem cor de destaque) foi escolha do agente.
- **Melhor:** dizer a direção que você quer ("preto e branco, estilo Linear/Vercel", "manter o laranja como destaque") e anexar uma referência.
- **Resultado:** PR #51 (FE-04)

### Pedir para a IA preencher dados que ela não tem

- **Prompt original:** "No registro, preencha o do Pedro e do Rodrigo usando os PRs e commits, e na ferramenta usada pode escolher a IA."
- **O que aconteceu:** o agente preencheu o que estava declarado nos PRs (#37, #46, #49) e nos commits, mas **se recusou a escolher a ferramenta** onde não havia declaração: atribuir a alguém uma ferramenta que a pessoa não declarou seria um registro falso.
- **Melhor:** pedir para preencher só o que tem fonte, e cobrar de cada pessoa a sua linha.
- **Resultado:** [`docs/ia/registro.md`](../ia/registro.md) com "não declarado" onde faltava fonte
