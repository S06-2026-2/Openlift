// Seção "Visão geral" do Início (RF-41, RF-42): resumo da semana, volume
// semanal, mapa de calor por grupo muscular e frequência por grupo.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/stats_model.dart';
import '../dashboard_controller.dart';
import '../volume_heatmap_widget.dart';
import 'muscle_frequency_chart.dart';
import 'weekly_volume_chart.dart';

class DashboardOverview extends ConsumerWidget {
  const DashboardOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardProvider);

    return stats.when(
      skipLoadingOnRefresh: true,
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      ),
      error: (error, _) => _Message(
        icon: Icons.cloud_off_rounded,
        text: error is ApiException
            ? error.message
            : 'Não foi possível carregar suas estatísticas.',
        action: AppButton(
          label: 'Tentar novamente',
          icon: Icons.refresh_rounded,
          variant: AppButtonVariant.secondary,
          isFullWidth: false,
          onPressed: () => ref.read(dashboardProvider.notifier).refresh(),
        ),
      ),
      data: (data) => data.isEmpty
          ? const _Message(
              icon: Icons.insights_rounded,
              text: 'Registre seu primeiro treino para ver volume semanal, '
                  'frequência e o mapa de calor por grupo muscular.',
            )
          : _Charts(data: data),
    );
  }
}

class _Charts extends StatelessWidget {
  const _Charts({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final current = data.volume.currentWeek;
    final previous = data.volume.previousWeek;
    final top = data.topMuscleGroup;
    final heatmap = data.heatmap;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Tiles(
          children: [
            _StatTile(
              icon: Icons.fitness_center_rounded,
              label: 'Volume da semana',
              value: formatKg(current?.volume ?? 0),
              detail: _delta(current?.volume ?? 0, previous?.volume ?? 0),
            ),
            _StatTile(
              icon: Icons.calendar_month_rounded,
              label: 'Treinos em ${DashboardController.volumeWeeks} semanas',
              value: '${data.volume.totalWorkouts}',
              detail: '${current?.workouts ?? 0} nesta semana',
            ),
            _StatTile(
              icon: Icons.local_fire_department_rounded,
              label: 'Músculo mais treinado',
              value: top?.name ?? '—',
              detail: top == null
                  ? 'Sem volume nos últimos '
                      '${DashboardController.frequencyDays} dias'
                  : '${formatKg(top.volume)} em '
                      '${DashboardController.frequencyDays} dias',
              accent: true,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title: 'Volume semanal',
          subtitle: 'Carga × repetições, sem aquecimento',
          child: WeeklyVolumeChart(weeks: data.volume.weeks),
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title: 'Mapa de calor por grupo muscular',
          subtitle: 'Volume de cada grupo nas últimas '
              '${heatmap.weekStarts.length} semanas',
          child: VolumeHeatmap(
            rows: heatmap.weeklyRows(),
            weekStarts: heatmap.weekStarts,
          ),
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title: 'Frequência por grupo muscular',
          subtitle: 'Dias treinados nos últimos '
              '${DashboardController.frequencyDays} dias',
          child: MuscleFrequencyChart(
            groups: data.muscleGroups,
            periodDays: DashboardController.frequencyDays,
          ),
        ),
      ],
    );
  }

  static String _delta(double current, double previous) {
    if (previous <= 0) {
      return current > 0 ? 'Primeira semana com volume' : 'Sem treino ainda';
    }
    final change = ((current - previous) / previous * 100).round();
    if (change == 0) return 'Igual à semana passada';
    return change > 0
        ? '+$change% vs. semana passada'
        : '$change% vs. semana passada';
  }
}

/// Três cards lado a lado em telas largas, empilhados no celular.
class _Tiles extends StatelessWidget {
  const _Tiles({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
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

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: accent
                      ? AppTheme.heatScale.last
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(detail, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(subtitle, style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}
