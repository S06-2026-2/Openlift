// FE-05 — Publica um treino no NOSTR (RF-20, RF-22, RF-25, RN-01, RN-08).
//
// 1. Garante a identidade da conta (a mesma do FE-04) e o `npub` no backend.
// 2. Monta os modelos de exercício (kind 33401) e o treino (kind 1301) pelo
//    WorkoutEventAdapter, e assina tudo no aparelho (ADR-0005).
// 3. Envia aos relays (ADR-0007) e avisa o backend do resultado:
//    algum relay aceitou → `/publication`; nenhum → `/publication-failure`.
//
// Republicar (após edição ou nova tentativa) reaproveita o `d` do treino, então
// os clientes NOSTR mostram só a versão mais nova (RN-08).
//
// RNF-01: para a API vão só `event_id`, `pubkey` (hex) e `d`. A chave privada
// fica no NostrSigner; nada aqui loga ou imprime.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_storage_service.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/nostr_identity_service.dart';
import '../../workouts/data/workout_repository.dart';
import '../../workouts/domain/exercise_model.dart';
import '../../workouts/domain/workout_model.dart';
import '../domain/workout_event_adapter.dart';
import 'nostr_relay_service.dart';

class PublishOutcome {
  const PublishOutcome({required this.workout, required this.relays});

  /// O treino como o backend registrou (status, `d`).
  final WorkoutModel workout;
  final List<RelayPublishResult> relays;

  int get acceptedCount => relays.where((r) => r.accepted).length;

  bool get published => acceptedCount > 0;
}

class WorkoutPublisher {
  WorkoutPublisher({
    required AuthRepository auth,
    required NostrIdentityService identity,
    required SecureStorageService storage,
    required WorkoutRepository workouts,
    required NostrRelayService relays,
    DateTime Function()? clock,
  })  : _auth = auth,
        _identity = identity,
        _storage = storage,
        _workouts = workouts,
        _relays = relays,
        _clock = clock ?? DateTime.now;

  final AuthRepository _auth;
  final NostrIdentityService _identity;
  final SecureStorageService _storage;
  final WorkoutRepository _workouts;
  final NostrRelayService _relays;
  final DateTime Function() _clock;

  /// `d` sorteado para treinos que ainda não têm um no backend. Se os relays
  /// aceitarem mas o aviso à API falhar, a nova tentativa usa o mesmo `d` e
  /// não cria um segundo treino nos relays.
  final Map<int, String> _pendingD = {};

  /// A conta já aceitou o aviso de publicação (RNF-12)?
  Future<bool> hasConsent() async {
    final me = await _auth.fetchMe();
    return _storage.hasPublishConsent(me.id);
  }

  Future<void> saveConsent() async {
    final me = await _auth.fetchMe();
    await _storage.savePublishConsent(me.id);
  }

  /// Lança [WorkoutEventException] quando o treino não pode virar evento e
  /// `ApiException` quando a API falha.
  Future<PublishOutcome> publish(
    WorkoutModel workout,
    Map<int, ExerciseModel> exercises,
  ) async {
    final id = workout.id;
    if (id == null) {
      throw const WorkoutEventException('Salve o treino antes de publicar.');
    }
    if (workout.sets.isEmpty) {
      throw const WorkoutEventException(
          'Registre pelo menos uma série antes de publicar.');
    }

    final me = await _auth.fetchMe();
    final signer = await _identity.signerFor(me.id);
    final identity = NostrIdentity.fromSigner(signer);
    if (me.npub != identity.npub) {
      await _auth.registerNostrIdentity(identity.npub);
    }

    final createdAt = _clock().millisecondsSinceEpoch ~/ 1000;
    final adapter = WorkoutEventAdapter(
      relayHint: _relays.relays.isEmpty ? '' : _relays.relays.first,
    );
    final d = workout.dTag ??
        _pendingD.putIfAbsent(id, WorkoutEventAdapter.newRecordD);

    // O 1301 primeiro: ele valida o treino antes de qualquer assinatura.
    final record = adapter.workoutRecord(
      pubkey: signer.publicKey,
      createdAt: createdAt,
      d: d,
      workout: workout,
      exercises: exercises,
    );
    final templates = [
      for (final exerciseId in workout.exerciseIds)
        adapter.exerciseTemplate(
          pubkey: signer.publicKey,
          createdAt: createdAt,
          exercise: exercises[exerciseId]!,
          equipment: _equipmentOf(exercises[exerciseId]!),
        ),
    ];

    final signed = [
      for (final event in [...templates, record]) signer.sign(event),
    ];
    final eventId = signed.last.id;
    final results = await _relays.publish(signed);

    final saved = results.any((r) => r.accepted)
        ? await _workouts.registerPublication(
            id,
            eventId: eventId,
            pubkey: signer.publicKey,
            dTag: d,
          )
        : await _workouts.registerPublicationFailure(
            id,
            eventId: eventId,
            pubkey: signer.publicKey,
          );
    if (saved.dTag != null) _pendingD.remove(id);
    return PublishOutcome(workout: saved, relays: results);
  }

  static ExerciseEquipment _equipmentOf(ExerciseModel exercise) {
    final equipment = ExerciseEquipment.values.asNameMap()[exercise.equipment];
    if (equipment == null) {
      throw WorkoutEventException(
          '"${exercise.name}" está sem equipamento na biblioteca. '
          'Atualize o servidor e tente de novo.');
    }
    return equipment;
  }
}

/// Reaproveitado entre telas: guarda o `d` pendente de cada treino.
final workoutPublisherProvider = Provider<WorkoutPublisher>(
  (ref) => WorkoutPublisher(
    auth: ref.watch(authRepositoryProvider),
    identity: ref.watch(nostrIdentityServiceProvider),
    storage: ref.watch(secureStorageServiceProvider),
    workouts: ref.watch(workoutRepositoryProvider),
    relays: ref.watch(nostrRelayServiceProvider),
  ),
);
