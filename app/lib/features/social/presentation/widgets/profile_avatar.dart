// Foto de perfil redonda; sem foto (ou se ela não carregar), as iniciais.

import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    this.url,
    this.image,
    this.radius = 20,
  });

  /// Nome usado para as iniciais.
  final String name;
  final String? url;

  /// Imagem já carregada (ex.: prévia da foto escolhida). Vence [url].
  final ImageProvider? image;
  final double radius;

  String get _initials {
    final clean = name.replaceAll('@', '').trim();
    if (clean.isEmpty) return '?';
    final parts = clean.split(RegExp(r'[\s._]+')).where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return letters.isEmpty ? clean[0].toUpperCase() : letters;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final provider = image ?? (url == null ? null : NetworkImage(url!));

    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundImage: provider,
      onForegroundImageError: provider == null ? null : (_, __) {},
      child: Text(
        _initials,
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }
}
