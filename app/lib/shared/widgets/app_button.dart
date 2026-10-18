// Botão padrão do design system (variantes: primary, secondary, danger).

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
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
    this.height = 44.0,
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
    final scheme = Theme.of(context).colorScheme;
    final isEnabled = onPressed != null && !isLoading;
    final effectiveOnPressed = isEnabled ? onPressed : null;

    final (Color background, Color foreground) = switch (variant) {
      AppButtonVariant.primary => (scheme.primary, scheme.onPrimary),
      AppButtonVariant.danger => (scheme.error, scheme.onError),
      AppButtonVariant.secondary => (Colors.transparent, scheme.onSurface),
    };

    final content = isLoading
        ? LoadingIndicator(size: 18, strokeWidth: 2, color: foreground)
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
    );
    const padding = EdgeInsets.symmetric(horizontal: 16);

    final Widget button = variant == AppButtonVariant.secondary
        ? OutlinedButton(
            onPressed: effectiveOnPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: foreground,
              disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
              side: BorderSide(color: scheme.outline),
              padding: padding,
              shape: shape,
            ),
            child: content,
          )
        : ElevatedButton(
            onPressed: effectiveOnPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: background,
              foregroundColor: foreground,
              disabledBackgroundColor: background.withValues(alpha: 0.4),
              disabledForegroundColor: foreground.withValues(alpha: 0.8),
              elevation: 0,
              padding: padding,
              shape: shape,
            ),
            child: content,
          );

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: height,
      child: button,
    );
  }
}
