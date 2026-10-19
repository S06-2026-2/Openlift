// NOSTR-02 — Primitivas criptográficas da NIP-01: SHA-256 do evento e
// verificação Schnorr (BIP-340). Pacote `bip340` em Dart puro, que roda
// igual na web e no APK.

import 'dart:convert';

import 'package:bip340/bip340.dart' as bip340;
import 'package:crypto/crypto.dart';

abstract final class NostrCrypto {
  static final RegExp _hex64 = RegExp(r'^[0-9a-f]{64}$');
  static final RegExp _hex128 = RegExp(r'^[0-9a-f]{128}$');

  /// SHA-256 do texto em UTF-8, em hex minúsculo.
  static String sha256Hex(String text) =>
      sha256.convert(utf8.encode(text)).toString();

  /// Verifica uma assinatura BIP-340. Nunca lança: entrada malformada é
  /// simplesmente uma assinatura inválida (RF-51).
  static bool verifySignature(
    String publicKeyHex,
    String messageHex,
    String signatureHex,
  ) {
    if (!_hex64.hasMatch(publicKeyHex) ||
        !_hex64.hasMatch(messageHex) ||
        !_hex128.hasMatch(signatureHex)) {
      return false;
    }
    try {
      return bip340.verify(publicKeyHex, messageHex, signatureHex);
    } catch (_) {
      // Ponto fora da curva, ponto no infinito etc.
      return false;
    }
  }
}
