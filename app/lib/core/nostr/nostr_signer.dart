// NOSTR-02 — Assinatura local de eventos (BIP-340), sem servidor (ADR-0005).
//
// RNF-01: a chave privada fica só neste objeto. Ela não aparece em
// toString, em mensagem de erro nem em log, e nunca vai para a rede. Quem
// guarda a chave entre sessões é o serviço de identidade (S2-01).

import 'dart:math';

import 'package:bip340/bip340.dart' as bip340;

import 'nostr_event.dart';

class NostrSigner {
  NostrSigner._(this._secretHex) : publicKey = bip340.getPublicKey(_secretHex);

  /// Cria o assinante a partir de uma chave privada em hex (64 caracteres).
  /// Chave inválida lança [ArgumentError] sem repetir a chave na mensagem.
  factory NostrSigner.fromPrivateKeyHex(String secretHex) {
    final normalized = secretHex.toLowerCase();
    if (!_isValidSecret(normalized)) {
      throw ArgumentError('Chave privada NOSTR inválida');
    }
    return NostrSigner._(normalized);
  }

  /// Gera uma chave nova com o gerador seguro da plataforma.
  factory NostrSigner.generate({Random? random}) {
    final source = random ?? Random.secure();
    while (true) {
      final candidate = _toHex(List.generate(32, (_) => source.nextInt(256)));
      if (_isValidSecret(candidate)) return NostrSigner._(candidate);
    }
  }

  /// Ordem do grupo da secp256k1: a chave privada fica em [1, n − 1].
  static final BigInt _curveOrder = BigInt.parse(
    'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141',
    radix: 16,
  );
  static final RegExp _hex64 = RegExp(r'^[0-9a-f]{64}$');

  final String _secretHex;

  /// Chave pública x-only em hex, a `pubkey` dos eventos.
  final String publicKey;

  /// Assina o evento. Ele precisa ter sido montado com a [publicKey] deste
  /// assinante.
  NostrEvent sign(UnsignedNostrEvent event, {Random? random}) {
    if (event.pubkey != publicKey) {
      throw ArgumentError('O evento é de outra pubkey');
    }
    final id = event.computeId();
    final source = random ?? Random.secure();
    final aux = _toHex(List.generate(32, (_) => source.nextInt(256)));
    return NostrEvent(
      id: id,
      pubkey: publicKey,
      createdAt: event.createdAt,
      kind: event.kind,
      tags: event.tags,
      content: event.content,
      sig: bip340.sign(_secretHex, id, aux),
    );
  }

  @override
  String toString() => 'NostrSigner($publicKey)';

  static bool _isValidSecret(String hex) {
    if (!_hex64.hasMatch(hex)) return false;
    final value = BigInt.parse(hex, radix: 16);
    return value > BigInt.zero && value < _curveOrder;
  }

  static String _toHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
