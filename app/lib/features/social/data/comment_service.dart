// Comentários (ADR-0012): `kind 1111` (NIP-22) lidos e publicados direto
// nos relays. Nada de comentário no Postgres (ADR-0004): a contagem é feita
// no aparelho, a partir dos eventos com assinatura verificada (RF-51).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nostr/nostr_kinds.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/nostr_identity_service.dart';
import '../domain/comment.dart';
import 'nostr_relay_service.dart';
import 'post_service.dart' show PostPublishException;

class CommentService {
  CommentService({
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

  /// Comentários de cada evento em [rootIds], do mais antigo para o mais
  /// novo. Todo id pedido aparece no mapa (lista vazia se ninguém comentou).
  Future<Map<String, List<Comment>>> load(List<String> rootIds) async {
    if (rootIds.isEmpty) return const {};
    final result = await _relays.query([
      {
        'kinds': [NostrKinds.comment],
        '#E': rootIds,
      },
    ]);
    final byRoot = {for (final id in rootIds) id: <Comment>[]};
    for (final event in result.events) {
      if (!event.isValid) continue;
      final comment = Comment.fromEvent(event);
      if (comment == null) continue;
      byRoot[comment.rootId]?.add(comment);
    }
    for (final list in byRoot.values) {
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    return byRoot;
  }

  /// Publica um comentário em [target]. Lança [PostPublishException] se
  /// nenhum relay aceitar.
  Future<Comment> publish(CommentTarget target, String text) async {
    final me = await _auth.fetchMe();
    final signer = await _identity.signerFor(me.id);
    final event = signer.sign(CommentEvent.build(
      pubkey: signer.publicKey,
      target: target,
      text: text,
      createdAt: _clock().millisecondsSinceEpoch ~/ 1000,
      relayHint: _relays.relays.isEmpty ? '' : _relays.relays.first,
    ));
    final results = await _relays.publish([event]);
    if (!results.any((r) => r.accepted)) {
      throw const PostPublishException(
        'Não foi possível comentar agora. Verifique sua conexão e tente '
        'novamente.',
      );
    }
    return Comment.fromEvent(event)!;
  }
}

final commentServiceProvider = Provider<CommentService>(
  (ref) => CommentService(
    auth: ref.watch(authRepositoryProvider),
    identity: ref.watch(nostrIdentityServiceProvider),
    relays: ref.watch(nostrRelayServiceProvider),
  ),
);
