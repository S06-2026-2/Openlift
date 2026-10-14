// FE-01 — AuthController (mocktail no AuthRepository): restauração de sessão,
// login, cadastro, logout e expiração.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openlift/core/network/api_exception.dart';
import 'package:openlift/features/auth/data/auth_repository.dart';
import 'package:openlift/features/auth/domain/user_model.dart';
import 'package:openlift/features/auth/presentation/auth_controller.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repository;
  late StreamController<void> expired;

  ProviderContainer makeContainer({bool hasSession = false}) {
    when(() => repository.hasSession()).thenAnswer((_) async => hasSession);
    when(() => repository.sessionExpired).thenAnswer((_) => expired.stream);
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    repository = _MockAuthRepository();
    expired = StreamController<void>.broadcast();
    addTearDown(expired.close);
  });

  test('restaura sessão salva ao abrir o app', () async {
    final container = makeContainer(hasSession: true);

    final state = await container.read(authControllerProvider.future);

    expect(state.isAuthenticated, isTrue);
  });

  test('sem sessão salva começa deslogado', () async {
    final container = makeContainer();

    final state = await container.read(authControllerProvider.future);

    expect(state.isAuthenticated, isFalse);
    expect(state.errorMessage, isNull);
  });

  test('signIn com sucesso autentica', () async {
    final container = makeContainer();
    when(() => repository.login(email: 'a@b.com', password: 'senha-segura'))
        .thenAnswer((_) async {});
    await container.read(authControllerProvider.future);

    final ok = await container
        .read(authControllerProvider.notifier)
        .signIn(email: 'a@b.com', password: 'senha-segura');

    expect(ok, isTrue);
    final state = container.read(authControllerProvider).requireValue;
    expect(state.isAuthenticated, isTrue);
    expect(state.isSubmitting, isFalse);
  });

  test('signIn com credencial inválida guarda a mensagem humana', () async {
    final container = makeContainer();
    when(() => repository.login(email: 'a@b.com', password: 'errada-123'))
        .thenThrow(const ApiException('E-mail ou senha incorretos.'));
    await container.read(authControllerProvider.future);

    final ok = await container
        .read(authControllerProvider.notifier)
        .signIn(email: 'a@b.com', password: 'errada-123');

    expect(ok, isFalse);
    final state = container.read(authControllerProvider).requireValue;
    expect(state.isAuthenticated, isFalse);
    expect(state.errorMessage, 'E-mail ou senha incorretos.');
  });

  test('erro inesperado nunca vaza o texto da exceção', () async {
    final container = makeContainer();
    when(() => repository.login(email: any(named: 'email'), password: any(named: 'password')))
        .thenThrow(StateError('boom: stack trace aqui'));
    await container.read(authControllerProvider.future);

    await container
        .read(authControllerProvider.notifier)
        .signIn(email: 'a@b.com', password: 'senha-segura');

    final message =
        container.read(authControllerProvider).requireValue.errorMessage;
    expect(message, 'Algo deu errado. Tente novamente.');
  });

  test('isSubmitting fica true enquanto o login acontece', () async {
    final container = makeContainer();
    final gate = Completer<void>();
    when(() => repository.login(email: any(named: 'email'), password: any(named: 'password')))
        .thenAnswer((_) => gate.future);
    await container.read(authControllerProvider.future);

    final future = container
        .read(authControllerProvider.notifier)
        .signIn(email: 'a@b.com', password: 'senha-segura');

    expect(
      container.read(authControllerProvider).requireValue.isSubmitting,
      isTrue,
    );
    gate.complete();
    await future;
    expect(
      container.read(authControllerProvider).requireValue.isSubmitting,
      isFalse,
    );
  });

  test('signUp cadastra e já entra', () async {
    final container = makeContainer();
    when(() => repository.register(email: 'n@b.com', password: 'senha-segura'))
        .thenAnswer(
      (_) async => const UserModel(id: 1, email: 'n@b.com'),
    );
    when(() => repository.login(email: 'n@b.com', password: 'senha-segura'))
        .thenAnswer((_) async {});
    await container.read(authControllerProvider.future);

    final ok = await container
        .read(authControllerProvider.notifier)
        .signUp(email: 'n@b.com', password: 'senha-segura');

    expect(ok, isTrue);
    verifyInOrder([
      () => repository.register(email: 'n@b.com', password: 'senha-segura'),
      () => repository.login(email: 'n@b.com', password: 'senha-segura'),
    ]);
    expect(
      container.read(authControllerProvider).requireValue.isAuthenticated,
      isTrue,
    );
  });

  test('signUp com e-mail repetido não tenta logar', () async {
    final container = makeContainer();
    when(() => repository.register(email: 'n@b.com', password: 'senha-segura'))
        .thenThrow(const ApiException('Este e-mail já está cadastrado.'));
    await container.read(authControllerProvider.future);

    final ok = await container
        .read(authControllerProvider.notifier)
        .signUp(email: 'n@b.com', password: 'senha-segura');

    expect(ok, isFalse);
    verifyNever(() => repository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ));
  });

  test('signOut limpa o storage e desloga', () async {
    final container = makeContainer(hasSession: true);
    when(() => repository.logout()).thenAnswer((_) async {});
    await container.read(authControllerProvider.future);

    await container.read(authControllerProvider.notifier).signOut();

    verify(() => repository.logout()).called(1);
    expect(
      container.read(authControllerProvider).requireValue.isAuthenticated,
      isFalse,
    );
  });

  test('sessão expirada no servidor desloga com aviso', () async {
    final container = makeContainer(hasSession: true);
    await container.read(authControllerProvider.future);

    expired.add(null);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(authControllerProvider).requireValue;
    expect(state.isAuthenticated, isFalse);
    expect(state.errorMessage, contains('sessão expirou'));
  });

  test('clearError remove a mensagem', () async {
    final container = makeContainer();
    when(() => repository.login(email: any(named: 'email'), password: any(named: 'password')))
        .thenThrow(const ApiException('E-mail ou senha incorretos.'));
    await container.read(authControllerProvider.future);
    final notifier = container.read(authControllerProvider.notifier);
    await notifier.signIn(email: 'a@b.com', password: 'errada-123');

    notifier.clearError();

    expect(
      container.read(authControllerProvider).requireValue.errorMessage,
      isNull,
    );
  });
}
