# ADR-0008 — IA é ferramenta de desenvolvimento, nunca feature do produto

- **Status:** Aceito
- **Data:** 17/09/2026 (registrado em arquivo em 17/10/2026)

## Contexto

O time usa assistentes de IA (Claude Code, Gemini, Copilot, Cline) para gerar código, testes e documentação. Ninguém tem plano pago, e cada pessoa usa uma ferramenta diferente. Também existe a tentação de colocar "IA" como funcionalidade do app (sugestão de treino, por exemplo), o que abriria uma frente nova de produto sem relação com a tese do OpenLift.

## Decisão

- IA é **ferramenta de desenvolvimento**, nunca feature do produto. Qualquer IA dentro do app está fora do escopo.
- Estratégia em **camadas gratuitas**: cada pessoa usa a ferramenta que tiver acesso.
- **Skills versionadas como markdown** em `.agents/skills/`, agnósticas de ferramenta, com um **`AGENTS.md` na raiz** descrevendo arquitetura, convenções e regras invioláveis.
- Política de uso: IA gera, humano é responsável; todo PR declara ferramenta, o que foi gerado e o que foi revisado; nunca colar segredo, chave privada ou dado pessoal em prompt; código gerado sem teste não é aceito.

## Alternativas consideradas

- **Padronizar uma ferramenta paga** — não há orçamento no time.
- **Prompts soltos, sem versionar** — cada pessoa reinventa o contexto e o código sai fora do padrão do projeto.
- **Recurso de IA no app** — fora da tese do produto, aumenta escopo num front-end que já é gargalo e traz questões de privacidade.

## Consequências

- O mesmo markdown funciona em Claude Code, Gemini, Copilot e Cline, sem reescrever nada.
- A declaração de uso de IA vira item da Definition of Done e do template de PR.
- "A IA escreveu" nunca é explicação aceitável para um bug: quem abre o PR responde pelo código.
- O registro de uso e a avaliação crítica entram em `docs/ia/` para o relatório final.
