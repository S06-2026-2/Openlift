// Smoke tests do app + proteção de rotas por sessão (FE-01).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlift/features/auth/data/auth_repository.dart';
import 'package:openlift/main.dart';

import 'helpers/fake_auth_repository.dart';

Widget _app(FakeAuthRepository repository) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repository)],
    child: const OpenLiftApp(),
  );
}

void main() {
  testWidgets('app inicia sem erros (com sessão salva abre o Dashboard)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeAuthRepository(session: true)));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Rota: /dashboard'), findsOneWidget);
  });

  testWidgets('sem sessão, a rota protegida redireciona para /login',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeAuthRepository(session: false)));
    await tester.pumpAndSettle();

    expect(find.text('Rota: /login'), findsOneWidget);
    expect(find.text('Rota: /dashboard'), findsNothing);
  });

  testWidgets('sair limpa a sessão e volta para /login',
      (WidgetTester tester) async {
    final repository = FakeAuthRepository(session: true);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sair'));
    await tester.pumpAndSettle();

    expect(repository.calls, contains('logout'));
    expect(repository.session, isFalse);
    expect(find.text('Rota: /login'), findsOneWidget);
  });
}
