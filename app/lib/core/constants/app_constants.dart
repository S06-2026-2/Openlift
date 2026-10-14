// Sprint 1 — Constantes globais do app.

class AppConstants {
  /// URL base da API FastAPI (configurável via --dart-define=API_URL=...).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );

  // TODO(Sprint 3): defaultNostrRelays (ex.: relay.damus.io, nos.lol, relay.nostr.band).
}
