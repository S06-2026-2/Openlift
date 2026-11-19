// FE-08 — Evento de like (kind 7, NIP-25), leitura da contagem da API e
// `GET /social/likes` (BE-10) com vários `event_ids`.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlift/core/network/api_client.dart';
import 'package:openlift/core/network/api_exception.dart';
import 'package:openlift/core/nostr/nostr_kinds.dart';
import 'package:openlift/core/nostr/nostr_signer.dart';
import 'package:openlift/features/social/data/social_repository.dart';
import 'package:openlift/features/social/domain/like_model.dart';
import 'package:openlift/features/social/domain/published_workout.dart';

import '../../helpers/fake_http_adapter.dart';

String _hex(int n) => n.toRadixString(16).padLeft(64, '0');

void main() {
  group('LikeEvent', () {
    final me = NostrSigner.generate();
    final author = NostrSigner.generate().publicKey;
    final workout = PublishedWorkout(
      eventId: _hex(1301),
      pubkey: author,
      createdAt: 100,
      date: DateTime(2026, 10, 13),
      sets: const [],
    );

    test('kind 7 com content "+", tags e/p/k e assinatura válida', () {
      final event = me.sign(LikeEvent.build(
        pubkey: me.publicKey,
        workout: workout,
        createdAt: 200,
        relayHint: 'wss://relay.um.test',
      ));

      expect(event.kind, NostrKinds.reaction);
      expect(event.kind, 7);
      expect(event.content, '+');
      expect(event.tags, [
        ['e', workout.eventId, 'wss://relay.um.test', author],
        ['p', author, 'wss://relay.um.test'],
        ['k', '1301'],
      ]);
      expect(event.isValid, isTrue);
    });

    test('a última tag e é o treino curtido (alvo na NIP-25)', () {
      final event = LikeEvent.build(
        pubkey: me.publicKey,
        workout: workout,
        createdAt: 200,
      );

      final eTags = event.tags.where((t) => t.first == 'e');
      expect(eTags.last[1], workout.eventId);
    });
  });

  group('LikeCount', () {
    test('lê o formato da API', () {
      final count = LikeCount.fromJson({
        'event_id': _hex(1),
        'count': 3,
        'liked_by_me': true,
      });

      expect(count.eventId, _hex(1));
      expect(count.count, 3);
      expect(count.likedByMe, isTrue);
    });

    test('sem event_id é resposta fora do contrato', () {
      expect(
        () => LikeCount.fromJson({'count': 1}),
        throwsFormatException,
      );
    });
  });

  group('SocialRepository', () {
    late FakeHttpAdapter adapter;
    late ApiClient client;
    late SocialRepository repository;

    void build(RequestHandler handler) {
      adapter = FakeHttpAdapter(handler);
      final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))
        ..httpClientAdapter = adapter;
      client = ApiClient(storage: MemorySecureStorage(access: 'a'), dio: dio);
      repository = SocialRepository(api: client);
    }

    tearDown(() => client.dispose());

    List<Map<String, Object>> echo(RequestOptions options) => [
          for (final id in options.uri.queryParametersAll['event_ids']!)
            {'event_id': id, 'count': 1, 'liked_by_me': false},
        ];

    test('repete event_ids na URL, como a API espera', () async {
      build((options) => jsonResponse(echo(options)));

      final counts = await repository.getLikeCounts([_hex(1), _hex(2)]);

      final uri = adapter.requests.single.uri;
      expect(uri.path, '/api/v1/social/likes');
      expect(uri.query, 'event_ids=${_hex(1)}&event_ids=${_hex(2)}');
      expect(counts.map((c) => c.eventId), [_hex(1), _hex(2)]);
    });

    test('mais de 100 ids vão em várias requisições', () async {
      build((options) => jsonResponse(echo(options)));

      final counts = await repository.getLikeCounts([
        for (var i = 0; i < 250; i++) _hex(i),
      ]);

      expect(adapter.requests, hasLength(3));
      expect(
        adapter.requests
            .map((r) => r.uri.queryParametersAll['event_ids']!.length),
        [100, 100, 50],
      );
      expect(counts, hasLength(250));
    });

    test('erro da API vira ApiException com mensagem humana', () async {
      build((_) => jsonResponse({'detail': 'x', 'code': 'y'}, status: 500));

      await expectLater(
        repository.getLikeCounts([_hex(1)]),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
