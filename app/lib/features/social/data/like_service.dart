// FE-08 — Curtir um treino (RF-32): kind 7 (NIP-25) assinado no aparelho
// (ADR-0005) e enviado aos relays (ADR-0007). O backend não recebe o like: o
// worker o lê dos relays e atualiza a contagem (ADR-0004).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/data/nostr_identity_service.dart';
import '../domain/like_model.dart';
import '../domain/published_workout.dart';
import 'nostr_relay_service.dart';

/// Nenhum relay aceitou o like. A [message] é para o usuário.
class LikePublishException implements Exception {
  const LikePublishException();

  String get message => 'Não foi possível curtir agora. '
      'Verifique sua conexão e tente novamente.';

  @override
  String toString() => message;
}

class LikeService {
  LikeService({
    required AuthRepository auth,
    required NostrIdentityService identity,
    required NostrRelayService relays,
    DateTime Function()? clock,
  })  : _auth = auth,
        _identity = identity,
        _relays = relays,
        _clock = clock ?? DateTime.now;

  final AuthRepository _auth;
  final NostrIdentityService _identity;
  final NostrRelayService _relays;
  final DateTime Function() _clock;

  /// Lança [LikePublishException] se nenhum relay aceitou.
  Future<void> like(PublishedWorkout workout) async {
    final me = await _auth.fetchMe();
    final signer = await _identity.signerFor(me.id);
    final event = signer.sign(LikeEvent.build(
      pubkey: signer.publicKey,
      workout: workout,
      createdAt: _clock().millisecondsSinceEpoch ~/ 1000,
      relayHint: _relays.relays.isEmpty ? '' : _relays.relays.first,
    ));
    final results = await _relays.publish([event]);
    if (!results.any((r) => r.accepted)) throw const LikePublishException();
  }
}

final likeServiceProvider = Provider<LikeService>(
  (ref) => LikeService(
    auth: ref.watch(authRepositoryProvider),
    identity: ref.watch(nostrIdentityServiceProvider),
    relays: ref.watch(nostrRelayServiceProvider),
  ),
);
