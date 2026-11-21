// Salvar o perfil (ADR-0012): grava na API (nome único, NIP-05) e publica o
// `kind 0` assinado no aparelho (ADR-0005) nos relays (ADR-0007).
//
// A API é quem garante o nome único, então ela vem primeiro. Se nenhum relay
// aceitar o `kind 0`, o perfil continua salvo: o app avisa e a próxima
// edição publica de novo.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/data/nostr_identity_service.dart';
import '../domain/profile_model.dart';
import 'nostr_relay_service.dart';
import 'profile_repository.dart';

class ProfileSaveResult {
  const ProfileSaveResult({required this.profile, required this.published});

  final SocialProfile profile;

  /// Algum relay aceitou o `kind 0`.
  final bool published;
}

class ProfileService {
  ProfileService({
    required ProfileRepository profiles,
    required AuthRepository auth,
    required NostrIdentityService identity,
    required NostrRelayService relays,
    DateTime Function()? clock,
  })  : _profiles = profiles,
        _auth = auth,
        _identity = identity,
        _relays = relays,
        _clock = clock ?? DateTime.now;

  final ProfileRepository _profiles;
  final AuthRepository _auth;
  final NostrIdentityService _identity;
  final NostrRelayService _relays;
  final DateTime Function() _clock;

  /// Lança `ApiException` se a API recusar (ex.: nome em uso).
  Future<ProfileSaveResult> save(ProfileInput input) async {
    final profile = await _profiles.saveMine(input);
    return ProfileSaveResult(
        profile: profile, published: await _publish(profile));
  }

  Future<bool> _publish(SocialProfile profile) async {
    try {
      final me = await _auth.fetchMe();
      final signer = await _identity.signerFor(me.id);
      final event = signer.sign(ProfileMetadataEvent.build(
        pubkey: signer.publicKey,
        profile: profile,
        createdAt: _clock().millisecondsSinceEpoch ~/ 1000,
      ));
      final results = await _relays.publish([event]);
      return results.any((r) => r.accepted);
    } on Object {
      return false;
    }
  }
}

final profileServiceProvider = Provider<ProfileService>(
  (ref) => ProfileService(
    profiles: ref.watch(profileRepositoryProvider),
    auth: ref.watch(authRepositoryProvider),
    identity: ref.watch(nostrIdentityServiceProvider),
    relays: ref.watch(nostrRelayServiceProvider),
  ),
);
