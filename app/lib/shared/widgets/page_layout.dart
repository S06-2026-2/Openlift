// Layout de página: conteúdo centralizado com largura máxima (web) e
// cabeçalho de seção. Mantém as telas alinhadas na mesma coluna.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Padding de uma lista/página que centraliza o conteúdo em
/// [AppTheme.contentMaxWidth], mantendo a área rolável em toda a largura.
EdgeInsets pagePadding(
  BoxConstraints constraints, {
  double top = 24,
  double bottom = 32,
}) {
  final side = math.max(
    20.0,
    (constraints.maxWidth - AppTheme.contentMaxWidth) / 2,
  );
  return EdgeInsets.fromLTRB(side, top, side, bottom);
}

/// Título + subtítulo de uma página, com ação opcional à direita.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.headlineMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 16), trailing!],
      ],
    );
  }
}

/// Rótulo pequeno em caixa alta que separa seções.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall,
    );
  }
}

/// Quadrado com borda fina e ícone ao centro (estados vazios, atalhos).
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.size = 40, this.filled = false});

  final IconData icon;
  final double size;

  /// `true` = fundo na cor primária (destaque); `false` = só a borda.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? scheme.primary : scheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: filled ? null : Border.all(color: scheme.outline),
      ),
      child: Icon(
        icon,
        size: size * 0.5,
        color: filled ? scheme.onPrimary : scheme.onSurface,
      ),
    );
  }
}
