// FE-05 — Publicação nos relays NOSTR por WebSocket (NIP-01, ADR-0007).
//
// Para cada relay: abre a conexão, envia `["EVENT", <evento>]` de cada evento
// e espera o `["OK", <id>, <aceito>, <mensagem>]` do último (o kind 1301).
// Os relays são independentes: um fora do ar não atrasa nem derruba os
// outros, e cada um tem o seu resultado (RF-22).
//
// FE-06 — Leitura: `["REQ", <id>, <filtros>...]`, junta os `EVENT` até o
// `EOSE` e fecha a assinatura. Conexão que falha é tentada de novo com espera
// crescente (backoff). Eventos repetidos entre relays chegam uma vez só
// (RF-24); quem verifica a assinatura é quem consome (RF-51).
//
// Só trafegam eventos já assinados. A chave privada não passa por aqui.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/nostr/nostr_event.dart';

/// Uma conexão com um relay. Existe para os testes trocarem o WebSocket.
abstract class RelayConnection {
  /// Completa quando a conexão abriu; falha se não abriu.
  Future<void> get ready;

  /// Mensagens recebidas do relay (texto JSON).
  Stream<dynamic> get messages;

  void send(String message);

  Future<void> close();
}

typedef RelayConnector = RelayConnection Function(Uri url);

enum RelayOutcome {
  /// O relay respondeu `OK` com `true`.
  accepted,

  /// O relay respondeu `OK` com `false` (ex.: bloqueado, limite de taxa).
  rejected,

  /// Conectou, mas não respondeu dentro do tempo.
  timeout,

  /// Não conectou ou a conexão caiu antes da resposta.
  unreachable,
}

class RelayPublishResult {
  const RelayPublishResult({required this.url, required this.outcome});

  final String url;
  final RelayOutcome outcome;

  bool get accepted => outcome == RelayOutcome.accepted;

  /// `wss://relay.damus.io` → `relay.damus.io`, para a tela.
  String get host {
    final parsed = Uri.tryParse(url);
    return (parsed == null || parsed.host.isEmpty) ? url : parsed.host;
  }
}

/// Como terminou a leitura em um relay.
enum RelayReadStatus {
  /// Mandou tudo o que tinha (`EOSE`).
  complete,

  /// Conectou, mas não mandou o `EOSE` (demorou ou a conexão caiu); o que
  /// chegou até ali é usado.
  timeout,

  /// Não conectou, mesmo depois das novas tentativas.
  unreachable,
}

class RelayReadResult {
  const RelayReadResult({required this.url, required this.status});

  final String url;
  final RelayReadStatus status;

  bool get responded => status != RelayReadStatus.unreachable;
}

class RelayQueryResult {
  const RelayQueryResult({required this.events, required this.relays});

  /// Um por `id`, na ordem em que chegaram. Assinatura ainda não verificada.
  final List<NostrEvent> events;
  final List<RelayReadResult> relays;

  bool get anyRelayResponded => relays.any((r) => r.responded);
}

class NostrRelayService {
  NostrRelayService({
    required this.relays,
    RelayConnector? connector,
    this.timeout = const Duration(seconds: 8),
    this.connectAttempts = 3,
    Future<void> Function(Duration)? delay,
  })  : _connector = connector ?? _WebSocketRelayConnection.new,
        _delay = delay ?? Future<void>.delayed;

  /// URLs `wss://` dos relays, na ordem configurada.
  final List<String> relays;

  /// Limite para conectar e, depois, para a resposta `OK`.
  final Duration timeout;

  /// Tentativas de conexão na leitura (a 1ª + novas tentativas).
  final int connectAttempts;

  final RelayConnector _connector;
  final Future<void> Function(Duration) _delay;
  int _subscriptions = 0;

  /// Envia [events] (nessa ordem) a todos os relays em paralelo. O resultado
  /// de cada relay é o do último evento. Nunca lança.
  Future<List<RelayPublishResult>> publish(List<NostrEvent> events) {
    if (events.isEmpty) throw ArgumentError('Nada para publicar');
    return Future.wait([for (final url in relays) _publishTo(url, events)]);
  }

  Future<RelayPublishResult> _publishTo(
    String url,
    List<NostrEvent> events,
  ) async {
    RelayPublishResult result(RelayOutcome outcome) =>
        RelayPublishResult(url: url, outcome: outcome);

    // `null` = a conexão acabou antes do `OK`.
    final acks = {for (final event in events) event.id: Completer<bool?>()};
    void finishAll() {
      for (final ack in acks.values) {
        if (!ack.isCompleted) ack.complete(null);
      }
    }

    RelayConnection? connection;
    StreamSubscription<dynamic>? subscription;
    try {
      connection = _connector(Uri.parse(url));
      await connection.ready.timeout(timeout);
      subscription = connection.messages.listen(
        (message) {
          final ok = _parseOk(message);
          final ack = ok == null ? null : acks[ok.$1];
          if (ack != null && !ack.isCompleted) ack.complete(ok!.$2);
        },
        onError: (Object _) => finishAll(),
        onDone: finishAll,
      );
      for (final event in events) {
        connection.send(jsonEncode(['EVENT', event.toJson()]));
      }
      final accepted = await acks[events.last.id]!.future.timeout(timeout);
      if (accepted == null) return result(RelayOutcome.unreachable);
      return result(accepted ? RelayOutcome.accepted : RelayOutcome.rejected);
    } on TimeoutException {
      return result(RelayOutcome.timeout);
    } on Object {
      return result(RelayOutcome.unreachable);
    } finally {
      finishAll();
      await subscription?.cancel();
      // Fechar não pode travar nem derrubar o resultado.
      unawaited(connection?.close().catchError((Object _) {}));
    }
  }

  /// Lê de todos os relays em paralelo os eventos que batem com [filters]
  /// (formato NIP-01, ex.: `{"kinds": [1301], "authors": [...]}`). Nunca
  /// lança: relay fora do ar só aparece no resultado dele.
  Future<RelayQueryResult> query(List<Map<String, Object>> filters) async {
    if (filters.isEmpty) throw ArgumentError('Nenhum filtro');
    final perRelay = await Future.wait(
      [for (final url in relays) _queryRelay(url, filters)],
    );
    final seen = <String>{};
    return RelayQueryResult(
      events: [
        for (final (_, events) in perRelay)
          for (final event in events)
            if (seen.add(event.id)) event,
      ],
      relays: [for (final (result, _) in perRelay) result],
    );
  }

  Future<(RelayReadResult, List<NostrEvent>)> _queryRelay(
    String url,
    List<Map<String, Object>> filters,
  ) async {
    final events = <NostrEvent>[];
    (RelayReadResult, List<NostrEvent>) result(RelayReadStatus status) =>
        (RelayReadResult(url: url, status: status), events);

    final connection = await _connectWithBackoff(url);
    if (connection == null) return result(RelayReadStatus.unreachable);

    final subscription = 'openlift-${++_subscriptions}';
    final finished = Completer<bool>(); // true = EOSE
    final listener = connection.messages.listen(
      (message) {
        final decoded = _decodeList(message);
        if (decoded == null || decoded.length < 2) return;
        if (decoded[1] != subscription) return;
        switch (decoded[0]) {
          case 'EVENT' when decoded.length >= 3 && decoded[2] is Map:
            try {
              events.add(NostrEvent.fromJson(
                Map<String, dynamic>.from(decoded[2] as Map),
              ));
            } on FormatException {
              // Evento malformado: descartado.
            }
          case 'EOSE' || 'CLOSED':
            if (!finished.isCompleted) finished.complete(decoded[0] == 'EOSE');
        }
      },
      onError: (Object _) {
        if (!finished.isCompleted) finished.complete(false);
      },
      onDone: () {
        if (!finished.isCompleted) finished.complete(false);
      },
    );

    try {
      connection.send(jsonEncode(['REQ', subscription, ...filters]));
      final complete = await finished.future.timeout(timeout);
      return result(
          complete ? RelayReadStatus.complete : RelayReadStatus.timeout);
    } on TimeoutException {
      return result(RelayReadStatus.timeout);
    } on Object {
      return result(RelayReadStatus.unreachable);
    } finally {
      try {
        connection.send(jsonEncode(['CLOSE', subscription]));
      } on Object {
        // Conexão já caiu: nada a fechar.
      }
      await listener.cancel();
      unawaited(connection.close().catchError((Object _) {}));
    }
  }

  /// Conecta com até [connectAttempts] tentativas, esperando 0,5 s, 1 s,
  /// 2 s... entre elas, sem passar de [timeout] no total: relay fora do ar
  /// não segura a tela. `null` se nenhuma deu certo.
  Future<RelayConnection?> _connectWithBackoff(String url) async {
    final elapsed = Stopwatch()..start();
    var wait = const Duration(milliseconds: 500);
    for (var attempt = 1; attempt <= connectAttempts; attempt++) {
      RelayConnection? connection;
      try {
        connection = _connector(Uri.parse(url));
        await connection.ready.timeout(timeout - elapsed.elapsed);
        return connection;
      } on Object {
        unawaited(connection?.close().catchError((Object _) {}));
        if (attempt == connectAttempts) break;
        if (elapsed.elapsed + wait >= timeout) break;
        await _delay(wait);
        wait *= 2;
      }
    }
    return null;
  }

  static List<dynamic>? _decodeList(dynamic message) {
    if (message is! String) return null;
    try {
      final decoded = jsonDecode(message);
      return decoded is List ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// `["OK", id, aceito, mensagem]` → `(id, aceito)`; outra coisa → `null`.
  static (String, bool)? _parseOk(dynamic message) {
    if (message is! String) return null;
    try {
      final decoded = jsonDecode(message);
      if (decoded is List &&
          decoded.length >= 3 &&
          decoded[0] == 'OK' &&
          decoded[1] is String &&
          decoded[2] is bool) {
        return (decoded[1] as String, decoded[2] as bool);
      }
    } on FormatException {
      // Mensagem que não é JSON: ignora.
    }
    return null;
  }
}

class _WebSocketRelayConnection implements RelayConnection {
  _WebSocketRelayConnection(Uri url) : _channel = WebSocketChannel.connect(url);

  final WebSocketChannel _channel;

  @override
  Future<void> get ready => _channel.ready;

  @override
  Stream<dynamic> get messages => _channel.stream;

  @override
  void send(String message) => _channel.sink.add(message);

  @override
  Future<void> close() async => _channel.sink.close();
}

final nostrRelayServiceProvider = Provider<NostrRelayService>(
  (ref) => NostrRelayService(relays: AppConstants.nostrRelays),
);
