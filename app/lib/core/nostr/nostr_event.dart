// NOSTR-02 — Evento NOSTR (NIP-01): forma sem assinatura (para montar e
// assinar) e forma assinada (para publicar, ler e verificar).
//
// A leitura é estrita no formato: campo faltando ou tipo errado vira
// FormatException, e quem consome decide se descarta o evento.

import 'dart:convert';

import 'nostr_crypto.dart';

final RegExp _hex64 = RegExp(r'^[0-9a-f]{64}$');
final RegExp _hex128 = RegExp(r'^[0-9a-f]{128}$');

List<List<String>> _freezeTags(List<List<String>> tags) =>
    List.unmodifiable([for (final tag in tags) List<String>.unmodifiable(tag)]);

class UnsignedNostrEvent {
  const UnsignedNostrEvent({
    required this.pubkey,
    required this.createdAt,
    required this.kind,
    required this.tags,
    required this.content,
  });

  /// Chave pública x-only em hex (não o `npub`).
  final String pubkey;

  /// Segundos Unix.
  final int createdAt;
  final int kind;
  final List<List<String>> tags;
  final String content;

  /// Serialização canônica da NIP-01: `[0, pubkey, created_at, kind, tags,
  /// content]` em JSON sem espaços, com acentos em UTF-8 cru.
  String serialize() => jsonEncode([0, pubkey, createdAt, kind, tags, content]);

  /// `id` do evento: SHA-256 da serialização canônica.
  String computeId() => NostrCrypto.sha256Hex(serialize());
}

class NostrEvent {
  NostrEvent({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.kind,
    required List<List<String>> tags,
    required this.content,
    required this.sig,
  }) : tags = _freezeTags(tags);

  final String id;
  final String pubkey;
  final int createdAt;
  final int kind;
  final List<List<String>> tags;
  final String content;
  final String sig;

  factory NostrEvent.fromJson(Map<String, dynamic> json) {
    T field<T>(String name) {
      final value = json[name];
      if (value is! T) throw FormatException('Evento sem "$name" válido');
      return value;
    }

    String hex(String name, RegExp pattern) {
      final value = field<String>(name);
      if (!pattern.hasMatch(value)) {
        throw FormatException('Evento com "$name" fora do formato hex');
      }
      return value;
    }

    final rawTags = field<List<dynamic>>('tags');
    final tags = <List<String>>[];
    for (final tag in rawTags) {
      if (tag is! List || tag.any((item) => item is! String)) {
        throw const FormatException('Evento com tag que não é lista de texto');
      }
      tags.add(tag.cast<String>());
    }

    return NostrEvent(
      id: hex('id', _hex64),
      pubkey: hex('pubkey', _hex64),
      createdAt: field<int>('created_at'),
      kind: field<int>('kind'),
      tags: tags,
      content: field<String>('content'),
      sig: hex('sig', _hex128),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'pubkey': pubkey,
        'created_at': createdAt,
        'kind': kind,
        'tags': tags,
        'content': content,
        'sig': sig,
      };

  UnsignedNostrEvent toUnsigned() => UnsignedNostrEvent(
        pubkey: pubkey,
        createdAt: createdAt,
        kind: kind,
        tags: tags,
        content: content,
      );

  /// RF-51/RNF-02: o `id` confere com o conteúdo e a assinatura é da
  /// `pubkey`. Evento inválido é descartado, nunca "consertado".
  bool get isValid =>
      toUnsigned().computeId() == id &&
      NostrCrypto.verifySignature(pubkey, id, sig);

  /// Primeiro valor da tag [name] (`["name", valor, ...]`), se existir.
  String? firstTagValue(String name) {
    for (final tag in tags) {
      if (tag.length >= 2 && tag.first == name) return tag[1];
    }
    return null;
  }
}
