# ADR-0001 — Front-end em Flutter, entregue como web e APK

- **Status:** Aceito
- **Data:** 17/09/2026 (registrado em arquivo em 17/10/2026)
- **Requisitos relacionados:** RNF-04, RNF-13

## Contexto

O OpenLift precisa de um cliente que abra no celular de qualquer pessoa durante as demos, sem loja e sem instalação, e que também possa ser entregue como app Android. O planejamento anterior (`openlift-plano-de-desenvolvimento.md` v1.0) previa um PWA em stack web.

Quando esta decisão foi tomada, a Sprint 1 do front-end já estava construída e testada em Flutter: tema, roteador, widgets compartilhados e scaffolding de todas as plataformas. O front-end é o gargalo estrutural do projeto (uma pessoa para treino, feed e dashboard), então reescrever o que já existe custaria a sprint mais cara do calendário.

## Decisão

O front-end é **Flutter**, com Riverpod e go_router, e é entregue de duas formas:

- **Build web** (`flutter build web` + manifest): alvo primário de demo e distribuição. Abre no navegador do celular, sem loja e sem instalar.
- **APK Android**: entrega adicional.

## Alternativas consideradas

- **PWA em stack web (React/Vue)** — era a decisão anterior. Descartada porque o benefício que a motivava (abrir no navegador, sem loja) o `flutter build web` já entrega, e trocar de stack jogaria fora a Sprint 1 pronta.
- **Só app nativo Android** — exigiria instalar APK na hora da demo; risco alto em sala de aula e exclui quem usa iPhone.

## Consequências

- Um único código para web e Android.
- Na web, o armazenamento seguro é do navegador, não do sistema operacional. Isso muda a custódia da chave NOSTR e está tratado no [ADR-0006](0006-custodia-da-chave-por-plataforma.md).
- Bibliotecas NOSTR em Dart precisam funcionar também no build web; isso entra no spike de compatibilidade do `dart_nostr`.
- `flutter analyze` quebra em caminho de projeto com acento (bug de ambiente, não do código); o CI não tem esse problema.
