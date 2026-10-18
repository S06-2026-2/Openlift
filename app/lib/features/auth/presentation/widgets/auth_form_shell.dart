// FE-02 — Casca visual compartilhada por Login e Cadastro: marca, título da
// tela e o formulário numa coluna estreita. Em telas largas o conteúdo fica
// num cartão com borda fina.

import 'package:flutter/material.dart';

import '../../../../shared/widgets/brand_mark.dart';

class AuthFormShell extends StatelessWidget {
  const AuthFormShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 600;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        ...children,
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: BrandMark(size: 32)),
                  const SizedBox(height: 32),
                  if (wide)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: content,
                      ),
                    )
                  else
                    content,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
