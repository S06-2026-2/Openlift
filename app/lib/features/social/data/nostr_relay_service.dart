// FE-05 — Publicação nos relays NOSTR por WebSocket (NIP-01, ADR-0007).
//
// Para cada relay: abre a conexão, envia `["EVENT", <evento>]` de cada evento
// e espera o `["OK", <id>, <aceito>, <mensagem>]` do último (o kind 1301).
// Os relays são independentes: um fora do ar não atrasa nem derruba os
// outros, e cada um tem o seu resultado (RF-22). Leitura (REQ) fica para o
// FE-06.
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

class NostrRelayService {
  NostrRelayService({
    required this.relays,
    RelayConnector? connector,
    this.timeout = const Duration(seconds: 8),
  }) : _connector = connector ?? _WebSocketRelayConnection.new;

  /// URLs `wss://` dos relays, na ordem configurada.
  final List<String> relays;

  /// Limite para conectar e, depois, para a resposta `OK`.
  final Duration timeout;

  final RelayConnector _connector;

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
