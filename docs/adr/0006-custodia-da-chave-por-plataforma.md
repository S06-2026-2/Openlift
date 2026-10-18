# ADR-0006 — Custódia da chave por plataforma

- **Status:** Aceito
- **Data:** 17/09/2026 (registrado em arquivo em 17/10/2026)
- **Requisitos relacionados:** RF-02, RNF-01

## Contexto

O [ADR-0005](0005-identidade-nostr.md) gera a chave privada no dispositivo. O [ADR-0001](0001-frontend-flutter-web-e-apk.md) entrega o app como **web** e **APK Android**. As duas plataformas oferecem garantias diferentes de armazenamento:

- No **Android**, `flutter_secure_storage` usa o Keystore do sistema operacional.
- Na **web**, o armazenamento é do **navegador**, não do sistema operacional, e é mais exposto (extensões, scripts na mesma origem).

Prometer "armazenamento seguro do SO" na web seria falso.

## Decisão

- **Android:** chave privada no Keystore, via `flutter_secure_storage`.
- **Web:** a chave fica no armazenamento do navegador, e o caminho **recomendado** passa a ser um **signer externo** (NIP-07, extensão de navegador; ou NIP-46, signer remoto).
- Em **qualquer** plataforma, a chave privada **nunca trafega para o backend**, nem aparece em log, telemetria ou mensagem de erro.

## Alternativas consideradas

- **Tratar web e Android igual** — mais simples de comunicar, mas desonesto sobre a segurança real da web.
- **Bloquear publicação na web** — elimina o risco, mas a web é o alvo primário de demo (ADR-0001).
- **Custódia no servidor** — descartada no ADR-0005.

## Consequências

- A frase "a chave nunca sai do dispositivo" continua verdadeira em todas as plataformas; "está em armazenamento seguro do SO" vale só no Android, e a documentação diz isso.
- RNF-01 vira teste automatizado: grep de `nsec` e de hex de 64 caracteres em logs e requisições.
- Suporte a NIP-07/NIP-46 na web entra no backlog como caminho recomendado.
- O tema entra no `docs/lgpd.md` (análise de privacidade e limitações).
