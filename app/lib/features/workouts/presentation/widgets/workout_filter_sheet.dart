// FE-03 — Filtro do histórico: período (data inicial/final) e exercício.
// Devolve o [WorkoutFilter] escolhido via Navigator.pop (null = cancelou).

import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/exercise_model.dart';
import '../workout_controller.dart';

Future<WorkoutFilter?> showWorkoutFilterSheet(
  BuildContext context, {
  required WorkoutFilter initial,
  required List<ExerciseModel> exercises,
}) {
  return showModalBottomSheet<WorkoutFilter>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _WorkoutFilterSheet(initial: initial, exercises: exercises),
  );
}

class _WorkoutFilterSheet extends StatefulWidget {
  const _WorkoutFilterSheet({required this.initial, required this.exercises});

  final WorkoutFilter initial;
  final List<ExerciseModel> exercises;

  @override
  State<_WorkoutFilterSheet> createState() => _WorkoutFilterSheetState();
}

class _WorkoutFilterSheetState extends State<_WorkoutFilterSheet> {
  late DateTime? _from = widget.initial.from;
  late DateTime? _to = widget.initial.to;
  late int? _exerciseId = widget.initial.exerciseId;

  String get _periodLabel {
    if (_from == null && _to == null) return 'Qualquer data';
    final from = _from == null ? '...' : formatDateBr(_from!);
    final to = _to == null ? '...' : formatDateBr(_to!);
    return '$from – $to';
  }

  Future<void> _pickPeriod() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: today,
      initialDateRange: (_from != null && _to != null)
          ? DateTimeRange(start: _from!, end: _to!)
          : null,
    );
    if (picked != null && mounted) {
      setState(() {
        _from = picked.start;
        _to = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exercises = [...widget.exercises]
      ..sort((a, b) => a.name.compareTo(b.name));

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Filtrar treinos',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickPeriod,
            icon: const Icon(Icons.date_range_rounded),
            label: Text(_periodLabel),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            initialValue: _exerciseId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Exercício'),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Todos os exercícios'),
              ),
              for (final exercise in exercises)
                DropdownMenuItem<int?>(
                  value: exercise.id,
                  child: Text(exercise.name),
                ),
            ],
            onChanged: (value) => setState(() => _exerciseId = value),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.of(context).pop(const WorkoutFilter()),
                  child: const Text('Limpar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    WorkoutFilter(
                      from: _from,
                      to: _to,
                      exerciseId: _exerciseId,
                    ),
                  ),
                  child: const Text('Aplicar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
