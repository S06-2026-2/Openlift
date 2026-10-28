// Sprint 1 — Constantes globais do app.

class AppConstants {
  /// URL base da API FastAPI (configurável via --dart-define=API_URL=...).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );

  /// Relays NOSTR, separados por vírgula (ADR-0007). Configurável via
  /// --dart-define=NOSTR_RELAYS=wss://a,wss://b. O primeiro é o relay
  /// indicado nas referências aos modelos de exercício.
  static const String _nostrRelays = String.fromEnvironment(
    'NOSTR_RELAYS',
    defaultValue: 'wss://relay.damus.io,wss://nos.lol,wss://relay.nostr.band',
  );

  static List<String> get nostrRelays => parseRelayList(_nostrRelays);

  /// `" wss://a , ,wss://b"` → `[wss://a, wss://b]`, sem repetidos.
  static List<String> parseRelayList(String raw) => [
        ...{
          for (final url in raw.split(','))
            if (url.trim().isNotEmpty) url.trim(),
        },
      ];
}
