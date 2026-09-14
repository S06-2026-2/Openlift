// Sprint 1 — Indicador de carregamento padrão, reutilizado nos estados `loading` dos controllers.

import 'package:flutter/material.dart';

/// Widget reutilizável para exibição de estado de carregamento.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({
    super.key,
    this.message,
    this.size,
    this.color,
    this.strokeWidth = 3.0,
  });

  /// Mensagem opcional de feedback exibida abaixo do indicador.
  final String? message;

  /// Dimensão (largura e altura) do indicador.
  final double? size;

  /// Cor customizada do indicador (usa primary do tema por padrão).
  final Color? color;

  /// Espessura do traço do indicador de progresso.
  final double strokeWidth;

  // TODO(Sprint 5): variante skeleton para listas (dashboard, histórico de treinos).

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indicatorColor = color ?? theme.colorScheme.primary;

    Widget indicator = CircularProgressIndicator(
      strokeWidth: strokeWidth,
      valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
    );

    if (size != null) {
      indicator = SizedBox(
        width: size,
        height: size,
        child: indicator,
      );
    }

    if (message == null) {
      return Center(child: indicator);
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          indicator,
          const SizedBox(height: 16),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
