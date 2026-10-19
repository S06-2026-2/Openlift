// NOSTR-02 — Núcleo NIP-01: serialização canônica, id, (de)serialização
// estrita e verificação de assinatura.
//
// Os eventos de referência vêm de docs/nips/examples/ (assinados por uma
// implementação independente, a referência do BIP-340 em Python). Nenhuma
// chave privada é guardada aqui: o teste de assinatura gera a chave na hora.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openlift/core/nostr/nostr_event.dart';
import 'package:openlift/core/nostr/nostr_kinds.dart';

Map<String, dynamic> _example(String name) =>
    jsonDecode(File('../docs/nips/examples/$name').readAsStringSync())
        as Map<String, dynamic>;

List<Map<String, dynamic>> _templates() =>
    (jsonDecode(File('../docs/nips/examples/exercise-templates.json')
            .readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();

Map<String, dynamic> _copy(Map<String, dynamic> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

void main() {
  group('NostrKinds (ADR-0003)', () {
    test('treino é 1301 e modelo de exercício é 33401 — nunca kind 1', () {
      expect(NostrKinds.workoutRecord, 1301);
      expect(NostrKinds.exerciseTemplate, 33401);
      expect(NostrKinds.reaction, 7);
      expect(NostrKinds.contacts, 3);
      expect(NostrKinds.metadata, 0);
      expect(NostrKinds.workoutRecord, isNot(1));
    });
  });

  group('serialização canônica (NIP-01)', () {
    test('sem espaços, acento cru e escapes do JSON', () {
      const event = UnsignedNostrEvent(
        pubkey:
            '3361fd648012d81dfb176fd52b6c0f6dd9c5979b3bf40beaa30a9dae199a7f6a',
        createdAt: 1700000000,
        kind: 1301,
        tags: [
          ['alt', 'séries'],
        ],
        content: 'linha 1\nlinha "2"\\',
      );

      expect(
        event.serialize(),
        '[0,"3361fd648012d81dfb176fd52b6c0f6dd9c5979b3bf40beaa30a9dae199a7f6a",'
        '1700000000,1301,[["alt","séries"]],"linha 1\\nlinha \\"2\\"\\\\"]',
      );
    });

    test('id do treino de exemplo bate com o da implementação de referência',
        () {
      final json = _example('workout-record.json');
      final event = NostrEvent.fromJson(json);

      expect(event.toUnsigned().computeId(), json['id']);
    });

    test('id dos modelos de exercício de exemplo também bate', () {
      for (final json in _templates()) {
        expect(NostrEvent.fromJson(json).toUnsigned().computeId(), json['id']);
      }
    });
  });

  group('fromJson / toJson', () {
    test('ida e volta preserva o evento', () {
      final json = _example('workout-record.json');

      expect(NostrEvent.fromJson(json).toJson(), json);
    });

    test('campo obrigatório faltando é FormatException', () {
      for (final field in [
        'id',
        'pubkey',
        'created_at',
        'kind',
        'tags',
        'content',
        'sig',
      ]) {
        final json = _copy(_example('workout-record.json'))..remove(field);
        expect(() => NostrEvent.fromJson(json), throwsFormatException,
            reason: field);
      }
    });

    test('tipos e formatos errados são FormatException', () {
      final cases = <String, void Function(Map<String, dynamic>)>{
        'created_at em texto': (j) => j['created_at'] = '1792447800',
        'kind em texto': (j) => j['kind'] = '1301',
        'id em maiúsculas': (j) => j['id'] = (j['id'] as String).toUpperCase(),
        'pubkey curta': (j) => j['pubkey'] = 'abc',
        'npub no lugar da pubkey': (j) => j['pubkey'] =
            'npub1xdslmeyqztvpm7chdl2jkmq0dhvut9um806qh64rp2w6uxv60a4q8r8hd7',
        'sig curta': (j) => j['sig'] = 'ab',
        'tag com número': (j) => (j['tags'] as List).add(['x', 1]),
        'tags não lista': (j) => j['tags'] = 'x',
        'content nulo': (j) => j['content'] = null,
      };
      cases.forEach((name, mutate) {
        final json = _copy(_example('workout-record.json'));
        mutate(json);
        expect(() => NostrEvent.fromJson(json), throwsFormatException,
            reason: name);
      });
    });
  });

  group('verificação (RF-51, RNF-02)', () {
    test('exemplos assinados são válidos', () {
      expect(
          NostrEvent.fromJson(_example('workout-record.json')).isValid, isTrue);
      for (final json in _templates()) {
        expect(NostrEvent.fromJson(json).isValid, isTrue);
      }
    });

    test('evento adulterado é inválido', () {
      final cases = <String, void Function(Map<String, dynamic>)>{
        'content': (j) => j['content'] = 'adulterado',
        'carga da série': (j) {
          final tag = (j['tags'] as List)
              .cast<List>()
              .firstWhere((t) => t.first == 'exercise');
          tag[3] = '800';
        },
        'created_at': (j) => j['created_at'] = (j['created_at'] as int) + 1,
        'sig de outro evento': (j) => j['sig'] = _templates().first['sig'],
        'id recalculado mas sig antiga': (j) {
          j['content'] = 'adulterado';
          j['id'] = NostrEvent.fromJson(j).toUnsigned().computeId();
        },
      };
      cases.forEach((name, mutate) {
        final json = _copy(_example('workout-record.json'));
        mutate(json);
        expect(NostrEvent.fromJson(json).isValid, isFalse, reason: name);
      });
    });
  });
}
