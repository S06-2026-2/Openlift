// NOSTR-02 — Kinds NOSTR usados pelo OpenLift, em constante única (ADR-0003):
// se o rascunho NIP-101e mudar, só este arquivo muda. Nenhum número de kind
// aparece solto no resto do código.

abstract final class NostrKinds {
  /// NIP-01 — metadados do perfil.
  static const int metadata = 0;

  /// NIP-02 — lista de quem o usuário segue.
  static const int contacts = 3;

  /// NIP-25 — reação (like).
  static const int reaction = 7;

  /// NIP-101e — registro de treino. Treino nunca é `kind 1` (ADR-0003).
  static const int workoutRecord = 1301;

  /// NIP-101e — modelo de exercício (endereçável), referenciado pelo 1301.
  static const int exerciseTemplate = 33401;
}
