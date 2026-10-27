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
// FE-04: depois de entrar (e ao restaurar a sessão), garante a identidade
// NOSTR da conta neste aparelho e registra o `npub` no backend. É melhor
// esforço: falha de rede não impede o login e a sincronização é refeita na
// próxima abertura do app. Nada disso aparece na tela (ADR-0005).

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/auth_repository.dart';
import '../data/nostr_identity_service.dart';

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
    if (hasSession) unawaited(_syncNostrIdentity());
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

  /// Caminho avançado (RF-04): passa a usar uma identidade NOSTR que a pessoa
  /// já tem. Registra o `npub` no backend antes de trocar a chave local, para
  /// app e servidor nunca ficarem com identidades diferentes. Devolve a
  /// mensagem de erro para a tela, ou `null` se deu certo.
  Future<String?> importNostrIdentity(String nsec) async {
    final service = ref.read(nostrIdentityServiceProvider);
    final repository = ref.read(authRepositoryProvider);
    try {
      final identity = service.previewNsec(nsec);
      final me = await repository.fetchMe();
      await repository.registerNostrIdentity(identity.npub);
      await service.importNsec(me.id, nsec);
      return null;
    } on InvalidNsecException {
      return 'Isso não é uma identidade NOSTR (nsec) válida.';
    } on ApiException catch (e) {
      return e.message;
    } on Object {
      return 'Não foi possível importar a identidade. Tente novamente.';
    }
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
      // Em segundo plano: o login não espera a identidade NOSTR.
      unawaited(_syncNostrIdentity());
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

  /// Gera (ou reaproveita) a identidade da conta e registra o `npub` se o
  /// backend ainda não tiver esse. Nunca lança.
  Future<void> _syncNostrIdentity() async {
    try {
      final repository = ref.read(authRepositoryProvider);
      final me = await repository.fetchMe();
      final identity =
          await ref.read(nostrIdentityServiceProvider).ensureIdentity(me.id);
      if (me.npub != identity.npub) {
        await repository.registerNostrIdentity(identity.npub);
      }
    } on Object {
      // Sem log de propósito (RNF-01). Tenta de novo na próxima abertura.
    }
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);
