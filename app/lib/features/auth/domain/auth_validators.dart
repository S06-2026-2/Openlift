// FE-02 — Validadores dos formulários de login/cadastro (funções puras).
//
// Regras: e-mail válido, senha com no mínimo 8 caracteres (mesmo mínimo do
// backend: RegisterRequest.password min_length=8) e confirmação igual à senha.

abstract final class AuthValidators {
  static const int minPasswordLength = 8;

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Informe seu e-mail.';
    if (!_emailPattern.hasMatch(email)) return 'Informe um e-mail válido.';
    return null;
  }

  static String? password(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Informe sua senha.';
    if (password.length < minPasswordLength) {
      return 'A senha deve ter pelo menos $minPasswordLength caracteres.';
    }
    return null;
  }

  /// Valida a confirmação contra a senha digitada no outro campo.
  static String? confirmation(String? value, String password) {
    final confirmation = value ?? '';
    if (confirmation.isEmpty) return 'Confirme sua senha.';
    if (confirmation != password) return 'As senhas não coincidem.';
    return null;
  }
}
