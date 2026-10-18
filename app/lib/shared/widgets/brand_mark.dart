// Marca do OpenLift: símbolo quadrado + nome. Usada no login/cadastro e na
// barra lateral (telas largas).

import 'package:flutter/material.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 28, this.showName = true});

  /// Lado do símbolo quadrado.
  final double size;

  /// Exibe o nome "OpenLift" ao lado do símbolo.
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final symbol = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Icon(
        Icons.fitness_center_rounded,
        size: size * 0.58,
        color: scheme.onPrimary,
      ),
    );

    if (!showName) return symbol;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        symbol,
        const SizedBox(width: 10),
        Text(
          'OpenLift',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}
