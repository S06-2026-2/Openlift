// FE-05 — WorkoutPublisher: monta, assina e envia 33401 + 1301 e avisa o
// backend (RF-20, RF-25, RN-01, RN-08). RNF-01: a chave privada não aparece
// em nada que sai do aparelho.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openlift/core/nostr/nostr_kinds.dart';
import 'package:openlift/core/storage/secure_storage_service.dart';
import 'package:openlift/features/auth/data/nostr_identity_service.dart';
import 'package:openlift/features/social/data/nostr_relay_service.dart';
import 'package:openlift/features/social/data/workout_publisher.dart';
import 'package:openlift/features/social/domain/workout_event_adapter.dart';
import 'package:openlift/features/workouts/domain/exercise_model.dart';
import 'package:openlift/features/workouts/domain/set_model.dart';
import 'package:openlift/features/workouts/domain/workout_model.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_nostr_relay_service.dart';
import '../../helpers/fake_workout_repository.dart';

final RegExp _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

WorkoutModel _workout({String? dTag, List<SetModel>? sets}) => WorkoutModel(
      id: 7,
      date: DateTime(2026, 10, 13),
      sets: sets ??
          const [
            SetModel(exerciseId: 1, reps: 8, weightKg: 80, rpe: 8),
            SetModel(exerciseId: 1, reps: 8, weightKg: 80),
            SetModel(exerciseId: 3, reps: 10, weightKg: 60),
          ],
      dTag: dTag,
      visibility: dTag == null
          ? WorkoutVisibility.private
          : WorkoutVisibility.published,
      publishStatus:
          dTag == null ? PublishStatus.local : PublishStatus.published,
    );

void main() {
  late FakeAuthRepository auth;
  late MemorySecureStorage storage;
  late FakeWorkoutRepository workouts;
  late FakeNostrRelayService relays;
  late WorkoutPublisher publisher;
  final library = {supino.id: supino, remada.id: remada};

  setUp(() {
    auth = FakeAuthRepository(session: true)..userId = 5;
    storage = MemorySecureStorage();
    workouts = FakeWorkoutRepository(workouts: [_workout()]);
    relays = FakeNostrRelayService();
    publisher = WorkoutPublisher(
      auth: auth,
      identity: NostrIdentityService(storage: storage),
      storage: storage,
      workouts: workouts,
      relays: relays,
      clock: () => DateTime.utc(2026, 10, 28, 12),
    );
  });

  test('envia um 33401 por exercício e o 1301 por último, assinados', () async {
    final outcome = await publisher.publish(_workout(), library);

    final events = relays.sent.single;
    expect(events.map((e) => e.kind), [
      NostrKinds.exerciseTemplate,
      NostrKinds.exerciseTemplate,
      NostrKinds.workoutRecord,
    ]);
    expect(events.every((e) => e.isValid), isTrue);
    expect(events.map((e) => e.createdAt).toSet(), {1793188800});
    // Equipamento da biblioteca na tag do modelo (mini-NIP §3).
    expect(events.first.firstTagValue('title'), 'Supino reto');
    expect(events.first.firstTagValue('equipment'), 'barbell');
    // O 1301 referencia os modelos pelo relay indicado (o 1º da lista).
    final exerciseTag = events.last.tags.firstWhere((t) => t[0] == 'exercise');
    expect(exerciseTag[2], relays.relays.first);

    expect(outcome.published, isTrue);
    expect(outcome.acceptedCount, 3);
    expect(outcome.workout.publishStatus, PublishStatus.published);
    expect(outcome.workout.isPublished, isTrue);
  });

  test('avisa o backend com event_id, pubkey e d do 1301', () async {
    await publisher.publish(_workout(), library);

    final record = relays.sent.single.last;
    final (id, body) = workouts.publications.single;
    expect(id, 7);
    expect(body['event_id'], record.id);
    expect(body['pubkey'], record.pubkey);
    expect(body['d_tag'], record.firstTagValue('d'));
    expect(body['d_tag'], matches(_uuidV4));
    expect(workouts.publicationFailures, isEmpty);
  });

  test('a pubkey é a da identidade da conta e o npub vai ao backend', () async {
    expect(auth.registeredNpub, isNull);

    await publisher.publish(_workout(), library);

    final identity =
        await NostrIdentityService(storage: storage).ensureIdentity(5);
    expect(relays.sent.single.last.pubkey, identity.publicKeyHex);
    expect(auth.registeredNpub, identity.npub);
  });

  test('basta um relay aceitar para o treino ficar publicado', () async {
    relays.outcomes
      ..['wss://relay.um.test'] = RelayOutcome.timeout
      ..['wss://relay.dois.test'] = RelayOutcome.rejected;

    final outcome = await publisher.publish(_workout(), library);

    expect(outcome.acceptedCount, 1);
    expect(outcome.workout.publishStatus, PublishStatus.published);
  });

  test('nenhum relay aceitou: avisa a falha e a nova tentativa usa o mesmo d',
      () async {
    for (final url in relays.relays) {
      relays.outcomes[url] = RelayOutcome.unreachable;
    }

    final failed = await publisher.publish(_workout(), library);

    expect(failed.published, isFalse);
    expect(failed.workout.publishStatus, PublishStatus.failed);
    expect(workouts.publications, isEmpty);
    final (_, failure) = workouts.publicationFailures.single;
    expect(failure.keys, unorderedEquals(['event_id', 'pubkey']));
    expect(failure['event_id'], relays.sent.single.last.id);

    relays.outcomes.clear();
    await publisher.publish(failed.workout, library);

    final firstD = relays.sent.first.last.firstTagValue('d');
    expect(relays.sent.last.last.firstTagValue('d'), firstD);
    expect(workouts.publications.single.$2['d_tag'], firstD);
  });

  test('republicar treino editado: evento novo com o mesmo d (RN-08)',
      () async {
    const d = '7c9e6679-7425-4f1b-9a2e-6a1f0c8d5b34';
    workouts.workouts[0] = _workout(dTag: d);

    await publisher.publish(_workout(dTag: d), library);

    expect(relays.sent.single.last.firstTagValue('d'), d);
    expect(workouts.publications.single.$2['d_tag'], d);
  });

  test('treino sem série não publica (RN-01)', () async {
    expect(
      () => publisher.publish(_workout(sets: const []), library),
      throwsA(isA<WorkoutEventException>()),
    );
    expect(relays.sent, isEmpty);
    expect(workouts.publications, isEmpty);
  });

  test('exercício sem equipamento não publica nada', () async {
    const semEquipamento =
        ExerciseModel(id: 3, name: 'Remada curvada', muscleGroup: 'Costas');

    await expectLater(
      publisher.publish(_workout(), {1: supino, 3: semEquipamento}),
      throwsA(isA<WorkoutEventException>()),
    );
    expect(relays.sent, isEmpty);
    expect(workouts.publications, isEmpty);
  });

  test('consentimento é por conta e fica guardado (RNF-12)', () async {
    expect(await publisher.hasConsent(), isFalse);

    await publisher.saveConsent();

    expect(await publisher.hasConsent(), isTrue);
    expect(storage.values[SecureStorageService.publishConsentKey(5)], 'true');
    auth.userId = 6;
    expect(await publisher.hasConsent(), isFalse);
  });

  test('RNF-01: a chave privada não sai do aparelho', () async {
    await publisher.publish(_workout(), library);
    for (final url in relays.relays) {
      relays.outcomes[url] = RelayOutcome.rejected;
    }
    await publisher.publish(_workout(), library);

    final secret = storage.values[SecureStorageService.nostrSecretKey(5)]!;
    final outgoing = [
      for (final events in relays.sent)
        for (final event in events) jsonEncode(event.toJson()),
      for (final (_, body) in workouts.publications) jsonEncode(body),
      for (final (_, body) in workouts.publicationFailures) jsonEncode(body),
      ...auth.identityCalls,
    ].join('\n');
    expect(outgoing, isNot(contains(secret)));
  });
}
