// Botão de trocar entre tema claro e escuro (fica no Início e no Perfil).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_mode_controller.dart';

/// Botão de trocar entre tema claro e escuro.
class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return IconButton(
      tooltip: isDark ? 'Usar tema claro' : 'Usar tema escuro',
      icon: Icon(
        isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
        size: 20,
      ),
      onPressed: () => ref.read(themeModeProvider.notifier).toggle(brightness),
    );
  }
}
