// FE-05 — NostrRelayService: NIP-01 `EVENT` → `OK` por relay, com relays
// independentes e tempo limite (RF-22). Sem rede: o WebSocket é trocado por
// uma conexão em memória.

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
}
