---
name: gerar-teste-flutter
description: Gerar testes automatizados do app Flutter do OpenLift (widget, controller Riverpod, repository e modelos), usando os fakes de test/helpers, sem rede e sem plugins de plataforma.
---

# Skill — gerar teste Flutter

Use quando a tarefa pede testes para código em `app/lib/`, ou quando você mudou uma tela, controller ou repository e precisa cobrir o comportamento. Para o backend, use `generate-tests`.

## Antes de escrever

1. Leia o código que vai ser testado **e** o teste que já existe para ele. Não duplique casos.
2. Leia os critérios de aceite da issue (e `docs/qa/` da sprint): cada critério vira pelo menos um teste.
3. Leia os helpers disponíveis em `app/test/helpers/`:
   - `FakeAuthRepository` — sessão salva (`session`), erros de login/cadastro, `latency` para ver loading, registro de `calls`.
   - `FakeWorkoutRepository` — treinos e biblioteca em memória (`supino`, `agachamento`, `remada`), erros injetáveis (`listError`, `saveError`), registro de `created`/`updated`/`deleted`.
   - `fake_http_adapter.dart` — adapter do Dio para testar `ApiClient`/repositories sem rede.

## Onde fica cada tipo de teste

| O que testar | Arquivo | Como |
|---|---|---|
| Tela / fluxo | `app/test/features/<feature>/<x>_screens_test.dart` | `testWidgets` subindo o `OpenLiftApp` com `ProviderScope` + overrides dos repositories |
| Controller Riverpod | `app/test/features/<feature>/<x>_controller_test.dart` | `ProviderContainer` com overrides, `addTearDown(container.dispose)` |
| Repository / ApiClient | `app/test/features/<feature>/<x>_repository_test.dart` | Dio com o fake adapter, conferindo método, rota, corpo e tratamento de erro |
| Modelo / validador | `app/test/features/<feature>/<x>_models_test.dart` | `test` puro (`fromJson`, `toJson`, limites) |
| Widget compartilhado | `app/test/shared/shared_widgets_test.dart` | `MaterialApp(theme: AppTheme.light(), home: ...)` |

## Regras do projeto

- **Sem rede e sem plugin de plataforma.** Sempre sobrescreva `authRepositoryProvider` e `workoutRepositoryProvider` com os fakes. Nunca use `flutter_secure_storage` real.
- **Tamanho da tela fixo** em testes de tela, para não depender do padrão do runner:
  ```dart
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  ```
  A navegação muda a partir de 840 px de largura (barra lateral em vez da inferior): teste os dois lados quando mexer na `AppShell`.
- Procure elementos pelo que o usuário vê: `find.text(...)`, `find.byTooltip(...)`. Use `Key` só quando não houver texto estável.
- Depois de toque ou navegação, `await tester.pumpAndSettle()`. Para ver estado de loading, use `latency` no fake e `tester.pump()` (sem settle).
- Cubra, além do caminho feliz: validação de formulário, erro da API mostrado em linguagem humana (`ApiException`), estado vazio, estado de erro com "Tentar novamente", e limites do RN-07 (carga ≤ 1000 kg, repetições ≤ 500).
- Nome do teste em português, descrevendo o comportamento: `'credencial inválida mostra mensagem humana e fica na tela'`.
- Comentário de cabeçalho no arquivo dizendo o que ele cobre e a issue (`// FE-03 — ...`).

## Validar

```bash
cd app
flutter analyze
flutter test
```

Rode `flutter test` duas vezes: teste que passa uma vez e falha na outra é flaky e não entra. Se `flutter analyze` quebrar por acento no caminho do projeto, rode numa cópia em caminho sem acento (o CI não tem esse problema).

## Não faça

- Não teste detalhe interno de biblioteca (Riverpod, go_router, Dio).
- Não use `sleep`/`Future.delayed` real para esperar: use `pump(duração)`.
- Não ajuste o teste para passar mudando o comportamento esperado sem a issue pedir. Se o teste revela bug, reporte.
- Não gere teste que só renderiza a tela sem nenhum `expect` relevante.

## Exemplo

[`examples/exemplo_widget_test.dart`](examples/exemplo_widget_test.dart): teste de tela com fake de repository, erro da API e retry.
