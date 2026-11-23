// Postagens de foto (ADR-0012): publicar `kind 20` e ler dos relays, mais as
// curtidas das postagens.
//
// A foto sobe para a API (sem EXIF); o evento é assinado no aparelho
// (ADR-0005) e vai para os relays (ADR-0007). Curtida de postagem é `kind 7`
// (NIP-25) contada a partir dos relays, no aparelho: o worker do backend só
// projeta curtidas de treino (BE-09), e nada social vive só no Postgres
// (ADR-0004).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nostr/nostr_event.dart';
import '../../../core/nostr/nostr_kinds.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/nostr_identity_service.dart';
import '../domain/like_model.dart';
import '../domain/photo_post.dart';
import 'network_workouts_service.dart' show RelaysUnavailableException;
import 'nostr_relay_service.dart';
import 'photo_picker.dart';
import 'profile_repository.dart';

/// Nenhum relay aceitou o evento. A [message] é para o usuário.
class PostPublishException implements Exception {
  const PostPublishException([
    this.message = 'Não foi possível publicar agora. '
        'Verifique sua conexão e tente novamente.',
  ]);

  final String message;

  @override
  String toString() => message;
}

/// Curtidas de uma postagem, contadas a partir dos `kind 7` dos relays.
class PostLikes {
  const PostLikes({this.count = 0, this.likedByMe = false});

  final int count;
  final bool likedByMe;
}

class PostService {
  PostService({
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

  static const int defaultLimit = 100;

  final ProfileRepository _profiles;
  final AuthRepository _auth;
  final NostrIdentityService _identity;
  final NostrRelayService _relays;
  final DateTime Function() _clock;

  int get _now => _clock().millisecondsSinceEpoch ~/ 1000;

  String get _relayHint => _relays.relays.isEmpty ? '' : _relays.relays.first;

  /// Envia a foto e publica o `kind 20`. Lança `ApiException` se a foto for
  /// recusada e [PostPublishException] se nenhum relay aceitar.
  Future<PhotoPost> publish(PickedPhoto photo, String caption) async {
    final media = await _profiles.uploadPhoto(photo.bytes, photo.name);
    final me = await _auth.fetchMe();
    final signer = await _identity.signerFor(me.id);
    final event = signer.sign(PhotoPostEvent.build(
      pubkey: signer.publicKey,
      media: media,
      caption: caption,
      createdAt: _now,
    ));
    final results = await _relays.publish([event]);
    if (!results.any((r) => r.accepted)) throw const PostPublishException();
    return PhotoPost.fromEvent(event)!;
  }

  /// Postagens de [authors], da mais nova para a mais antiga. Evento com
  /// assinatura inválida fica de fora (RF-51).
  Future<List<PhotoPost>> load(
    List<String> authors, {
    int limit = defaultLimit,
  }) async {
    if (authors.isEmpty) return const [];
    final result = await _relays.query([
      {
        'kinds': [NostrKinds.picture],
        'authors': authors,
        'limit': limit,
      },
    ]);
    if (!result.anyRelayResponded) throw const RelaysUnavailableException();
    final wanted = authors.toSet();
    final posts = <PhotoPost>[
      for (final event in result.events)
        if (wanted.contains(event.pubkey) && event.isValid)
          if (PhotoPost.fromEvent(event) case final post?) post,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return posts;
  }

  /// Curtidas de cada postagem em [eventIds]. Uma por pessoa (RN-06); só
  /// conta `+` (a NIP-25 trata `-` como "não curti").
  Future<Map<String, PostLikes>> likes(
    List<String> eventIds,
    String ownPubkey,
  ) async {
    if (eventIds.isEmpty) return const {};
    final result = await _relays.query([
      {
        'kinds': [NostrKinds.reaction],
        '#e': eventIds,
      },
    ]);
    final wanted = eventIds.toSet();
    final likers = <String, Set<String>>{};
    for (final event in result.events) {
      if (event.content == '-' || !event.isValid) continue;
      final target = _lastETag(event);
      if (target == null || !wanted.contains(target)) continue;
      likers.putIfAbsent(target, () => {}).add(event.pubkey);
    }
    return {
      for (final id in eventIds)
        id: PostLikes(
          count: likers[id]?.length ?? 0,
          likedByMe: likers[id]?.contains(ownPubkey) ?? false,
        ),
    };
  }

  /// Curte [post] com `kind 7`. Lança [PostPublishException] se nenhum relay
  /// aceitar.
  Future<void> like(PhotoPost post) async {
    final me = await _auth.fetchMe();
    final signer = await _identity.signerFor(me.id);
    final event = signer.sign(UnsignedNostrEvent(
      pubkey: signer.publicKey,
      createdAt: _now,
      kind: NostrKinds.reaction,
      tags: [
        ['e', post.eventId, _relayHint, post.pubkey],
        ['p', post.pubkey, _relayHint],
        ['k', '${NostrKinds.picture}'],
      ],
      content: LikeEvent.like,
    ));
    final results = await _relays.publish([event]);
    if (!results.any((r) => r.accepted)) {
      throw const PostPublishException(
        'Não foi possível curtir agora. Verifique sua conexão e tente '
        'novamente.',
      );
    }
  }

  /// NIP-25: o alvo da reação é a última tag `e`.
  static String? _lastETag(NostrEvent event) {
    String? target;
    for (final tag in event.tags) {
      if (tag.length > 1 && tag[0] == 'e') target = tag[1];
    }
    return target;
  }
}

final postServiceProvider = Provider<PostService>(
  (ref) => PostService(
    profiles: ref.watch(profileRepositoryProvider),
    auth: ref.watch(authRepositoryProvider),
    identity: ref.watch(nostrIdentityServiceProvider),
    relays: ref.watch(nostrRelayServiceProvider),
  ),
);
