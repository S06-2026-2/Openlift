// FE-02 — Widget tests de Login e Cadastro: validação, credencial inválida,
// loading e sucesso (repository mockado), navegação Login ↔ Cadastro.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlift/core/network/api_exception.dart';
import 'package:openlift/features/auth/data/auth_repository.dart';
import 'package:openlift/main.dart';

import '../../helpers/fake_auth_repository.dart';

Future<void> _pumpApp(
  WidgetTester tester,
  FakeAuthRepository repository,
) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      child: const OpenLiftApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _field(int index) => find.byType(TextFormField).at(index);

bool _isObscured(WidgetTester tester, int index) => tester
    .widget<EditableText>(find.byType(EditableText).at(index))
    .obscureText;

void main() {
  group('Login', () {
    testWidgets('mostra marca, campos, botão e link de cadastro',
        (tester) async {
      await _pumpApp(tester, FakeAuthRepository());

      expect(find.text('OpenLift'), findsOneWidget);
      expect(find.text('Seu treino. Seus dados.'), findsOneWidget);
      expect(find.text('E-mail'), findsOneWidget);
      expect(find.text('Senha'), findsOneWidget);
      expect(find.text('Entrar'), findsOneWidget);
      expect(find.text('Não tem conta? Cadastre-se'), findsOneWidget);
    });

    testWidgets('campos vazios mostram os erros e não chamam a API',
        (tester) async {
      final repository = FakeAuthRepository();
      await _pumpApp(tester, repository);

      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      expect(find.text('Informe seu e-mail.'), findsOneWidget);
      expect(find.text('Informe sua senha.'), findsOneWidget);
      expect(repository.calls, isEmpty);
    });

    testWidgets('e-mail inválido e senha curta são recusados', (tester) async {
      final repository = FakeAuthRepository();
      await _pumpApp(tester, repository);

      await tester.enterText(_field(0), 'nao-e-um-email');
      await tester.enterText(_field(1), '1234567');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      expect(find.text('Informe um e-mail válido.'), findsOneWidget);
      expect(
        find.text('A senha deve ter pelo menos 8 caracteres.'),
        findsOneWidget,
      );
      expect(repository.calls, isEmpty);
    });

    testWidgets('credencial inválida mostra mensagem humana e fica na tela',
        (tester) async {
      final repository = FakeAuthRepository(
        loginError: const ApiException(
          'E-mail ou senha incorretos.',
          statusCode: 401,
        ),
      );
      await _pumpApp(tester, repository);

      await tester.enterText(_field(0), 'a@b.com');
      await tester.enterText(_field(1), 'senha-errada');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
      expect(find.text('Entrar'), findsOneWidget);
      expect(find.text('Rota: /dashboard'), findsNothing);
    });

    testWidgets('sucesso leva ao dashboard', (tester) async {
      final repository = FakeAuthRepository();
      await _pumpApp(tester, repository);

      await tester.enterText(_field(0), '  a@b.com ');
      await tester.enterText(_field(1), 'senha-segura');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      expect(repository.calls, ['login:a@b.com']);
      expect(find.text('Rota: /dashboard'), findsOneWidget);
    });

    testWidgets('botão mostra loading e bloqueia os campos durante o login',
        (tester) async {
      final repository = FakeAuthRepository(
        latency: const Duration(milliseconds: 300),
      );
      await _pumpApp(tester, repository);

      await tester.enterText(_field(0), 'a@b.com');
      await tester.enterText(_field(1), 'senha-segura');
      await tester.tap(find.text('Entrar'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Entrar'), findsNothing);
      expect(
        tester.widget<TextFormField>(_field(0)).enabled,
        isFalse,
      );

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Rota: /dashboard'), findsOneWidget);
    });

    testWidgets('Enter no campo de senha envia o formulário', (tester) async {
      final repository = FakeAuthRepository();
      await _pumpApp(tester, repository);

      await tester.enterText(_field(0), 'a@b.com');
      await tester.enterText(_field(1), 'senha-segura');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(repository.calls, ['login:a@b.com']);
      expect(find.text('Rota: /dashboard'), findsOneWidget);
    });

    testWidgets('olho alterna a visibilidade da senha', (tester) async {
      await _pumpApp(tester, FakeAuthRepository());
      expect(_isObscured(tester, 1), isTrue);

      await tester.tap(find.byTooltip('Mostrar senha'));
      await tester.pump();
      expect(_isObscured(tester, 1), isFalse);

      await tester.tap(find.byTooltip('Ocultar senha'));
      await tester.pump();
      expect(_isObscured(tester, 1), isTrue);
    });

    testWidgets('link alterna para o cadastro', (tester) async {
      await _pumpApp(tester, FakeAuthRepository());

      await tester.tap(find.text('Não tem conta? Cadastre-se'));
      await tester.pumpAndSettle();

      expect(find.text('Criar conta'), findsOneWidget);
      expect(find.text('Confirmar senha'), findsOneWidget);
    });
  });

  group('Cadastro', () {
    Future<void> openSignup(
      WidgetTester tester,
      FakeAuthRepository repository,
    ) async {
      await _pumpApp(tester, repository);
      await tester.tap(find.text('Não tem conta? Cadastre-se'));
      await tester.pumpAndSettle();
    }

    testWidgets('confirmação diferente da senha é recusada', (tester) async {
      final repository = FakeAuthRepository();
      await openSignup(tester, repository);

      await tester.enterText(_field(0), 'novo@b.com');
      await tester.enterText(_field(1), 'senha-segura');
      await tester.enterText(_field(2), 'senha-diferente');
      await tester.tap(find.text('Criar conta'));
      await tester.pumpAndSettle();

      expect(find.text('As senhas não coincidem.'), findsOneWidget);
      expect(repository.calls, isEmpty);
    });

    testWidgets('sucesso cadastra, entra e vai ao dashboard', (tester) async {
      final repository = FakeAuthRepository();
      await openSignup(tester, repository);

      await tester.enterText(_field(0), 'novo@b.com');
      await tester.enterText(_field(1), 'senha-segura');
      await tester.enterText(_field(2), 'senha-segura');
      await tester.tap(find.text('Criar conta'));
      await tester.pumpAndSettle();

      expect(repository.calls, ['register:novo@b.com', 'login:novo@b.com']);
      expect(find.text('Rota: /dashboard'), findsOneWidget);
    });

    testWidgets('e-mail já cadastrado mostra aviso claro', (tester) async {
      final repository = FakeAuthRepository(
        registerError: const ApiException(
          'Este e-mail já está cadastrado. Tente entrar.',
          statusCode: 409,
        ),
      );
      await openSignup(tester, repository);

      await tester.enterText(_field(0), 'novo@b.com');
      await tester.enterText(_field(1), 'senha-segura');
      await tester.enterText(_field(2), 'senha-segura');
      await tester.tap(find.text('Criar conta'));
      await tester.pumpAndSettle();

      expect(
        find.text('Este e-mail já está cadastrado. Tente entrar.'),
        findsOneWidget,
      );
      expect(repository.calls, ['register:novo@b.com']);
    });

    testWidgets('link volta para o login e limpa o erro', (tester) async {
      final repository = FakeAuthRepository(
        registerError: const ApiException('Este e-mail já está cadastrado.'),
      );
      await openSignup(tester, repository);

      await tester.enterText(_field(0), 'novo@b.com');
      await tester.enterText(_field(1), 'senha-segura');
      await tester.enterText(_field(2), 'senha-segura');
      await tester.tap(find.text('Criar conta'));
      await tester.pumpAndSettle();
      expect(find.text('Este e-mail já está cadastrado.'), findsOneWidget);

      await tester.tap(find.text('Já tem conta? Entrar'));
      await tester.pumpAndSettle();

      expect(find.text('Não tem conta? Cadastre-se'), findsOneWidget);
      expect(find.text('Este e-mail já está cadastrado.'), findsNothing);
    });
  });
}
