// FE-01 — Controller (Riverpod AsyncNotifier) do fluxo de autenticação.
//
// Estados:
//  - AsyncLoading  → restaurando a sessão salva (só na abertura do app);
//  - AsyncData     → [AuthState] com `status`, `isSubmitting` e `errorMessage`;
//  - AsyncError    → falha inesperada ao ler o armazenamento (tratada como
//                    "sem sessão": o usuário cai na tela de login).
//
// O estado de envio/erro vive dentro de [AuthState] (e não em AsyncLoading)
// para o formulário continuar na tela enquanto o login acontece.
//
// TODO(NOSTR): após signUp/signIn, garantir a identidade NOSTR local
//   (NostrIdentityService.ensureIdentityExists) e registrar o npub.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/auth_repository.dart';

enum AuthStatus { unauthenticated, authenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final AuthStatus status;
  final bool isSubmitting;
  final String? errorMessage;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthController extends AsyncNotifier<AuthState> {
  static const String _sessionExpiredMessage =
      'Sua sessão expirou. Entre novamente.';

  @override
  Future<AuthState> build() async {
    final repository = ref.watch(authRepositoryProvider);

    final subscription = repository.sessionExpired.listen((_) {
      state = const AsyncData(
        AuthState(errorMessage: _sessionExpiredMessage),
      );
    });
    ref.onDispose(subscription.cancel);

    final hasSession = await repository.hasSession();
    return AuthState(
      status: hasSession
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated,
    );
  }

  AuthState get _current => state.valueOrNull ?? const AuthState();

  /// Cria a conta e já entra. Retorna `true` em caso de sucesso.
  Future<bool> signUp({required String email, required String password}) {
    return _submit(() async {
      final repository = ref.read(authRepositoryProvider);
      await repository.register(email: email, password: password);
      await repository.login(email: email, password: password);
    });
  }

  /// Entra com e-mail e senha. Retorna `true` em caso de sucesso.
  Future<bool> signIn({required String email, required String password}) {
    return _submit(() {
      return ref
          .read(authRepositoryProvider)
          .login(email: email, password: password);
    });
  }

  /// Sai: limpa os tokens do dispositivo.
  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(AuthState());
  }

  /// Some com a mensagem de erro (ex.: ao alternar Login ↔ Cadastro).
  void clearError() {
    final current = _current;
    if (current.errorMessage == null) return;
    state = AsyncData(current.copyWith(clearError: true));
  }

  Future<bool> _submit(Future<void> Function() action) async {
    state = AsyncData(_current.copyWith(isSubmitting: true, clearError: true));
    try {
      await action();
      state = const AsyncData(AuthState(status: AuthStatus.authenticated));
      return true;
    } on ApiException catch (e) {
      state = AsyncData(AuthState(errorMessage: e.message));
      return false;
    } on Object {
      state = const AsyncData(
        AuthState(errorMessage: 'Algo deu errado. Tente novamente.'),
      );
      return false;
    }
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);
