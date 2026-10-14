// FE-03 — Histórico de treinos: lista com pull-to-refresh, estados
// loading/error/empty, filtro por data/exercício, editar e excluir (com
// confirmação).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../domain/exercise_model.dart';
import '../domain/workout_model.dart';
import 'widgets/state_views.dart';
import 'widgets/workout_filter_sheet.dart';
import 'workout_controller.dart';

class WorkoutHistoryScreen extends ConsumerWidget {
  const WorkoutHistoryScreen({super.key});

  Future<void> _openFilter(BuildContext context, WidgetRef ref) async {
    final library = ref.read(exerciseLibraryProvider).valueOrNull ?? const [];
    final chosen = await showWorkoutFilterSheet(
      context,
      initial: ref.read(workoutFilterProvider),
      exercises: library,
    );
    if (chosen != null) ref.read(workoutFilterProvider.notifier).set(chosen);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    WorkoutModel workout,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir treino?'),
        content: Text(
          'O treino de ${formatDateBr(workout.date)} será removido. '
          'Essa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || workout.id == null) return;

    try {
      await ref.read(workoutControllerProvider.notifier).remove(workout.id!);
      messenger.showSnackBar(const SnackBar(content: Text('Treino excluído.')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('Não foi possível excluir o treino.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workouts = ref.watch(workoutControllerProvider);
    final filter = ref.watch(workoutFilterProvider);
    final exercises = {
      for (final e in ref.watch(exerciseLibraryProvider).valueOrNull ??
          const <ExerciseModel>[])
        e.id: e,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Treinos'),
        leading: BackButton(onPressed: () => context.go(AppRoutes.dashboard)),
        actions: [
          IconButton(
            tooltip: 'Filtrar',
            onPressed: () => _openFilter(context, ref),
            icon: Badge(
              isLabelVisible: filter.isActive,
              child: const Icon(Icons.filter_list_rounded),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AppRoutes.newWorkout),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo treino'),
      ),
      body: workouts.when(
        loading: () => const LoadingIndicator(message: 'Carregando treinos...'),
        error: (error, _) => RefreshIndicator(
          onRefresh: () => ref.refresh(workoutControllerProvider.future),
          child: ErrorStateView(
            message: error is ApiException
                ? error.message
                : 'Não foi possível carregar seus treinos.',
            onRetry: () => ref.invalidate(workoutControllerProvider),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => ref.refresh(workoutControllerProvider.future),
              child: filter.isActive
                  ? EmptyStateView(
                      icon: Icons.search_off_rounded,
                      title: 'Nenhum treino encontrado',
                      description:
                          'Nenhum treino bate com os filtros escolhidos.',
                      actionLabel: 'Limpar filtros',
                      onAction: () =>
                          ref.read(workoutFilterProvider.notifier).clear(),
                    )
                  : EmptyStateView(
                      icon: Icons.fitness_center_rounded,
                      title: 'Nenhum treino ainda',
                      description:
                          'Registre seu primeiro treino e acompanhe '
                          'sua evolução por aqui.',
                      actionLabel: 'Registrar primeiro treino',
                      onAction: () => context.go(AppRoutes.newWorkout),
                    ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(workoutControllerProvider.future),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final workout = items[index];
                return _WorkoutCard(
                  workout: workout,
                  exercises: exercises,
                  onTap: workout.id == null
                      ? null
                      : () => context.go(AppRoutes.editWorkout(workout.id!)),
                  onDelete: () => _confirmDelete(context, ref, workout),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({
    required this.workout,
    required this.exercises,
    required this.onTap,
    required this.onDelete,
  });

  final WorkoutModel workout;
  final Map<int, ExerciseModel> exercises;
  final VoidCallback? onTap;
  final VoidCallback onDelete;

  String get _exerciseSummary {
    final names = [
      for (final id in workout.exerciseIds)
        exercises[id]?.name ?? 'Exercício #$id',
    ];
    if (names.isEmpty) return 'Sem exercícios';
    if (names.length <= 3) return names.join(' · ');
    return '${names.take(3).join(' · ')} +${names.length - 3}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.7);
    final setsCount = workout.sets.length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatDateBr(workout.date),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _exerciseSummary,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$setsCount ${setsCount == 1 ? 'série' : 'séries'}'
                      ' · ${formatKg(workout.volumeKg)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Excluir treino',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
