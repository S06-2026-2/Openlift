// Helper de teste: AuthRepository falso (sem rede, sem plugins de plataforma).

import 'package:openlift/core/network/api_exception.dart';
import 'package:openlift/features/auth/data/auth_repository.dart';
import 'package:openlift/features/auth/domain/user_model.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.session = false,
    this.loginError,
    this.registerError,
    this.latency = Duration.zero,
  });

  /// Há sessão salva no "dispositivo"?
  bool session;

  /// Se definido, `login` lança este erro.
  ApiException? loginError;

  /// Se definido, `register` lança este erro.
  ApiException? registerError;

  /// Atraso simulado das chamadas (para observar o estado de loading).
  Duration latency;

  /// Registro das chamadas, na ordem: 'login:<email>', 'register:<email>'...
  final List<String> calls = [];

  /// Usuário devolvido por `fetchMe` (FE-04).
  int userId = 1;
  String email = 'a@b.com';

  /// `npub` que o "backend" tem registrado para o usuário.
  String? registeredNpub;

  /// Se definido, `registerNostrIdentity` lança este erro.
  ApiException? nostrIdentityError;

  /// Chamadas da identidade NOSTR, separadas de [calls]: 'me', 'npub:<npub>'.
  final List<String> identityCalls = [];

  @override
  Future<UserModel> fetchMe() async {
    identityCalls.add('me');
    return UserModel(id: userId, email: email, npub: registeredNpub);
  }

  @override
  Future<UserModel> registerNostrIdentity(String npub) async {
    identityCalls.add('npub:$npub');
    final error = nostrIdentityError;
    if (error != null) throw error;
    registeredNpub = npub;
    return UserModel(id: userId, email: email, npub: npub);
  }

  @override
  Stream<void> get sessionExpired => const Stream<void>.empty();

  @override
  Future<bool> hasSession() async => session;

  @override
  Future<UserModel> register({
    required String email,
    required String password,
  }) async {
    calls.add('register:$email');
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final error = registerError;
    if (error != null) throw error;
    return UserModel(id: 1, email: email);
  }

  @override
  Future<void> login({required String email, required String password}) async {
    calls.add('login:$email');
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final error = loginError;
    if (error != null) throw error;
    session = true;
  }

  @override
  Future<void> logout() async {
    calls.add('logout');
    session = false;
  }
}
