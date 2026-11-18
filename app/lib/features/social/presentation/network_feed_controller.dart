// FE-06 / NOSTR-04 — Estado da aba "Da rede": quem ler e o que os relays
// devolveram.
//
// - [followingProvider]: quem a pessoa segue, lido do kind 3 nos relays
//   (NOSTR-04). Seguir e deixar de seguir publicam a lista inteira;
// - [ownIdentityProvider]: a identidade pública deste aparelho;
// - [networkFeedProvider]: treinos da própria identidade primeiro, depois os
//   de quem ela segue.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nostr/nip19.dart';
import '../../auth/data/nostr_identity_service.dart';
import '../data/follow_service.dart';
import '../data/network_workouts_service.dart';
import '../domain/contact_list.dart';

class FollowingController extends AutoDisposeAsyncNotifier<ContactList> {
  bool _busy = false;

  @override
  Future<ContactList> build() => ref.watch(followServiceProvider).load();

  /// Segue o dono de [raw] (`npub`). Devolve a mensagem de erro para a tela,
  /// ou `null`. Se a publicação falhar, a lista continua como estava.
  Future<String?> follow(String raw) async {
    final String pubkey;
    try {
      pubkey = Nip19.decodeNpub(raw.trim().toLowerCase());
    } on Object {
      return 'Isso não é um npub válido.';
    }
    final own = await ref.read(ownIdentityProvider.future);
    if (pubkey == own.publicKeyHex) {
      return 'Esse é o seu npub. Não dá para seguir a si mesmo.';
    }
    final current = state.valueOrNull;
    if (current == null) return _notLoaded;
    if (current.contains(pubkey)) return 'Você já segue essa pessoa.';
    return _publish(current.follow(pubkey));
  }

  /// Deixa de seguir [pubkey] (hex). Devolve a mensagem de erro, ou `null`.
  Future<String?> unfollow(String pubkey) async {
    final current = state.valueOrNull;
    if (current == null) return _notLoaded;
    if (!current.contains(pubkey)) return null;
    return _publish(current.unfollow(pubkey));
  }

  // Sem a lista atual, publicar uma nova apagaria quem já era seguido.
  static const String _notLoaded =
      'Ainda não deu para ler quem você segue. Tente novamente.';

  Future<String?> _publish(ContactList next) async {
    if (_busy) return null; // toque duplo: a primeira publicação já vale.
    _busy = true;
    try {
      final published = await ref.read(followServiceProvider).publish(next);
      state = AsyncData(published);
      return null;
    } on FollowPublishException catch (e) {
      return e.message;
    } on Object {
      return const FollowPublishException().message;
    } finally {
      _busy = false;
    }
  }
}

/// autoDispose: sai da tela, some; outra conta no mesmo aparelho não herda.
final followingProvider =
    AsyncNotifierProvider.autoDispose<FollowingController, ContactList>(
  FollowingController.new,
);

final ownIdentityProvider = FutureProvider.autoDispose<NostrIdentity>(
  (ref) => ref.watch(networkWorkoutsServiceProvider).ownIdentity(),
);

final networkFeedProvider =
    FutureProvider.autoDispose<NetworkFeed>((ref) async {
  final service = ref.watch(networkWorkoutsServiceProvider);
  final own = await ref.watch(ownIdentityProvider.future);
  final following = await ref.watch(followingProvider.future);
  final authors = {own.publicKeyHex, ...following.pubkeys}.toList();
  return service.load(authors);
});
