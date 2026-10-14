// FE-02 — Casca visual compartilhada por Login e Cadastro (marca + conteúdo
// centralizado, com largura máxima confortável na web) e o aviso de erro.

import 'package:flutter/material.dart';

class AuthFormShell extends StatelessWidget {
  const AuthFormShell({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.fitness_center_rounded,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'OpenLift',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Seu treino. Seus dados.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Aviso de erro em linguagem humana (nunca stack trace).
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.error;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
