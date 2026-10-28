// FE-06 — Estado da aba "Da rede": quem ler e o que os relays devolveram.
//
// - [followedNpubsProvider]: identidades que a pessoa colou para ver os
//   treinos (só nesta sessão; seguir de verdade, kind 3, é da Sprint 3);
// - [ownIdentityProvider]: a identidade pública deste aparelho;
// - [networkFeedProvider]: treinos da própria identidade primeiro, depois os
//   das identidades adicionadas.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nostr/nip19.dart';
import '../../auth/data/nostr_identity_service.dart';
import '../data/network_workouts_service.dart';

class FollowedNpubsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  /// Adiciona um `npub`. Devolve a mensagem de erro para a tela, ou `null`.
  String? add(String raw) {
    final npub = raw.trim().toLowerCase();
    try {
      Nip19.decodeNpub(npub);
    } on Object {
      return 'Isso não é um npub válido.';
    }
    if (state.contains(npub)) return 'Essa pessoa já está na lista.';
    state = [...state, npub];
    return null;
  }

  void remove(String npub) => state = [
        for (final item in state)
          if (item != npub) item
      ];
}

final followedNpubsProvider =
    NotifierProvider<FollowedNpubsNotifier, List<String>>(
  FollowedNpubsNotifier.new,
);

/// autoDispose: sai da tela, some; outra conta no mesmo aparelho não herda.
final ownIdentityProvider = FutureProvider.autoDispose<NostrIdentity>(
  (ref) => ref.watch(networkWorkoutsServiceProvider).ownIdentity(),
);

final networkFeedProvider =
    FutureProvider.autoDispose<NetworkFeed>((ref) async {
  final service = ref.watch(networkWorkoutsServiceProvider);
  final followed = ref.watch(followedNpubsProvider);
  final own = await ref.watch(ownIdentityProvider.future);
  final authors = {
    own.publicKeyHex,
    for (final npub in followed) Nip19.decodeNpub(npub),
  }.toList();
  return service.load(authors);
});
