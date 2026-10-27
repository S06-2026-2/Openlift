// FE-04 — Identidade NOSTR invisível ao usuário (ADR-0005, ADR-0006, RNF-01).
//
// - `ensureIdentity` gera o par de chaves no 1º uso da conta neste aparelho
//   e reutiliza nas próximas vezes. O usuário nunca vê a palavra "chave".
// - `importNsec` é o caminho avançado (RF-04) para quem já tem identidade.
// - Para fora deste serviço só sai a parte PÚBLICA ([NostrIdentity]); a
//   chave privada fica no armazenamento seguro e no [NostrSigner].
// - Nada aqui loga, imprime ou coloca a chave privada em mensagem de erro.
//
// Biblioteca: `bip340` (Dart puro, mesma do núcleo NOSTR-02), que roda igual
// na web e no APK — resultado do spike registrado no ADR-0005.

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nostr/nip19.dart';
import '../../../core/nostr/nostr_signer.dart';
import '../../../core/storage/secure_storage_service.dart';

/// Parte pública da identidade: é o que pode ir para a tela e para a API.
class NostrIdentity {
  const NostrIdentity({required this.publicKeyHex, required this.npub});

  factory NostrIdentity.fromSigner(NostrSigner signer) => NostrIdentity(
        publicKeyHex: signer.publicKey,
        npub: Nip19.encodeNpub(signer.publicKey),
      );

  final String publicKeyHex;
  final String npub;

  @override
  bool operator ==(Object other) =>
      other is NostrIdentity && other.publicKeyHex == publicKeyHex;

  @override
  int get hashCode => publicKeyHex.hashCode;

  @override
  String toString() => 'NostrIdentity($npub)';
}

/// Chave colada no fluxo avançado que não é um `nsec` válido.
class InvalidNsecException implements Exception {
  const InvalidNsecException();

  @override
  String toString() => 'Identidade NOSTR inválida';
}

class NostrIdentityService {
  NostrIdentityService({required SecureStorageService storage, Random? random})
      : _storage = storage,
        _random = random ?? Random.secure();

  final SecureStorageService _storage;
  final Random _random;

  /// Identidade da conta neste aparelho; gera e guarda se ainda não existir.
  Future<NostrIdentity> ensureIdentity(int userId) async {
    return NostrIdentity.fromSigner(await signerFor(userId));
  }

  /// Assinante da conta (para publicar eventos, FE-05). Gera a chave no 1º uso.
  Future<NostrSigner> signerFor(int userId) async {
    final stored = await _storage.readNostrSecret(userId);
    if (stored != null) {
      try {
        return NostrSigner.fromPrivateKeyHex(stored);
      } on ArgumentError {
        // Valor corrompido: cai para gerar uma identidade nova.
      }
    }
    final secret = _generateSecretHex();
    await _storage.saveNostrSecret(userId, secret);
    return NostrSigner.fromPrivateKeyHex(secret);
  }

  /// Lê um `nsec` sem guardar nada. Lança [InvalidNsecException].
  NostrIdentity previewNsec(String nsec) =>
      NostrIdentity.fromSigner(_signerFromNsec(nsec));

  /// Substitui a identidade da conta neste aparelho pela do `nsec` (RF-04).
  Future<NostrIdentity> importNsec(int userId, String nsec) async {
    final secret = Nip19.decodeNsecOrNull(nsec);
    if (secret == null) throw const InvalidNsecException();
    final signer = _signerFromHex(secret);
    await _storage.saveNostrSecret(userId, secret);
    return NostrIdentity.fromSigner(signer);
  }

  NostrSigner _signerFromNsec(String nsec) {
    final secret = Nip19.decodeNsecOrNull(nsec);
    if (secret == null) throw const InvalidNsecException();
    return _signerFromHex(secret);
  }

  NostrSigner _signerFromHex(String secret) {
    try {
      return NostrSigner.fromPrivateKeyHex(secret);
    } on ArgumentError {
      throw const InvalidNsecException();
    }
  }

  String _generateSecretHex() {
    while (true) {
      final candidate = List.generate(32, (_) => _random.nextInt(256))
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      try {
        NostrSigner.fromPrivateKeyHex(candidate);
        return candidate;
      } on ArgumentError {
        // Fora do intervalo da curva (probabilidade ~2^-128): tenta de novo.
      }
    }
  }
}

final nostrIdentityServiceProvider = Provider<NostrIdentityService>(
  (ref) =>
      NostrIdentityService(storage: ref.watch(secureStorageServiceProvider)),
);
