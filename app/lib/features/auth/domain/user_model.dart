// FE-01 — Modelo de usuário no app.
//
// Espelha o `UserOut` do backend (POST /auth/register): { id, email, npub,
// created_at }. `npub` é nulo até a identidade NOSTR ser registrada.

class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    this.npub,
    this.createdAt,
  });

  final int id;
  final String email;
  final String? npub;
  final DateTime? createdAt;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final createdAt = json['created_at'];
    return UserModel(
      id: (json['id'] as num).toInt(),
      email: json['email'] as String,
      npub: json['npub'] as String?,
      createdAt: createdAt is String ? DateTime.tryParse(createdAt) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'npub': npub,
        'created_at': createdAt?.toIso8601String(),
      };
}
