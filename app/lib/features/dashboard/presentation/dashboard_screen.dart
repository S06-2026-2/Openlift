// Tela inicial: saudação, atalhos para registrar treino e ver o histórico, e
// o espaço reservado para as métricas.
//
// Sprint 3 — cards de resumo (volume da semana, treinos no mês, streak) +
// gráfico de volume (fl_chart). Sprint 5 adiciona o heatmap.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_layout.dart';
import '../../auth/presentation/auth_controller.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  // TODO(Sprint 3): cards de resumo + gráfico de linha/barra de volume.
  // TODO(Sprint 5): seção com VolumeHeatmapWidget.

  static String _greeting(DateTime now) {
    if (now.hour < 12) return 'Bom dia';
    if (now.hour < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Início'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout_rounded, size: 20),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => ListView(
          padding: pagePadding(constraints, top: 32),
          children: [
            PageHeader(
              title: _greeting(DateTime.now()),
              subtitle: 'Registre a sessão de hoje ou revise o que já fez.',
            ),
            const SizedBox(height: 28),
            _Shortcuts(
              children: [
                _ShortcutCard(
                  icon: Icons.add_rounded,
                  title: 'Novo treino',
                  description: 'Séries, cargas e RPE em poucos toques.',
                  highlighted: true,
                  onTap: () => context.go(AppRoutes.newWorkout),
                ),
                _ShortcutCard(
                  icon: Icons.history_rounded,
                  title: 'Meus treinos',
                  description: 'Histórico com filtros por data e exercício.',
                  onTap: () => context.go(AppRoutes.workouts),
                ),
              ],
            ),
            const SizedBox(height: 36),
            const SectionLabel('Visão geral'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.insights_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Volume semanal, frequência e mapa de calor por grupo '
                      'muscular aparecem aqui em breve.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Atalhos lado a lado em telas largas, empilhados no celular.
class _Shortcuts extends StatelessWidget {
  const _Shortcuts({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                children[i],
              ],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: children[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(icon, filled: highlighted),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(description, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
