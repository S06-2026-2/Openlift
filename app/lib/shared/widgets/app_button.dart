// Sprint 1 — Botão padrão do design system (variantes: primary, secondary, danger).

import 'package:flutter/material.dart';

import 'loading_indicator.dart';

/// Variantes visuais suportadas pelo [AppButton].
enum AppButtonVariant {
  primary,
  secondary,
  danger,
}

/// Botão padronizado do OpenLift com suporte a variantes e estado de loading.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.isFullWidth = true,
    this.height = 48.0,
  });

  /// Texto exibido no botão.
  final String label;

  /// Callback disparado ao tocar no botão (nulo se desabilitado).
  final VoidCallback? onPressed;

  /// Estilo visual do botão (primário, secundário ou perigo).
  final AppButtonVariant variant;

  /// Indica se o botão está em estado de processamento/carregamento.
  final bool isLoading;

  /// Ícone opcional posicionado antes do texto.
  final IconData? icon;

  /// Se deve ocupar toda a largura disponível do elemento pai.
  final bool isFullWidth;

  /// Altura do botão.
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = onPressed != null && !isLoading;

    final effectiveOnPressed = isEnabled ? onPressed : null;

    final Color loadingColor;
    switch (variant) {
      case AppButtonVariant.primary:
      case AppButtonVariant.danger:
        loadingColor = Colors.white;
        break;
      case AppButtonVariant.secondary:
        loadingColor = theme.colorScheme.primary;
        break;
    }

    Widget content = isLoading
        ? LoadingIndicator(
            size: 20,
            strokeWidth: 2.5,
            color: loadingColor,
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );

    final Widget button;

    switch (variant) {
      case AppButtonVariant.primary:
        button = ElevatedButton(
          onPressed: effectiveOnPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: theme.colorScheme.primary.withValues(alpha: 0.5),
            disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: content,
        );
        break;

      case AppButtonVariant.secondary:
        button = OutlinedButton(
          onPressed: effectiveOnPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurface,
            disabledForegroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.38),
            side: BorderSide(
              color: isEnabled
                  ? theme.colorScheme.outline
                  : theme.colorScheme.outline.withValues(alpha: 0.5),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: content,
        );
        break;

      case AppButtonVariant.danger:
        button = ElevatedButton(
          onPressed: effectiveOnPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: Colors.white,
            disabledBackgroundColor: theme.colorScheme.error.withValues(alpha: 0.5),
            disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: content,
        );
        break;
    }

    if (isFullWidth) {
      return SizedBox(
        width: double.infinity,
        height: height,
        child: button,
      );
    }

    return SizedBox(
      height: height,
      child: button,
    );
  }
}
