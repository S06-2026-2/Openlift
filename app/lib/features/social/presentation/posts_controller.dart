// Estado das postagens de foto (ADR-0012).
//
// - [postsFeedProvider]: postagens da própria conta e de quem ela segue;
// - [personPostsProvider]: postagens de uma pessoa (página de perfil);
// - [postLikesProvider]: curtidas das postagens na tela, com atualização
//   otimista ao curtir.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/post_service.dart';
import '../domain/photo_post.dart';
import 'network_feed_controller.dart';

final postsFeedProvider =
    FutureProvider.autoDispose<List<PhotoPost>>((ref) async {
  final own = await ref.watch(ownIdentityProvider.future);
  final following = await ref.watch(followingProvider.future);
  final authors = {own.publicKeyHex, ...following.pubkeys}.toList();
  return ref.watch(postServiceProvider).load(authors);
});

final personPostsProvider =
    FutureProvider.autoDispose.family<List<PhotoPost>, String>(
  (ref, pubkey) => ref.watch(postServiceProvider).load([pubkey]),
);

class PostLikesController extends AutoDisposeNotifier<Map<String, PostLikes>> {
  final Set<String> _publishing = {};

  @override
  Map<String, PostLikes> build() => const {};

  PostLikes likesOf(String eventId) => state[eventId] ?? const PostLikes();

  /// Lê dos relays as curtidas de [posts]. Falha deixa como estava.
  Future<void> fetch(Iterable<PhotoPost> posts) async {
    final ids = [for (final post in posts) post.eventId];
    if (ids.isEmpty) return;
    try {
      final own = await ref.read(ownIdentityProvider.future);
      final counts =
          await ref.read(postServiceProvider).likes(ids, own.publicKeyHex);
      state = {
        ...state,
        for (final entry in counts.entries)
          // Like recém-feito que o relay ainda não devolveu não some.
          entry.key:
              (state[entry.key]?.likedByMe ?? false) && !entry.value.likedByMe
                  ? PostLikes(count: entry.value.count + 1, likedByMe: true)
                  : entry.value,
      };
    } on Object {
      return;
    }
  }

  /// Curte [post]. Devolve a mensagem de erro para a tela, ou `null`.
  Future<String?> like(PhotoPost post) async {
    final id = post.eventId;
    final before = likesOf(id);
    if (before.likedByMe || !_publishing.add(id)) return null;
    state = {
      ...state,
      id: PostLikes(count: before.count + 1, likedByMe: true),
    };
    try {
      await ref.read(postServiceProvider).like(post);
      return null;
    } on Object catch (e) {
      state = {...state, id: before};
      return e is PostPublishException
          ? e.message
          : const PostPublishException().message;
    } finally {
      _publishing.remove(id);
    }
  }
}

final postLikesProvider =
    NotifierProvider.autoDispose<PostLikesController, Map<String, PostLikes>>(
  PostLikesController.new,
);
