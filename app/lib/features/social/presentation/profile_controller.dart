// Estado do perfil da rede social (ADR-0012).
//
// - [myProfileProvider]: o próprio perfil, ou `null` enquanto a pessoa não
//   escolheu um nome de usuário (a aba Social abre o cadastro);
// - [authorProfilesProvider]: nome e foto de quem aparece no feed, por
//   chave pública, buscados em lote na API;
// - [profileByUsernameProvider] e [peopleSearchProvider]: página de perfil e
//   busca por nome de usuário.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/profile_repository.dart';
import '../data/profile_service.dart';
import '../domain/profile_model.dart';

class MyProfileController extends AutoDisposeAsyncNotifier<SocialProfile?> {
  @override
  Future<SocialProfile?> build() =>
      ref.watch(profileRepositoryProvider).fetchMine();

  /// Salva o perfil. Devolve um aviso para a tela, ou `null` se deu tudo
  /// certo. Lança [ApiException] se a API recusou (o perfil não mudou).
  Future<String?> save(ProfileInput input) async {
    final result = await ref.read(profileServiceProvider).save(input);
    state = AsyncData(result.profile);
    ref.invalidate(authorProfilesProvider);
    return result.published
        ? null
        : 'Perfil salvo. Não deu para publicar na rede agora; '
            'ele será publicado na próxima edição.';
  }
}

final myProfileProvider =
    AsyncNotifierProvider.autoDispose<MyProfileController, SocialProfile?>(
  MyProfileController.new,
);

/// Perfis já conhecidos por chave pública (hex). Quem não tem perfil fica
/// fora do mapa e aparece pelo ID encurtado.
class AuthorProfilesController
    extends AutoDisposeNotifier<Map<String, SocialProfile>> {
  final Set<String> _requested = {};

  @override
  Map<String, SocialProfile> build() {
    _requested.clear();
    return const {};
  }

  /// Busca os perfis de [pubkeys] que ainda não foram pedidos. Falha deixa
  /// o feed como está: o nome é enfeite, o treino é o conteúdo.
  Future<void> load(Iterable<String> pubkeys) async {
    final missing = [
      for (final pubkey in pubkeys.toSet())
        if (_requested.add(pubkey)) pubkey,
    ];
    if (missing.isEmpty) return;
    try {
      final found =
          await ref.read(profileRepositoryProvider).byPubkeys(missing);
      state = {
        ...state,
        for (final profile in found) profile.pubkey: profile,
      };
    } on Object {
      _requested.removeAll(missing);
    }
  }
}

final authorProfilesProvider = NotifierProvider.autoDispose<
    AuthorProfilesController, Map<String, SocialProfile>>(
  AuthorProfilesController.new,
);

final profileByUsernameProvider =
    FutureProvider.autoDispose.family<SocialProfile, String>(
  (ref, username) => ref.watch(profileRepositoryProvider).byUsername(username),
);

final peopleSearchProvider =
    FutureProvider.autoDispose.family<List<SocialProfile>, String>(
  (ref, query) async {
    if (query.trim().isEmpty) return const [];
    return ref.watch(profileRepositoryProvider).search(query);
  },
);

/// Mensagem de erro para a tela a partir de qualquer falha.
String profileErrorMessage(Object error) => error is ApiException
    ? error.message
    : 'Não foi possível falar com o servidor. Tente novamente.';
