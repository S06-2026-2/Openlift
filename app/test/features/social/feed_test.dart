// FE-07 — Feed de quem a pessoa segue (RF-31): autores da contact list
// (NOSTR-04), treinos lidos dos relays com assinatura verificada, um por `id`,
// em ordem cronológica decrescente e paginados por `until`. FE-08: curtir
// pelo card, com contagem da API e atualização otimista.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlift/core/nostr/nip19.dart';
import 'package:openlift/core/nostr/nostr_event.dart';
import 'package:openlift/core/nostr/nostr_kinds.dart';
import 'package:openlift/core/nostr/nostr_signer.dart';
import 'package:openlift/core/storage/secure_storage_service.dart';
import 'package:openlift/features/auth/data/auth_repository.dart';
import 'package:openlift/features/auth/data/nostr_identity_service.dart';
import 'package:openlift/features/social/data/nostr_relay_service.dart';
import 'package:openlift/features/social/data/social_repository.dart';
import 'package:openlift/features/social/domain/contact_list.dart';
import 'package:openlift/features/social/domain/like_model.dart';
import 'package:openlift/features/social/domain/workout_event_adapter.dart';
import 'package:openlift/features/social/presentation/feed_controller.dart';
import 'package:openlift/features/social/presentation/widgets/feed_workout_card.dart';
import 'package:openlift/features/workouts/data/workout_repository.dart';
import 'package:openlift/features/workouts/domain/set_model.dart';
import 'package:openlift/features/workouts/domain/workout_model.dart';
import 'package:openlift/main.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_nostr_relay_service.dart';
import '../../helpers/fake_social_repository.dart';
import '../../helpers/fake_workout_repository.dart';

const _adapter = WorkoutEventAdapter(relayHint: 'wss://relay.um.test');
const _userId = 1;

final _ana = NostrSigner.generate();
final _bia = NostrSigner.generate();

/// Modelo do supino (33401) de [author], para o feed achar o nome.
NostrEvent _template(NostrSigner author) => author.sign(
      _adapter.exerciseTemplate(
        pubkey: author.publicKey,
        createdAt: 1,
        exercise: supino,
        equipment: ExerciseEquipment.barbell,
      ),
    );

/// Treino (1301) de [author] no dia [day] de outubro, publicado em
/// [createdAt]: 2 séries normais de 80 kg × [reps] e 1 aquecimento.
NostrEvent _record(
  NostrSigner author, {
  required int createdAt,
  int day = 13,
  int reps = 8,
  String? d,
}) =>
    author.sign(
      _adapter.workoutRecord(
        pubkey: author.publicKey,
        createdAt: createdAt,
        d: d ?? WorkoutEventAdapter.newRecordD(),
        workout: WorkoutModel(
          id: 1,
          date: DateTime(2026, 10, day),
          sets: [
            const SetModel(
              exerciseId: 1,
              reps: 10,
              weightKg: 40,
              type: SetType.warmup,
            ),
            SetModel(exerciseId: 1, reps: reps, weightKg: 80),
            SetModel(exerciseId: 1, reps: reps, weightKg: 80),
          ],
        ),
        exercises: const {1: supino},
      ),
    );

String _short(String pubkey) {
  final npub = Nip19.encodeNpub(pubkey);
  return '${npub.substring(0, 12)}…${npub.substring(npub.length - 6)}';
}

class _Setup {
  _Setup() : relays = FakeNostrRelayService();

  final FakeNostrRelayService relays;
  final MemorySecureStorage storage = MemorySecureStorage();
  final FakeAuthRepository auth = FakeAuthRepository(session: true)
    ..userId = _userId;
  final FakeSocialRepository social = FakeSocialRepository();

  /// Guarda [events] em todos os relays.
  void store(List<NostrEvent> events) {
    for (final url in relays.relays) {
      relays.stored.putIfAbsent(url, () => []).addAll(events);
    }
  }

  /// Publica a contact list deste aparelho seguindo [people].
  Future<void> follow(List<NostrSigner> people) async {
    final signer =
        await NostrIdentityService(storage: storage).signerFor(_userId);
    var list = const ContactList();
    for (final person in people) {
      list = list.follow(person.publicKey);
    }
    store([
      signer.sign(list.toUnsignedEvent(pubkey: signer.publicKey, now: 10)),
    ]);
  }

  List<Override> get overrides => [
        authRepositoryProvider.overrideWithValue(auth),
        workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
        secureStorageServiceProvider.overrideWithValue(storage),
        nostrRelayServiceProvider.overrideWithValue(relays),
        socialRepositoryProvider.overrideWithValue(social),
      ];

  Future<void> openFeed(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(overrides: overrides, child: const OpenLiftApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Social'));
    await tester.pumpAndSettle();
  }

  ProviderContainer container() {
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    return container;
  }
}

void main() {
  group('tela', () {
    testWidgets('sem seguir ninguém: estado vazio com chamada para seguir',
        (tester) async {
      final setup = _Setup();
      await setup.openFeed(tester);

      expect(find.text('Você ainda não segue ninguém'), findsOneWidget);
      expect(find.text('Seguir alguém'), findsOneWidget);
      // Sem contact list, nenhum treino é pedido aos relays.
      expect(
        setup.relays.queries.expand((q) => q).any(
            (f) => (f['kinds'] as List).contains(NostrKinds.workoutRecord)),
        isFalse,
      );
    });

    testWidgets('card mostra autor, data, exercícios e volume sem aquecimento',
        (tester) async {
      final setup = _Setup();
      await setup.follow([_ana]);
      setup.store([_template(_ana), _record(_ana, createdAt: 100)]);
      await setup.openFeed(tester);

      expect(find.byType(FeedWorkoutCard), findsOneWidget);
      expect(find.text(_short(_ana.publicKey)), findsOneWidget);
      expect(find.text('13/10/2026'), findsOneWidget);
      expect(find.text('Supino reto'), findsOneWidget);
      // 2 × 80 × 8 = 1.280 kg; o aquecimento (40 × 10) fica fora (RN-03).
      expect(find.text('3 séries · 1.280 kg'), findsOneWidget);
    });

    testWidgets('mais novos primeiro, de várias pessoas seguidas',
        (tester) async {
      final setup = _Setup();
      await setup.follow([_ana, _bia]);
      setup.store([
        _template(_ana),
        _template(_bia),
        _record(_ana, createdAt: 100, day: 10),
        _record(_bia, createdAt: 300, day: 12),
        _record(_ana, createdAt: 200, day: 11),
      ]);
      await setup.openFeed(tester);

      final dates = ['12/10/2026', '11/10/2026', '10/10/2026'];
      final tops = [for (final d in dates) tester.getTopLeft(find.text(d)).dy];
      expect(tops[0], lessThan(tops[1]));
      expect(tops[1], lessThan(tops[2]));
    });

    testWidgets('evento repetido em vários relays aparece uma vez só',
        (tester) async {
      final setup = _Setup();
      await setup.follow([_ana]);
      // store() guarda o mesmo evento nos 3 relays.
      setup.store([_template(_ana), _record(_ana, createdAt: 100)]);
      await setup.openFeed(tester);

      expect(find.byType(FeedWorkoutCard), findsOneWidget);
    });

    testWidgets('evento adulterado não aparece e é contado', (tester) async {
      final setup = _Setup();
      await setup.follow([_ana]);
      final real = _record(_ana, createdAt: 100);
      final tampered = NostrEvent(
        id: real.id,
        pubkey: real.pubkey,
        createdAt: real.createdAt,
        kind: real.kind,
        tags: [
          for (final tag in real.tags)
            tag[0] == 'exercise'
                ? [...tag.take(4), '100', ...tag.skip(5)]
                : tag,
        ],
        content: real.content,
        sig: real.sig,
      );
      setup.store([_template(_ana), tampered]);
      await setup.openFeed(tester);

      expect(find.byType(FeedWorkoutCard), findsNothing);
      expect(find.text('1 evento descartado (assinatura inválida)'),
          findsOneWidget);
    });

    testWidgets('quem é seguido ainda não publicou: aviso, não lista vazia',
        (tester) async {
      final setup = _Setup();
      await setup.follow([_ana]);
      await setup.openFeed(tester);

      expect(
        find.text('Quem você segue ainda não publicou nenhum treino.'),
        findsOneWidget,
      );
    });

    testWidgets('nenhum relay responde: erro humano e "Tentar novamente"',
        (tester) async {
      final setup = _Setup();
      await setup.follow([_ana]);
      setup.store([_template(_ana), _record(_ana, createdAt: 100)]);
      for (final url in setup.relays.relays) {
        setup.relays.readStatus[url] = RelayReadStatus.unreachable;
      }
      await setup.openFeed(tester);

      expect(find.textContaining('conectar aos relays NOSTR'), findsOneWidget);

      setup.relays.readStatus.clear();
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();

      expect(find.byType(FeedWorkoutCard), findsOneWidget);
    });

    testWidgets('RNF-05: 200 eventos renderizam em menos de 2 s',
        (tester) async {
      final setup = _Setup();
      await setup.follow([_ana]);
      setup.store([
        _template(_ana),
        for (var i = 0; i < 200; i++) _record(_ana, createdAt: 1000 + i),
      ]);
      final container = setup.container();
      await container.read(feedProvider.future);
      // A 1ª página traz [FeedController.pageSize]; as outras, por "Carregar
      // mais". Para medir a renderização dos 200, carrega tudo antes.
      while (container.read(feedProvider).requireValue.hasMore) {
        await container.read(feedProvider.notifier).loadMore();
      }
      final workouts = container.read(feedProvider).requireValue.workouts;
      expect(workouts, hasLength(200));

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final stopwatch = Stopwatch()..start();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            itemCount: workouts.length,
            itemBuilder: (_, i) => FeedWorkoutCard(workout: workouts[i]),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      // Rolar até o fim força a construção de todos os cards.
      await tester.fling(find.byType(ListView), const Offset(0, -100000), 5000);
      await tester.pumpAndSettle();
      stopwatch.stop();

      // ignore: avoid_print
      print('RNF-05: 200 eventos renderizados em '
          '${stopwatch.elapsedMilliseconds} ms');
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
    });
  });

  group('controller', () {
    test('a 1ª página traz os mais novos e "loadMore" pede os anteriores',
        () async {
      final setup = _Setup();
      await setup.follow([_ana]);
      const total = FeedController.pageSize + 5;
      setup.store([
        _template(_ana),
        for (var i = 0; i < total; i++) _record(_ana, createdAt: 1000 + i),
      ]);
      final container = setup.container();

      final first = await container.read(feedProvider.future);

      expect(first.workouts, hasLength(FeedController.pageSize));
      expect(first.workouts.first.createdAt, 1000 + total - 1);
      expect(first.hasMore, isTrue);

      await container.read(feedProvider.notifier).loadMore();
      final all = container.read(feedProvider).requireValue;

      expect(all.workouts, hasLength(total));
      expect(all.workouts.last.createdAt, 1000);
      expect(all.workouts.map((w) => w.eventId).toSet(), hasLength(total));
      expect(all.hasMore, isFalse);
      final untils = [
        for (final query in setup.relays.queries)
          for (final filter in query)
            if ((filter['kinds']! as List).contains(NostrKinds.workoutRecord))
              filter['until'],
      ];
      expect(untils, [null, first.nextUntil]);
    });

    test('versão antiga de um treino já exibido não volta na página seguinte',
        () async {
      final setup = _Setup();
      await setup.follow([_ana]);
      const d = '11111111-1111-4111-8111-111111111111';
      setup.store([
        _template(_ana),
        // Versão nova do treino `d` na 1ª página; a antiga, bem mais velha,
        // só chegaria na 2ª (RN-08).
        _record(_ana, createdAt: 5000, d: d, reps: 10),
        for (var i = 0; i < FeedController.pageSize; i++)
          _record(_ana, createdAt: 2000 + i),
        _record(_ana, createdAt: 100, d: d, reps: 5),
      ]);
      final container = setup.container();
      await container.read(feedProvider.future);

      await container.read(feedProvider.notifier).loadMore();
      final workouts = container.read(feedProvider).requireValue.workouts;

      expect(workouts.where((w) => w.d == d), hasLength(1));
      expect(workouts.firstWhere((w) => w.d == d).sets.last.reps, 10);
    });

    test('os próprios treinos não entram no feed de quem sigo', () async {
      final setup = _Setup();
      await setup.follow([_ana]);
      final me =
          await NostrIdentityService(storage: setup.storage).signerFor(_userId);
      setup.store([
        _template(_ana),
        _record(_ana, createdAt: 100),
        _template(me),
        _record(me, createdAt: 200),
      ]);
      final container = setup.container();

      final state = await container.read(feedProvider.future);

      expect(state.workouts.map((w) => w.pubkey), [_ana.publicKey]);
    });
  });

  group('curtir (FE-08)', () {
    Future<_Setup> feedWithOneWorkout(WidgetTester tester) async {
      final setup = _Setup();
      await setup.follow([_ana]);
      setup.store([_template(_ana), _record(_ana, createdAt: 100)]);
      await setup.openFeed(tester);
      return setup;
    }

    List<NostrEvent> sentLikes(_Setup setup) => [
          for (final batch in setup.relays.sent)
            for (final event in batch)
              if (event.kind == NostrKinds.reaction) event,
        ];

    testWidgets('a contagem vem da API ao abrir o feed', (tester) async {
      final setup = _Setup();
      await setup.follow([_ana]);
      final record = _record(_ana, createdAt: 100);
      setup.store([_template(_ana), record]);
      setup.social.counts[record.id] = LikeCount(eventId: record.id, count: 3);
      await setup.openFeed(tester);

      expect(setup.social.calls.last, [record.id]);
      expect(find.text('3 curtidas'), findsOneWidget);
      expect(find.byTooltip('Curtir'), findsOneWidget);
    });

    testWidgets('curtir publica um kind 7 e a contagem sobe na hora',
        (tester) async {
      final setup = await feedWithOneWorkout(tester);
      expect(find.text('0 curtidas'), findsOneWidget);

      await tester.tap(find.byTooltip('Curtir'));
      await tester.pumpAndSettle();

      expect(find.text('1 curtida'), findsOneWidget);
      expect(find.byTooltip('Você curtiu'), findsOneWidget);
      final like = sentLikes(setup).single;
      expect(like.isValid, isTrue);
      expect(like.content, '+');
    });

    testWidgets('toque duplo publica um like só', (tester) async {
      final setup = _Setup();
      setup.relays.gate = Completer<void>();
      await setup.follow([_ana]);
      setup.store([_template(_ana), _record(_ana, createdAt: 100)]);
      await setup.openFeed(tester);

      await tester.tap(find.byTooltip('Curtir'));
      await tester.pump();
      // Enquanto o relay não responde, o botão já está marcado.
      expect(find.byTooltip('Você curtiu'), findsOneWidget);
      await tester.tap(find.byTooltip('Você curtiu'), warnIfMissed: false);
      setup.relays.gate!.complete();
      await tester.pumpAndSettle();

      expect(sentLikes(setup), hasLength(1));
      expect(find.text('1 curtida'), findsOneWidget);
    });

    testWidgets('nenhum relay aceita: volta ao que era, com aviso humano',
        (tester) async {
      final setup = _Setup();
      await setup.follow([_ana]);
      setup.store([_template(_ana), _record(_ana, createdAt: 100)]);
      await setup.openFeed(tester);
      for (final url in setup.relays.relays) {
        setup.relays.outcomes[url] = RelayOutcome.rejected;
      }

      await tester.tap(find.byTooltip('Curtir'));
      await tester.pumpAndSettle();

      expect(find.text('0 curtidas'), findsOneWidget);
      expect(find.byTooltip('Curtir'), findsOneWidget);
      expect(
          find.textContaining('Não foi possível curtir agora'), findsOneWidget);
    });

    testWidgets('a API confirma o like depois do ciclo do worker',
        (tester) async {
      final setup = await feedWithOneWorkout(tester);
      final record = setup.relays.stored.values.first
          .firstWhere((e) => e.kind == NostrKinds.workoutRecord);

      await tester.tap(find.byTooltip('Curtir'));
      await tester.pumpAndSettle();

      // Antes do worker: a API ainda não conta o like, e o otimista fica.
      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(find.text('1 curtida'), findsOneWidget);

      // Depois do ciclo: a API conta 1, curtido por mim. Não vira 2.
      setup.social.counts[record.id] =
          LikeCount(eventId: record.id, count: 1, likedByMe: true);
      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(find.text('1 curtida'), findsOneWidget);
      expect(setup.social.calls.length, greaterThanOrEqualTo(3));
    });
  });
}
