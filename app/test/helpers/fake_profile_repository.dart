// Helper de teste: ProfileRepository em memória (sem rede), com nomes
// únicos como a API (ADR-0012).

import 'dart:typed_data';

import 'package:openlift/core/network/api_exception.dart';
import 'package:openlift/features/social/data/profile_repository.dart';
import 'package:openlift/features/social/domain/profile_model.dart';

/// Perfil pronto para testes.
SocialProfile fakeProfile(
  String username, {
  String pubkey = '',
  String? displayName,
  String? avatarUrl,
  String? bio,
}) {
  final key = pubkey.isEmpty
      ? username.codeUnits.first.toRadixString(16).padLeft(64, '0')
      : pubkey;
  return SocialProfile(
    username: username,
    displayName: displayName,
    bio: bio,
    avatarUrl: avatarUrl,
    npub: 'npub1$username',
    pubkey: key,
    nip05: '$username@api.test',
  );
}

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({this.mine, List<SocialProfile> others = const []}) {
    for (final profile in others) {
      directory[profile.username] = profile;
    }
    final own = mine;
    if (own != null) directory[own.username] = own;
  }

  /// O próprio perfil (`null` = ainda não criou).
  SocialProfile? mine;

  /// Chave pública da conta, usada ao criar o perfil.
  String myPubkey = 'f' * 64;

  /// Todos os perfis por nome (inclui o próprio).
  final Map<String, SocialProfile> directory = {};

  final List<ProfileInput> saved = [];
  final List<String> uploads = [];

  /// Se definido, toda chamada falha com ele.
  ApiException? error;

  void _fail() {
    final failure = error;
    if (failure != null) throw failure;
  }

  @override
  Future<SocialProfile?> fetchMine() async {
    _fail();
    return mine;
  }

  @override
  Future<SocialProfile> saveMine(ProfileInput input) async {
    _fail();
    final username = normalizeUsername(input.username);
    final owner = directory[username];
    if (owner != null && owner.pubkey != myPubkey) {
      throw const ApiException(
        'Esse nome de usuário já está em uso. Escolha outro.',
        statusCode: 409,
      );
    }
    final json = input.toJson();
    final previous = mine;
    if (previous != null) directory.remove(previous.username);
    final profile = SocialProfile(
      username: username,
      displayName: json['display_name'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      npub: 'npub1$username',
      pubkey: myPubkey,
      nip05: '$username@api.test',
    );
    saved.add(input);
    directory[username] = profile;
    return mine = profile;
  }

  @override
  Future<bool> isAvailable(String username) async {
    _fail();
    final owner = directory[normalizeUsername(username)];
    return owner == null || owner.pubkey == myPubkey;
  }

  @override
  Future<List<SocialProfile>> search(String query) async {
    _fail();
    final term = normalizeUsername(query);
    return [
      for (final profile in directory.values)
        if (profile.username.startsWith(term) ||
            (profile.displayName?.toLowerCase().contains(term) ?? false))
          profile,
    ]..sort((a, b) => a.username.compareTo(b.username));
  }

  @override
  Future<List<SocialProfile>> byPubkeys(List<String> pubkeys) async {
    _fail();
    return [
      for (final profile in directory.values)
        if (pubkeys.contains(profile.pubkey)) profile,
    ];
  }

  @override
  Future<SocialProfile> byUsername(String username) async {
    _fail();
    final profile = directory[normalizeUsername(username)];
    if (profile == null) {
      throw const ApiException('Perfil não encontrado.', statusCode: 404);
    }
    return profile;
  }

  @override
  Future<UploadedMedia> uploadPhoto(Uint8List bytes, String filename) async {
    _fail();
    uploads.add(filename);
    return UploadedMedia(
      url: 'http://api.test/media/${uploads.length}.webp',
      mimeType: 'image/webp',
      width: 800,
      height: 600,
      sha256: 'a' * 64,
    );
  }
}
