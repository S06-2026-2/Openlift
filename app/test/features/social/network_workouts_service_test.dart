// FE-06 — NetworkWorkoutsService: treinos lidos dos relays com assinatura
// verificada (RF-51, RNF-02), um por `id` (RF-24) e só a versão mais nova de
// cada `d` (RN-08).

import 'package:flutter_test/flutter_test.dart';
import 'package:openlift/core/nostr/nostr_event.dart';
import 'package:openlift/core/nostr/nostr_kinds.dart';
import 'package:openlift/core/nostr/nostr_signer.dart';
import 'package:openlift/features/auth/data/nostr_identity_service.dart';
import 'package:openlift/features/social/data/network_workouts_service.dart';
import 'package:openlift/features/social/data/nostr_relay_service.dart';
import 'package:openlift/features/social/domain/workout_event_adapter.dart';
import 'package:openlift/features/workouts/domain/set_model.dart';
import 'package:openlift/features/workouts/domain/workout_model.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_nostr_relay_service.dart';
import '../../helpers/fake_workout_repository.dart';

const _adapter = WorkoutEventAdapter(relayHint: 'wss://relay.um.test');

/// 33401 do supino + 1301 com [reps] repetições, assinados por [signer].
List<NostrEvent> _published(
  NostrSigner signer, {
  required String d,
  required int createdAt,
  int reps = 8,
}) {
  final workout = WorkoutModel(
    id: 1,
    date: DateTime(2026, 10, 13),
    sets: [SetModel(exerciseId: 1, reps: reps, weightKg: 80)],
  );
  return [
    signer.sign(_adapter.exerciseTemplate(
      pubkey: signer.publicKey,
      createdAt: createdAt,
      exercise: supino,
      equipment: ExerciseEquipment.barbell,
    )),
    signer.sign(_adapter.workoutRecord(
      pubkey: signer.publicKey,
      createdAt: createdAt,
      d: d,
      workout: workout,
      exercises: const {1: supino},
    )),
  ];
}

/// Mesmo `id` e `sig`, conteúdo trocado: a assinatura não confere mais.
NostrEvent _tampered(NostrEvent event) => NostrEvent(
      id: event.id,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      kind: event.kind,
      tags: [
        for (final tag in event.tags)
          tag[0] == 'exercise' ? [...tag.take(3), '999', ...tag.skip(4)] : tag,
      ],
      content: event.content,
      sig: event.sig,
    );

void main() {
  late FakeNostrRelayService relays;
  late NetworkWorkoutsService service;
  late MemorySecureStorage storage;
  final alice = NostrSigner.generate();
  final bob = NostrSigner.generate();
  const d1 = '11111111-1111-4111-8111-111111111111';
  const d2 = '22222222-2222-4222-8222-222222222222';

  setUp(() {
    relays = FakeNostrRelayService();
    storage = MemorySecureStorage();
    service = NetworkWorkoutsService(
      auth: FakeAuthRepository(session: true),
      identity: NostrIdentityService(storage: storage),
      relays: relays,
    );
  });

  void store(String url, List<NostrEvent> events) =>
      relays.stored.putIfAbsent(url, () => []).addAll(events);

  test('pede 1301 e 33401 dos autores e lê o treino com o nome do exercício',
      () async {
    store('wss://relay.um.test', _published(alice, d: d1, createdAt: 100));

    final feed = await service.load([alice.publicKey]);

    expect(relays.queries.single, [
      {
        'kinds': [NostrKinds.workoutRecord],
        'authors': [alice.publicKey],
        'limit': 200,
      },
      {
        'kinds': [NostrKinds.exerciseTemplate],
        'authors': [alice.publicKey],
        'limit': 200,
      },
    ]);
    final workout = feed.workouts.single;
    expect(workout.pubkey, alice.publicKey);
    expect(workout.exerciseNames, ['Supino reto']);
    expect(workout.volumeKg, 640);
    expect(feed.discarded, 0);
  });

  test('evento com assinatura inválida é descartado e contado (RNF-02)',
      () async {
    final events = _published(alice, d: d1, createdAt: 100);
    store('wss://relay.um.test', [events.first, _tampered(events.last)]);

    final feed = await service.load([alice.publicKey]);

    expect(feed.workouts, isEmpty);
    expect(feed.discarded, 1);
  });

  test('o mesmo evento em vários relays aparece uma vez (RF-24)', () async {
    final events = _published(alice, d: d1, createdAt: 100);
    for (final url in relays.relays) {
      store(url, events);
    }

    final feed = await service.load([alice.publicKey]);

    expect(feed.workouts, hasLength(1));
  });

  test('treino republicado: só a versão mais nova do mesmo d (RN-08)',
      () async {
    store('wss://relay.um.test', [
      ..._published(alice, d: d1, createdAt: 100, reps: 8),
      ..._published(alice, d: d1, createdAt: 200, reps: 10),
      ..._published(alice, d: d2, createdAt: 150),
    ]);

    final feed = await service.load([alice.publicKey]);

    expect(feed.workouts.map((w) => w.d), [d1, d2]);
    expect(feed.workouts.first.sets.single.reps, 10);
  });

  test('vários autores; evento de quem não foi pedido fica de fora', () async {
    final intruder = NostrSigner.generate();
    store('wss://relay.um.test', [
      ..._published(alice, d: d1, createdAt: 100),
      ..._published(bob, d: d2, createdAt: 200),
    ]);
    // Um relay que ignora o filtro e manda evento de outra pessoa.
    relays.stored['wss://relay.dois.test'] =
        _published(intruder, d: d1, createdAt: 300);
    relays.ignoringFilters.add('wss://relay.dois.test');

    final feed = await service.load([alice.publicKey, bob.publicKey]);

    expect(
        feed.workouts.map((w) => w.pubkey), [bob.publicKey, alice.publicKey]);
  });

  test('nenhum relay respondeu: erro humano, não lista vazia', () async {
    for (final url in relays.relays) {
      relays.readStatus[url] = RelayReadStatus.unreachable;
    }

    expect(
      () => service.load([alice.publicKey]),
      throwsA(isA<RelaysUnavailableException>()),
    );
  });

  test('um relay fora do ar não impede ler dos outros', () async {
    relays.readStatus['wss://relay.um.test'] = RelayReadStatus.unreachable;
    store('wss://relay.dois.test', _published(alice, d: d1, createdAt: 100));

    final feed = await service.load([alice.publicKey]);

    expect(feed.workouts, hasLength(1));
    expect(feed.relays.where((r) => r.responded), hasLength(2));
  });

  test('ownIdentity é a mesma identidade que publica', () async {
    final own = await service.ownIdentity();
    final signer = await NostrIdentityService(storage: storage).signerFor(1);

    expect(own.publicKeyHex, signer.publicKey);
  });
}
