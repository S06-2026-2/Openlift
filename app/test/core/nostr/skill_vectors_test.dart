// RNF-02 — vetores da skill validar-evento-nostr, com verificação Schnorr real.
//
// Os vetores ficam em .agents/skills/validar-evento-nostr/examples/vetores/:
// um evento assinado válido e dois adulterados (conteúdo trocado com id
// antigo; conteúdo trocado com id recalculado e assinatura antiga). O script
// Python da skill só verifica assinatura com `coincurve`; aqui a verificação
// roda sempre, com o mesmo NostrEvent que o app usa para ler o relay.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openlift/core/nostr/nostr_event.dart';

const _dir = '../.agents/skills/validar-evento-nostr/examples/vetores';

NostrEvent _vector(String name) => NostrEvent.fromJson(
    jsonDecode(File('$_dir/$name').readAsStringSync()) as Map<String, dynamic>);

void main() {
  group('vetores da skill validar-evento-nostr', () {
    test('evento válido passa', () {
      expect(_vector('valido.json').isValid, isTrue);
    });

    test('conteúdo adulterado é rejeitado (id não confere)', () {
      final event = _vector('adulterado-conteudo.json');
      expect(event.toUnsigned().computeId(), isNot(event.id));
      expect(event.isValid, isFalse);
    });

    test('assinatura adulterada é rejeitada (id confere, sig não)', () {
      final event = _vector('adulterado-assinatura.json');
      expect(event.toUnsigned().computeId(), event.id);
      expect(event.isValid, isFalse);
    });
  });
}
