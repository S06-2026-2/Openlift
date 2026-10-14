// FE-02 — Validadores de e-mail, senha e confirmação.

import 'package:flutter_test/flutter_test.dart';
import 'package:openlift/features/auth/domain/auth_validators.dart';

void main() {
  group('email', () {
    test('vazio pede o e-mail', () {
      expect(AuthValidators.email(''), 'Informe seu e-mail.');
      expect(AuthValidators.email('   '), 'Informe seu e-mail.');
      expect(AuthValidators.email(null), 'Informe seu e-mail.');
    });

    test('formato inválido é recusado', () {
      for (final invalid in ['abc', 'a@', '@b.com', 'a@b', 'a b@c.com', 'a@b.c']) {
        expect(
          AuthValidators.email(invalid),
          'Informe um e-mail válido.',
          reason: invalid,
        );
      }
    });

    test('e-mails válidos passam (com espaços nas pontas)', () {
      for (final valid in ['a@b.com', 'nome.sobrenome@dominio.com.br', ' a@b.io ']) {
        expect(AuthValidators.email(valid), isNull, reason: valid);
      }
    });
  });

  group('password', () {
    test('vazia pede a senha', () {
      expect(AuthValidators.password(''), 'Informe sua senha.');
      expect(AuthValidators.password(null), 'Informe sua senha.');
    });

    test('menos de 8 caracteres é recusada', () {
      expect(
        AuthValidators.password('1234567'),
        'A senha deve ter pelo menos 8 caracteres.',
      );
    });

    test('8 caracteres ou mais passa', () {
      expect(AuthValidators.password('12345678'), isNull);
      expect(AuthValidators.password('uma senha longa'), isNull);
    });
  });

  group('confirmation', () {
    test('vazia pede a confirmação', () {
      expect(AuthValidators.confirmation('', 'abc12345'), 'Confirme sua senha.');
    });

    test('diferente da senha é recusada', () {
      expect(
        AuthValidators.confirmation('abc12346', 'abc12345'),
        'As senhas não coincidem.',
      );
    });

    test('igual à senha passa', () {
      expect(AuthValidators.confirmation('abc12345', 'abc12345'), isNull);
    });
  });
}
