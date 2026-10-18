// FE-03 — Views de estado reutilizadas pelas telas de treino: erro com
// "Tentar novamente" e estado vazio com chamada para ação.

import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/page_layout.dart';

/// Centraliza [child] e continua rolável (necessário para o pull-to-refresh
/// funcionar também quando não há itens).
class ScrollableCentered extends StatelessWidget {
  const ScrollableCentered({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _StateView extends StatelessWidget {
  const _StateView({
    required this.icon,
    required this.title,
    required this.action,
    this.description,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ScrollableCentered(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTile(icon, size: 48),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            if (description != null) ...[
              const SizedBox(height: 6),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 24),
            action,
          ],
        ),
      ),
    );
  }
}

class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _StateView(
      icon: Icons.cloud_off_rounded,
      title: message,
      action: AppButton(
        label: 'Tentar novamente',
        icon: Icons.refresh_rounded,
        variant: AppButtonVariant.secondary,
        isFullWidth: false,
        onPressed: onRetry,
      ),
    );
  }
}

class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return _StateView(
      icon: icon,
      title: title,
      description: description,
      action: AppButton(
        label: actionLabel,
        icon: Icons.add_rounded,
        isFullWidth: false,
        onPressed: onAction,
      ),
    );
  }
}
