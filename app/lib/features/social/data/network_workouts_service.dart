// FE-06 — Treinos lidos dos relays NOSTR (RF-24, RF-51, RNF-02).
//
// Pede aos relays os treinos (kind 1301) e os modelos de exercício (kind
// 33401) dos autores: a identidade deste aparelho primeiro, depois quem a
// pessoa adicionou. Todo evento tem `id` e assinatura verificados antes de
// virar treino; o inválido é descartado e contado, nunca "consertado".

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nostr/nostr_event.dart';
import '../../../core/nostr/nostr_kinds.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/nostr_identity_service.dart';
import '../domain/published_workout.dart';
import '../domain/workout_event_adapter.dart';
import 'nostr_relay_service.dart';

/// Nenhum relay respondeu. A [message] é para o usuário.
class RelaysUnavailableException implements Exception {
  const RelaysUnavailableException();

  String get message => 'Não foi possível conectar aos relays NOSTR. '
      'Verifique sua conexão e tente novamente.';

  @override
  String toString() => message;
}

class NetworkFeed {
  const NetworkFeed({
    required this.workouts,
    required this.relays,
    required this.discarded,
  });

  /// Versão mais nova de cada treino, mais recentes primeiro.
  final List<PublishedWorkout> workouts;
  final List<RelayReadResult> relays;

  /// Eventos recusados por `id` ou assinatura inválidos (RF-51).
  final int discarded;
}

class NetworkWorkoutsService {
  NetworkWorkoutsService({
    required AuthRepository auth,
    required NostrIdentityService identity,
    required NostrRelayService relays,
  })  : _auth = auth,
        _identity = identity,
        _relays = relays;

  static const int _limit = 200;

  final AuthRepository _auth;
  final NostrIdentityService _identity;
  final NostrRelayService _relays;

  /// Identidade pública da conta neste aparelho (a mesma que publica).
  Future<NostrIdentity> ownIdentity() async {
    final me = await _auth.fetchMe();
    return _identity.ensureIdentity(me.id);
  }

  /// Lança [RelaysUnavailableException] se nenhum relay respondeu.
  Future<NetworkFeed> load(List<String> authors) async {
    if (authors.isEmpty) {
      return const NetworkFeed(workouts: [], relays: [], discarded: 0);
    }
    final result = await _relays.query([
      {
        'kinds': [NostrKinds.workoutRecord],
        'authors': authors,
        'limit': _limit,
      },
      {
        'kinds': [NostrKinds.exerciseTemplate],
        'authors': authors,
        'limit': _limit,
      },
    ]);
    if (!result.anyRelayResponded) throw const RelaysUnavailableException();

    // Relay pode mandar evento de quem não foi pedido: fica de fora.
    final wanted = authors.toSet();
    final valid = <NostrEvent>[];
    var discarded = 0;
    for (final event in result.events) {
      if (!wanted.contains(event.pubkey)) continue;
      if (event.isValid) {
        valid.add(event);
      } else {
        discarded++;
      }
    }

    final titles = WorkoutEventAdapter.exerciseTitles(
      valid.where((e) => e.kind == NostrKinds.exerciseTemplate),
    );
    return NetworkFeed(
      workouts: WorkoutEventAdapter.latestVersions(
        valid.where((e) => e.kind == NostrKinds.workoutRecord),
        exerciseTitles: titles,
      ),
      relays: result.relays,
      discarded: discarded,
    );
  }
}

final networkWorkoutsServiceProvider = Provider<NetworkWorkoutsService>(
  (ref) => NetworkWorkoutsService(
    auth: ref.watch(authRepositoryProvider),
    identity: ref.watch(nostrIdentityServiceProvider),
    relays: ref.watch(nostrRelayServiceProvider),
  ),
);
