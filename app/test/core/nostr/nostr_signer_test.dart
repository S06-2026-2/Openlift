// NOSTR-02 — Assinatura Schnorr (BIP-340) local e verificação.
//
// Vetores: bitcoin/bips, bip-0340/test-vectors.csv, linhas 0–14 (mensagem de
// 32 bytes, como o id NOSTR). Só as colunas públicas: chave pública,
// mensagem, assinatura e resultado esperado. Nenhuma chave privada aqui —
// a dos testes de assinatura é gerada em tempo de execução (RNF-01).

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:openlift/core/nostr/nostr_crypto.dart';
import 'package:openlift/core/nostr/nostr_event.dart';
import 'package:openlift/core/nostr/nostr_kinds.dart';
import 'package:openlift/core/nostr/nostr_signer.dart';

const _vectors = [
  (
    'f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9',
    '0000000000000000000000000000000000000000000000000000000000000000',
    'e907831f80848d1069a5371b402410364bdf1c5f8307b0084c55f1ce2dca821525f66a4a85ea8b71e482a74f382d2ce5ebeee8fdb2172f477df4900d310536c0',
    true
  ),
  (
    'dff1d77f2a671c5f36183726db2341be58feae1da2deced843240f7b502ba659',
    '243f6a8885a308d313198a2e03707344a4093822299f31d0082efa98ec4e6c89',
    '6896bd60eeae296db48a229ff71dfe071bde413e6d43f917dc8dcf8c78de33418906d11ac976abccb20b091292bff4ea897efcb639ea871cfa95f6de339e4b0a',
    true
  ),
  (
    'dd308afec5777e13121fa72b9cc1b7cc0139715309b086c960e18fd969774eb8',
    '7e2d58d8b3bcdf1abadec7829054f90dda9805aab56c77333024b9d0a508b75c',
    '5831aaeed7b44bb74e5eab94ba9d4294c49bcf2a60728d8b4c200f50dd313c1bab745879a5ad954a72c45a91c3a51d3c7adea98d82f8481e0e1e03674a6f3fb7',
    true
  ),
  (
    '25d1dff95105f5253c4022f628a996ad3a0d95fbf21d468a1b33f8c160d8f517',
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
    '7eb0509757e246f19449885651611cb965ecc1a187dd51b64fda1edc9637d5ec97582b9cb13db3933705b32ba982af5af25fd78881ebb32771fc5922efc66ea3',
    true
  ), // test fails if msg is reduced modulo p or n
  (
    'd69c3509bb99e412e68b0fe8544e72837dfa30746d8be2aa65975f29d22dc7b9',
    '4df3c3f68fcc83b27e9d42c90431a72499f17875c81a599b566c9889b9696703',
    '00000000000000000000003b78ce563f89a0ed9414f5aa28ad0d96d6795f9c6376afb1548af603b3eb45c9f8207dee1060cb71c04e80f593060b07d28308d7f4',
    true
  ),
  (
    'eefdea4cdb677750a420fee807eacf21eb9898ae79b9768766e4faa04a2d4a34',
    '243f6a8885a308d313198a2e03707344a4093822299f31d0082efa98ec4e6c89',
    '6cff5c3ba86c69ea4b7376f31a9bcb4f74c1976089b2d9963da2e5543e17776969e89b4c5564d00349106b8497785dd7d1d713a8ae82b32fa79d5f7fc407d39b',
    false
  ), // public key not on the curve
  (
    'dff1d77f2a671c5f36183726db2341be58feae1da2deced843240f7b502ba659',
    '243f6a8885a308d313198a2e03707344a4093822299f31d0082efa98ec4e6c89',
    'fff97bd5755eeea420453a14355235d382f6472f8568a18b2f057a14602975563cc27944640ac607cd107ae10923d9ef7a73c643e166be5ebeafa34b1ac553e2',
    false
  ), // has_even_y(R) is false
  (
    'dff1d77f2a671c5f36183726db2341be58feae1da2deced843240f7b502ba659',
    '243f6a8885a308d313198a2e03707344a4093822299f31d0082efa98ec4e6c89',
    '1fa62e331edbc21c394792d2ab1100a7b432b013df3f6ff4f99fcb33e0e1515f28890b3edb6e7189b630448b515ce4f8622a954cfe545735aaea5134fccdb2bd',
    false
  ), // negated message
  (
    'dff1d77f2a671c5f36183726db2341be58feae1da2deced843240f7b502ba659',
    '243f6a8885a308d313198a2e03707344a4093822299f31d0082efa98ec4e6c89',
    '6cff5c3ba86c69ea4b7376f31a9bcb4f74c1976089b2d9963da2e5543e177769961764b3aa9b2ffcb6ef947b6887a226e8d7c93e00c5ed0c1834ff0d0c2e6da6',
    false
  ), // negated s value
  (
    'dff1d77f2a671c5f36183726db2341be58feae1da2deced843240f7b502ba659',
    '243f6a8885a308d313198a2e03707344a4093822299f31d0082efa98ec4e6c89',
    '0000000000000000000000000000000000000000000000000000000000000000123dda8328af9c23a94c1feecfd123ba4fb73476f0d594dcb65c6425bd186051',
    false
  ), // sG - eP is infinite (x(inf) as 0)
  (
    'dff1d77f2a671c5f36183726db2341be58feae1da2deced843240f7b502ba659',
    '243f6a8885a308d313198a2e03707344a4093822299f31d0082efa98ec4e6c89',
    '00000000000000000000000000000000000000000000000000000000000000017615fbaf5ae28864013c099742deadb4dba87f11ac6754f93780d5a1837cf197',
    false
  ), // sG - eP is infinite (x(inf) as 1)
  (
    'dff1d77f2a671c5f36183726db2341be58feae1da2deced843240f7b502ba659',
    '243f6a8885a308d313198a2e03707344a4093822299f31d0082efa98ec4e6c89',
    '4a298dacae57395a15d0795ddbfd1dcb564da82b0f269bc70a74f8220429ba1d69e89b4c5564d00349106b8497785dd7d1d713a8ae82b32fa79d5f7fc407d39b',
    false
  ), // sig[0:32] is not an X coordinate on the curve
  (
    'dff1d77f2a671c5f36183726db2341be58feae1da2deced843240f7b502ba659',
    '243f6a8885a308d313198a2e03707344a4093822299f31d0082efa98ec4e6c89',
    'fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f69e89b4c5564d00349106b8497785dd7d1d713a8ae82b32fa79d5f7fc407d39b',
    false
  ), // sig[0:32] is equal to field size
  (
    'dff1d77f2a671c5f36183726db2341be58feae1da2deced843240f7b502ba659',
    '243f6a8885a308d313198a2e03707344a4093822299f31d0082efa98ec4e6c89',
    '6cff5c3ba86c69ea4b7376f31a9bcb4f74c1976089b2d9963da2e5543e177769fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141',
    false
  ), // sig[32:64] is equal to curve order
  (
    'fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc30',
    '243f6a8885a308d313198a2e03707344a4093822299f31d0082efa98ec4e6c89',
    '6cff5c3ba86c69ea4b7376f31a9bcb4f74c1976089b2d9963da2e5543e17776969e89b4c5564d00349106b8497785dd7d1d713a8ae82b32fa79d5f7fc407d39b',
    false
  ), // public key exceeds the field size
];

/// Chave aleatória gerada só para este processo de teste.
String _randomSecretHex() {
  final random = Random.secure();
  return List.generate(32, (_) => random.nextInt(256))
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
}

void main() {
  group('verificação BIP-340 (vetores oficiais)', () {
    for (var i = 0; i < _vectors.length; i++) {
      final (pubkey, message, signature, expected) = _vectors[i];
      test('vetor $i → $expected', () {
        expect(
            NostrCrypto.verifySignature(pubkey, message, signature), expected);
      });
    }

    test('entrada malformada não lança: só devolve false', () {
      final (pubkey, message, signature, _) = _vectors[1];
      expect(NostrCrypto.verifySignature(pubkey, message, 'zz'), isFalse);
      expect(NostrCrypto.verifySignature('xyz', message, signature), isFalse);
      expect(NostrCrypto.verifySignature(pubkey, '00', signature), isFalse);
    });
  });

  group('NostrSigner', () {
    test('assina localmente e o evento verifica (ida e volta)', () {
      final signer = NostrSigner.generate();
      final unsigned = UnsignedNostrEvent(
        pubkey: signer.publicKey,
        createdAt: 1792447800,
        kind: NostrKinds.workoutRecord,
        tags: const [
          ['alt', 'Registro de treino de 19/10/2026'],
        ],
        content: '',
      );

      final event = signer.sign(unsigned);

      expect(event.pubkey, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(event.sig, matches(RegExp(r'^[0-9a-f]{128}$')));
      expect(event.id, unsigned.computeId());
      expect(event.isValid, isTrue);
    });

    test('a mesma chave sempre dá a mesma pubkey', () {
      final secret = _randomSecretHex();

      expect(NostrSigner.fromPrivateKeyHex(secret).publicKey,
          NostrSigner.fromPrivateKeyHex(secret).publicKey);
    });

    test('recusa assinar evento de outra pubkey', () {
      final signer = NostrSigner.generate();
      final other = NostrSigner.generate();
      final unsigned = UnsignedNostrEvent(
        pubkey: other.publicKey,
        createdAt: 1792447800,
        kind: NostrKinds.workoutRecord,
        tags: const [],
        content: '',
      );

      expect(() => signer.sign(unsigned), throwsArgumentError);
    });

    test('RNF-01: toString e erros nunca mostram a chave privada', () {
      final secret = _randomSecretHex();
      final signer = NostrSigner.fromPrivateKeyHex(secret);

      expect(signer.toString(), isNot(contains(secret)));
      expect(signer.toString(), contains(signer.publicKey));

      for (final bad in [
        secret.substring(1), // curta
        '${secret.substring(0, 63)}g', // não hex
        '0' * 64, // zero
        'f' * 64, // ≥ ordem da curva
      ]) {
        expect(
          () => NostrSigner.fromPrivateKeyHex(bad),
          throwsA(isA<ArgumentError>()
              .having((e) => e.toString(), 'mensagem', isNot(contains(bad)))),
        );
      }
    });
  });
}
