// FE-05 — NostrRelayService: NIP-01 `EVENT` → `OK` por relay, com relays
// independentes e tempo limite (RF-22). Sem rede: o WebSocket é trocado por
// uma conexão em memória.
// FE-06 — Leitura: `REQ` até o `EOSE`, `CLOSE`, deduplicação por `id`
// (RF-24) e reconexão com backoff.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openlift/core/constants/app_constants.dart';
import 'package:openlift/core/nostr/nostr_event.dart';
import 'package:openlift/core/nostr/nostr_kinds.dart';
import 'package:openlift/core/nostr/nostr_signer.dart';
import 'package:openlift/features/social/data/nostr_relay_service.dart';

/// Como o relay de teste responde a cada `EVENT`.
enum _Behavior { accept, reject, silent, refuse, hangUp }

class _FakeConnection implements RelayConnection {
  _FakeConnection(this.behavior);

  final _Behavior behavior;
  final StreamController<dynamic> _incoming = StreamController<dynamic>();
  final List<String> sent = [];
  bool closed = false;

  @override
  Future<void> get ready => behavior == _Behavior.refuse
      ? Future<void>.error(StateError('conexão recusada'))
      : Future<void>.value();

  @override
  Stream<dynamic> get messages => _incoming.stream;

  @override
  void send(String message) {
    sent.add(message);
    final event = (jsonDecode(message) as List)[1] as Map<String, dynamic>;
    final id = event['id'] as String;
    switch (behavior) {
      case _Behavior.accept:
        // Barulho que o serviço deve ignorar antes da resposta certa.
        _incoming.add('["NOTICE","oi"]');
        _incoming.add('não é json');
        _incoming.add(jsonEncode(['OK', 'f' * 64, false, 'outro evento']));
        _incoming.add(jsonEncode(['OK', id, true, '']));
      case _Behavior.reject:
        _incoming.add(jsonEncode(['OK', id, false, 'blocked: teste']));
      case _Behavior.hangUp:
        _incoming.close();
      case _Behavior.silent:
      case _Behavior.refuse:
        break;
    }
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

/// Relay de leitura: responde o `REQ` com os eventos guardados e `EOSE`.
enum _ReadMode { serve, partial, hangUp }

class _ReadConnection implements RelayConnection {
  _ReadConnection(this.events, {this.mode = _ReadMode.serve});

  final List<NostrEvent> events;
  final _ReadMode mode;
  final StreamController<dynamic> _incoming = StreamController<dynamic>();
  final List<List<dynamic>> sent = [];

  @override
  Future<void> get ready => Future<void>.value();

  @override
  Stream<dynamic> get messages => _incoming.stream;

  @override
  void send(String message) {
    final decoded = jsonDecode(message) as List;
    sent.add(decoded);
    if (decoded[0] != 'REQ') return;
    final sub = decoded[1] as String;
    if (mode == _ReadMode.hangUp) {
      _incoming.close();
      return;
    }
    // Outra assinatura e lixo: o serviço ignora.
    _incoming.add(jsonEncode(['EVENT', 'outra', events.first.toJson()]));
    _incoming.add(jsonEncode([
      'EVENT',
      sub,
      {'id': 'malformado'}
    ]));
    for (final event in events) {
      _incoming.add(jsonEncode(['EVENT', sub, event.toJson()]));
    }
    if (mode == _ReadMode.serve) _incoming.add(jsonEncode(['EOSE', sub]));
  }

  @override
  Future<void> close() async {}
}

NostrEvent _event(NostrSigner signer, int kind, int createdAt) => signer.sign(
      UnsignedNostrEvent(
        pubkey: signer.publicKey,
        createdAt: createdAt,
        kind: kind,
        tags: const [
          ['alt', 'teste'],
        ],
        content: '',
      ),
    );

void main() {
  final signer = NostrSigner.generate();
  final template = _event(signer, NostrKinds.exerciseTemplate, 1760000000);
  final record = _event(signer, NostrKinds.workoutRecord, 1760000001);

  late Map<String, _FakeConnection> connections;

  NostrRelayService service(Map<String, _Behavior> relays) {
    connections = {};
    return NostrRelayService(
      relays: relays.keys.toList(),
      timeout: const Duration(milliseconds: 50),
      connector: (url) => connections[url.toString()] =
          _FakeConnection(relays[url.toString()]!),
    );
  }

  test('envia ["EVENT", evento] de cada evento, na ordem, e lê o OK', () async {
    final relays = service({'wss://a.test': _Behavior.accept});

    final results = await relays.publish([template, record]);

    final sent = connections['wss://a.test']!.sent.map(jsonDecode).toList();
    expect(sent, [
      ['EVENT', template.toJson()],
      ['EVENT', record.toJson()],
    ]);
    expect(results.single.url, 'wss://a.test');
    expect(results.single.host, 'a.test');
    expect(results.single.outcome, RelayOutcome.accepted);
    expect(connections['wss://a.test']!.closed, isTrue);
  });

  test('cada relay tem o seu resultado e um fora do ar não derruba os outros',
      () async {
    final relays = service({
      'wss://aceita.test': _Behavior.accept,
      'wss://recusa.test': _Behavior.reject,
      'wss://mudo.test': _Behavior.silent,
      'wss://fora.test': _Behavior.refuse,
      'wss://cai.test': _Behavior.hangUp,
    });

    final results = await relays.publish([record]);

    expect({
      for (final r in results) r.host: r.outcome
    }, {
      'aceita.test': RelayOutcome.accepted,
      'recusa.test': RelayOutcome.rejected,
      'mudo.test': RelayOutcome.timeout,
      'fora.test': RelayOutcome.unreachable,
      'cai.test': RelayOutcome.unreachable,
    });
    expect(results.where((r) => r.accepted), hasLength(1));
  });

  test('URL inválida vira "não conectou", sem lançar', () async {
    final relays = NostrRelayService(
      relays: const ['wss://a.test'],
      connector: (_) => throw const FormatException('URL ruim'),
    );

    final results = await relays.publish([record]);

    expect(results.single.outcome, RelayOutcome.unreachable);
  });

  group('lista de relays (ADR-0007)', () {
    test('padrão: os três relays do ADR-0007', () {
      expect(AppConstants.nostrRelays, [
        'wss://relay.damus.io',
        'wss://nos.lol',
        'wss://relay.nostr.band',
      ]);
    });

    test('--dart-define: separa por vírgula, ignora vazio e repetido', () {
      expect(
        AppConstants.parseRelayList(
            ' wss://a.test , ,wss://b.test,wss://a.test'),
        ['wss://a.test', 'wss://b.test'],
      );
      expect(AppConstants.parseRelayList(''), isEmpty);
    });
  });

  group('leitura (FE-06)', () {
    final other = _event(signer, NostrKinds.workoutRecord, 1760000002);
    final filters = [
      {
        'kinds': [NostrKinds.workoutRecord],
        'authors': [signer.publicKey],
      },
    ];

    test('REQ com os filtros, junta até o EOSE, deduplica e manda CLOSE',
        () async {
      final reads = <String, _ReadConnection>{
        'wss://a.test': _ReadConnection([record, template]),
        'wss://b.test': _ReadConnection([record, other]),
      };
      final relays = NostrRelayService(
        relays: reads.keys.toList(),
        timeout: const Duration(milliseconds: 50),
        connector: (url) => reads[url.toString()]!,
      );

      final result = await relays.query(filters);

      // `record` veio dos dois relays e aparece uma vez (RF-24).
      expect(
          result.events.map((e) => e.id), [record.id, template.id, other.id]);
      expect(result.relays.map((r) => r.status),
          everyElement(RelayReadStatus.complete));
      final a = reads['wss://a.test']!.sent;
      expect(a.first[0], 'REQ');
      expect(a.first.sublist(2), filters);
      expect(a.last, ['CLOSE', a.first[1]]);
    });

    test('sem EOSE no tempo: usa o que chegou e marca timeout', () async {
      final relays = NostrRelayService(
        relays: const ['wss://a.test'],
        timeout: const Duration(milliseconds: 50),
        connector: (_) => _ReadConnection([record], mode: _ReadMode.partial),
      );

      final result = await relays.query(filters);

      expect(result.events.single.id, record.id);
      expect(result.relays.single.status, RelayReadStatus.timeout);
      expect(result.anyRelayResponded, isTrue);
    });

    test('conexão que cai antes do EOSE não lança', () async {
      final relays = NostrRelayService(
        relays: const ['wss://a.test'],
        timeout: const Duration(milliseconds: 50),
        connector: (_) => _ReadConnection([record], mode: _ReadMode.hangUp),
      );

      final result = await relays.query(filters);

      expect(result.events, isEmpty);
      expect(result.relays.single.status, RelayReadStatus.timeout);
    });

    test('reconecta com backoff (0,5 s, 1 s) antes de desistir', () async {
      var attempts = 0;
      final waits = <Duration>[];
      final relays = NostrRelayService(
        relays: const ['wss://a.test'],
        timeout: const Duration(seconds: 5),
        delay: (d) async => waits.add(d),
        connector: (_) {
          attempts++;
          return attempts < 3
              ? _FakeConnection(_Behavior.refuse)
              : _ReadConnection([record]);
        },
      );

      final result = await relays.query(filters);

      expect(attempts, 3);
      expect(waits, [
        const Duration(milliseconds: 500),
        const Duration(seconds: 1),
      ]);
      expect(result.relays.single.status, RelayReadStatus.complete);
      expect(result.events.single.id, record.id);
    });

    test('as novas tentativas não passam do tempo limite', () async {
      var attempts = 0;
      final relays = NostrRelayService(
        relays: const ['wss://fora.test'],
        // Menor que a 1ª espera (0,5 s): não cabe nenhuma nova tentativa.
        timeout: const Duration(milliseconds: 100),
        delay: (_) async {},
        connector: (_) {
          attempts++;
          return _FakeConnection(_Behavior.refuse);
        },
      );

      final result = await relays.query(filters);

      expect(attempts, 1);
      expect(result.relays.single.status, RelayReadStatus.unreachable);
    });

    test('relay que nunca conecta fica "unreachable" e os outros seguem',
        () async {
      final relays = NostrRelayService(
        relays: const ['wss://fora.test', 'wss://a.test'],
        timeout: const Duration(milliseconds: 50),
        delay: (_) async {},
        connector: (url) => url.host == 'fora.test'
            ? _FakeConnection(_Behavior.refuse)
            : _ReadConnection([record]),
      );

      final result = await relays.query(filters);

      expect({
        for (final r in result.relays) r.url: r.status
      }, {
        'wss://fora.test': RelayReadStatus.unreachable,
        'wss://a.test': RelayReadStatus.complete,
      });
      expect(result.events, hasLength(1));
    });
  });
}
