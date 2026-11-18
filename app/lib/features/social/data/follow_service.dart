// NOSTR-04 — Seguir e deixar de seguir (RF-30, NIP-02).
//
// A lista de seguidos mora no relay, não no Postgres (ADR-0004): é lida do
// kind 3 mais recente da identidade e cada mudança publica um kind 3 novo,
// assinado no aparelho (ADR-0005). Outro aparelho com a mesma identidade lê a
// mesma lista.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nostr/nostr_kinds.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/nostr_identity_service.dart';
import '../domain/contact_list.dart';
import 'network_workouts_service.dart';
import 'nostr_relay_service.dart';

/// Nenhum relay aceitou a nova lista. A [message] é para o usuário.
class FollowPublishException implements Exception {
  const FollowPublishException();

  String get message => 'Não foi possível atualizar quem você segue. '
      'Verifique sua conexão e tente novamente.';

  @override
  String toString() => message;
}

class FollowService {
  FollowService({
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

  /// Lista atual da identidade deste aparelho; vazia se ela nunca seguiu
  /// ninguém. Lança [RelaysUnavailableException] se nenhum relay respondeu:
  /// sem a lista atual, publicar uma nova apagaria quem já era seguido.
  Future<ContactList> load() async {
    final me = await _auth.fetchMe();
    final own = await _identity.ensureIdentity(me.id);
    final result = await _relays.query([
      {
        'kinds': [NostrKinds.contacts],
        'authors': [own.publicKeyHex],
      },
    ]);
    if (!result.anyRelayResponded) throw const RelaysUnavailableException();
    return ContactList.latest(result.events, own.publicKeyHex);
  }

  /// Assina e publica [next] inteira. Devolve a lista com o `created_at`
  /// publicado. Lança [FollowPublishException] se nenhum relay aceitou.
  Future<ContactList> publish(ContactList next) async {
    final me = await _auth.fetchMe();
    final signer = await _identity.signerFor(me.id);
    final event = signer.sign(next.toUnsignedEvent(
      pubkey: signer.publicKey,
      now: _clock().millisecondsSinceEpoch ~/ 1000,
    ));
    final results = await _relays.publish([event]);
    if (!results.any((r) => r.accepted)) {
      throw const FollowPublishException();
    }
    return ContactList.fromEvent(event);
  }
}

final followServiceProvider = Provider<FollowService>(
  (ref) => FollowService(
    auth: ref.watch(authRepositoryProvider),
    identity: ref.watch(nostrIdentityServiceProvider),
    relays: ref.watch(nostrRelayServiceProvider),
  ),
);
