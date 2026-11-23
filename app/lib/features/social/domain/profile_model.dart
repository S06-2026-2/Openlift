// Perfil da rede social (ADR-0012): nome de usuário único, nome de exibição,
// bio e foto. A API guarda o diretório de nomes (NIP-05); o app publica o
// mesmo perfil como `kind 0` (NIP-01) para qualquer cliente NOSTR ver.

import 'dart:convert';

import '../../../core/nostr/nostr_event.dart';
import '../../../core/nostr/nostr_kinds.dart';

/// Regra do nome de usuário, igual à da API: 3 a 20 de a-z, 0-9, _ e ponto.
final RegExp usernamePattern = RegExp(r'^[a-z0-9_.]{3,20}$');

/// Tira espaços e `@` do começo e passa para minúsculas, como a API.
String normalizeUsername(String raw) {
  var value = raw.trim();
  while (value.startsWith('@')) {
    value = value.substring(1);
  }
  return value.toLowerCase();
}

/// Mensagem de erro do nome, ou `null` se está no formato.
String? validateUsername(String raw) {
  final value = normalizeUsername(raw);
  if (value.isEmpty) return 'Escolha um nome de usuário.';
  if (value.length < 3) return 'Use pelo menos 3 caracteres.';
  if (value.length > 20) return 'Use no máximo 20 caracteres.';
  if (!usernamePattern.hasMatch(value)) {
    return 'Só letras sem acento, números, _ e ponto.';
  }
  return null;
}

class SocialProfile {
  const SocialProfile({
    required this.username,
    required this.npub,
    required this.pubkey,
    required this.nip05,
    this.displayName,
    this.bio,
    this.avatarUrl,
  });

  factory SocialProfile.fromJson(Map<String, dynamic> json) {
    String required(String key) {
      final value = json[key];
      if (value is String && value.isNotEmpty) return value;
      throw FormatException('Campo "$key" ausente');
    }

    String? optional(String key) {
      final value = json[key];
      return value is String && value.isNotEmpty ? value : null;
    }

    return SocialProfile(
      username: required('username'),
      npub: required('npub'),
      pubkey: required('pubkey'),
      nip05: required('nip05'),
      displayName: optional('display_name'),
      bio: optional('bio'),
      avatarUrl: optional('avatar_url'),
    );
  }

  final String username;
  final String? displayName;
  final String? bio;
  final String? avatarUrl;

  /// ID público na rede (NIP-19).
  final String npub;

  /// A mesma chave em hex, como aparece nos eventos.
  final String pubkey;

  /// Nome verificado `usuario@dominio` (NIP-05).
  final String nip05;

  /// Nome para mostrar: o de exibição, ou o `@usuario`.
  String get title => displayName ?? '@$username';

  String get handle => '@$username';
}

/// O que a pessoa preenche ao criar ou editar o perfil.
class ProfileInput {
  const ProfileInput({
    required this.username,
    this.displayName,
    this.bio,
    this.avatarUrl,
  });

  final String username;
  final String? displayName;
  final String? bio;
  final String? avatarUrl;

  Map<String, Object?> toJson() => {
        'username': normalizeUsername(username),
        'display_name': _blankToNull(displayName),
        'bio': _blankToNull(bio),
        'avatar_url': _blankToNull(avatarUrl),
      };

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

/// `kind 0` (NIP-01) com o perfil salvo. `nip05` liga o nome à chave
/// (NIP-05), verificável em `/.well-known/nostr.json` da API.
abstract final class ProfileMetadataEvent {
  static UnsignedNostrEvent build({
    required String pubkey,
    required SocialProfile profile,
    required int createdAt,
  }) {
    return UnsignedNostrEvent(
      pubkey: pubkey,
      createdAt: createdAt,
      kind: NostrKinds.metadata,
      tags: const [],
      content: jsonEncode({
        'name': profile.username,
        if (profile.displayName != null) 'display_name': profile.displayName,
        if (profile.bio != null) 'about': profile.bio,
        if (profile.avatarUrl != null) 'picture': profile.avatarUrl,
        'nip05': profile.nip05,
      }),
    );
  }
}
