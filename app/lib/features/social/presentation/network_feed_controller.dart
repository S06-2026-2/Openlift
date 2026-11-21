// FE-06 / NOSTR-04 — Estado da aba "Da rede": quem ler e o que os relays
// devolveram.
//
// - [followingProvider]: quem a pessoa segue, lido do kind 3 nos relays
//   (NOSTR-04). Seguir e deixar de seguir publicam a lista inteira;
// - [ownIdentityProvider]: a identidade pública deste aparelho (o "ID");
// - [personWorkoutsProvider]: treinos de quem foi buscado pelo ID;
// - [networkFeedProvider]: treinos da própria identidade primeiro, depois os
//   de quem ela segue.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nostr/nip19.dart';
import '../../auth/data/nostr_identity_service.dart';
import '../data/follow_service.dart';
import '../data/network_workouts_service.dart';
import '../domain/contact_list.dart';

/// ID digitado que não dá para usar. [message] vai direto para a tela.
class IdInputException implements Exception {
  const IdInputException(this.message);

  final String message;

  static const String invalid =
      'Esse ID não é válido. Confira se colou ele inteiro.';
  static const String ownId = 'Esse é o seu ID. Não dá para seguir a si mesmo.';
}

/// O "ID" que o app mostra é o `npub` (NIP-19): identificador público da
/// pessoa na rede. Devolve a chave pública em hex.
String parseIdInput(String raw) {
  try {
    return Nip19.decodeNpub(raw.trim().toLowerCase());
  } on Object {
    throw const IdInputException(IdInputException.invalid);
  }
}

class FollowingController extends AutoDisposeAsyncNotifier<ContactList> {
  bool _busy = false;

  @override
  Future<ContactList> build() => ref.watch(followServiceProvider).load();

  /// Segue o dono de [raw] (o ID, um `npub`). Devolve a mensagem de erro
  /// para a tela, ou `null`. Se a publicação falhar, a lista continua como
  /// estava.
  Future<String?> follow(String raw) async {
    final String pubkey;
    try {
      pubkey = parseIdInput(raw);
    } on IdInputException catch (e) {
      return e.message;
    }
    final own = await ref.read(ownIdentityProvider.future);
    if (pubkey == own.publicKeyHex) return IdInputException.ownId;
    return followPubkey(pubkey);
  }

  /// Segue [pubkey] (hex, já validado). Devolve a mensagem de erro, ou `null`.
  Future<String?> followPubkey(String pubkey) async {
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

/// Treinos publicados por uma pessoa buscada pelo ID (antes de seguir).
final personWorkoutsProvider =
    FutureProvider.autoDispose.family<NetworkFeed, String>(
  (ref, pubkey) =>
      ref.watch(networkWorkoutsServiceProvider).load([pubkey], limit: 50),
);

final networkFeedProvider =
    FutureProvider.autoDispose<NetworkFeed>((ref) async {
  final service = ref.watch(networkWorkoutsServiceProvider);
  final own = await ref.watch(ownIdentityProvider.future);
  final following = await ref.watch(followingProvider.future);
  final authors = {own.publicKeyHex, ...following.pubkeys}.toList();
  return service.load(authors);
});
