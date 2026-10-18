# Requisitos não funcionais (RNF)

Fonte: [`docs/CONTEXTO.md` §7](../CONTEXTO.md#7-requisitos). Todo RNF tem uma forma de verificação definida: requisito que não dá para verificar não é requisito. O status de cada um está na [matriz de rastreabilidade](rastreabilidade.md).

| ID | Categoria | Requisito | Como verificar |
|---|---|---|---|
| RNF-01 | Segurança | Chave privada nunca em log, telemetria ou requisição HTTP | Teste automatizado que faz grep de `nsec` e de hex de 64 caracteres nos logs |
| RNF-02 | Segurança | 100% dos eventos consumidos têm assinatura verificada antes de projetar | Teste unitário com evento adulterado |
| RNF-03 | Segurança | Rate limiting nos endpoints públicos | Teste de integração |
| RNF-04 | Desempenho | Registro de série percebido como instantâneo (< 100 ms) | Teste de widget com timing |
| RNF-05 | Desempenho | Feed com 200 eventos renderiza em < 2 s | Benchmark manual documentado |
| RNF-06 | Recuperabilidade | Agregações reconstruíveis por replay em < 5 min | Comando + teste de integração |
| RNF-07 | Qualidade | Cobertura conforme [ADR-0010](../adr/0010-gates-de-qualidade-progressivos.md), com gate no CI | Relatório do `pytest-cov` no PR |
| RNF-08 | Qualidade | Zero warnings de lint no merge (`ruff`, `black`, `flutter analyze`) | CI |
| RNF-09 | Manutenibilidade | Todo merge em `main` via PR com ≥ 1 aprovação | Branch protection |
| RNF-10 | Portabilidade | Ambiente completo sobe com um `docker compose up` | Teste de "notebook novo" antes de cada demo |
| RNF-11 | Interoperabilidade | Evento publicado é legível em ≥ 1 cliente NOSTR de terceiros | Screenshot em cada demo |
| RNF-12 | Privacidade | Nenhuma coleta de geolocalização. Consentimento informado e explícito na primeira publicação | Revisão + `docs/lgpd.md` |
| RNF-13 | Usabilidade | Registrar uma série em ≤ 3 toques | Teste com 3 pessoas fora da equipe |
| RNF-14 | Observabilidade | Logs estruturados em JSON, correlacionáveis por `event_id` | Revisão de código |
