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

    expect(find.text('Início'), findsWidgets);
    expect(find.text('Meus treinos'), findsOneWidget);
  });

  testWidgets('sem sessão, a rota protegida redireciona para /login',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeAuthRepository(session: false)));
    await tester.pumpAndSettle();

    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Meus treinos'), findsNothing);
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
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('navegação inferior leva ao Perfil, que permite sair',
      (WidgetTester tester) async {
    final repository = FakeAuthRepository(session: true);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Perfil em breve'), findsOneWidget);

    await tester.tap(find.text('Sair da conta'));
    await tester.pumpAndSettle();
    expect(repository.session, isFalse);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('tela larga usa barra lateral no lugar da inferior',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(FakeAuthRepository(session: true)));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.text('Social'));
    await tester.pumpAndSettle();
    expect(find.text('Feed social em breve'), findsOneWidget);
  });
}
