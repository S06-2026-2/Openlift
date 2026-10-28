// Helper de teste: NostrRelayService sem rede. Guarda o que seria enviado e
// responde o resultado configurado para cada relay.

import 'dart:async';

import 'package:openlift/core/nostr/nostr_event.dart';
import 'package:openlift/features/social/data/nostr_relay_service.dart';

class FakeNostrRelayService implements NostrRelayService {
  FakeNostrRelayService({
    this.relays = const [
      'wss://relay.um.test',
      'wss://relay.dois.test',
      'wss://relay.tres.test',
    ],
    Map<String, RelayOutcome>? outcomes,
  }) : outcomes = {...?outcomes};

  @override
  final List<String> relays;

  @override
  Duration get timeout => Duration.zero;

  /// Resultado de cada relay; relay fora do mapa aceita.
  final Map<String, RelayOutcome> outcomes;

  /// Cada chamada de `publish`, com os eventos na ordem enviada.
  final List<List<NostrEvent>> sent = [];

  /// Se definido, `publish` só termina quando ele completar.
  Completer<void>? gate;

  @override
  Future<List<RelayPublishResult>> publish(List<NostrEvent> events) async {
    sent.add(List.of(events));
    final wait = gate;
    if (wait != null) await wait.future;
    return [
      for (final url in relays)
        RelayPublishResult(
          url: url,
          outcome: outcomes[url] ?? RelayOutcome.accepted,
        ),
    ];
  }
}
