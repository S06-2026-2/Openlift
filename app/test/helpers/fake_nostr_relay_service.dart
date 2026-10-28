// Helper de teste: NostrRelayService sem rede. Guarda o que seria enviado e
// responde o resultado configurado para cada relay. Na leitura (FE-06), cada
// relay devolve os eventos de [stored] que batem com o filtro.

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

  @override
  int get connectAttempts => 1;

  /// Resultado de cada relay; relay fora do mapa aceita.
  final Map<String, RelayOutcome> outcomes;

  /// Cada chamada de `publish`, com os eventos na ordem enviada.
  final List<List<NostrEvent>> sent = [];

  /// Se definido, `publish` só termina quando ele completar.
  Completer<void>? gate;

  /// Eventos guardados em cada relay (leitura). Por padrão, cada relay
  /// também guarda o que foi publicado nele com sucesso.
  final Map<String, List<NostrEvent>> stored = {};

  /// Status de leitura de cada relay; relay fora do mapa responde completo.
  final Map<String, RelayReadStatus> readStatus = {};

  /// Relays que devolvem tudo o que guardam, sem aplicar o filtro.
  final Set<String> ignoringFilters = {};

  /// Filtros de cada chamada de `query`.
  final List<List<Map<String, Object>>> queries = [];

  @override
  Future<List<RelayPublishResult>> publish(List<NostrEvent> events) async {
    sent.add(List.of(events));
    final wait = gate;
    if (wait != null) await wait.future;
    for (final url in relays) {
      if ((outcomes[url] ?? RelayOutcome.accepted) == RelayOutcome.accepted) {
        stored.putIfAbsent(url, () => []).addAll(events);
      }
    }
    return [
      for (final url in relays)
        RelayPublishResult(
          url: url,
          outcome: outcomes[url] ?? RelayOutcome.accepted,
        ),
    ];
  }

  @override
  Future<RelayQueryResult> query(List<Map<String, Object>> filters) async {
    queries.add(filters);
    final seen = <String>{};
    final events = <NostrEvent>[];
    final results = <RelayReadResult>[];
    for (final url in relays) {
      final status = readStatus[url] ?? RelayReadStatus.complete;
      results.add(RelayReadResult(url: url, status: status));
      if (status == RelayReadStatus.unreachable) continue;
      for (final event in stored[url] ?? const <NostrEvent>[]) {
        final match = ignoringFilters.contains(url) ||
            filters.any((f) => _matches(f, event));
        if (match && seen.add(event.id)) {
          events.add(event);
        }
      }
    }
    return RelayQueryResult(events: events, relays: results);
  }

  static bool _matches(Map<String, Object> filter, NostrEvent event) {
    final kinds = filter['kinds'] as List?;
    final authors = filter['authors'] as List?;
    return (kinds == null || kinds.contains(event.kind)) &&
        (authors == null || authors.contains(event.pubkey));
  }
}
