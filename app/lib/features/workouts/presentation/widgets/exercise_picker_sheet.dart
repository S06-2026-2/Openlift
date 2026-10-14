// FE-03 — Seletor de exercício: biblioteca agrupada por grupo muscular, com
// busca por nome. Devolve o [ExerciseModel] escolhido via Navigator.pop.

import 'package:flutter/material.dart';

import '../../domain/exercise_model.dart';

Future<ExerciseModel?> showExercisePicker(
  BuildContext context, {
  required List<ExerciseModel> exercises,
}) {
  return showModalBottomSheet<ExerciseModel>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ExercisePickerSheet(exercises: exercises),
  );
}

class ExercisePickerSheet extends StatefulWidget {
  const ExercisePickerSheet({super.key, required this.exercises});

  final List<ExerciseModel> exercises;

  @override
  State<ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<ExercisePickerSheet> {
  String _query = '';

  Map<String, List<ExerciseModel>> _grouped() {
    final query = _query.trim().toLowerCase();
    final groups = <String, List<ExerciseModel>>{};
    for (final exercise in widget.exercises) {
      if (query.isNotEmpty && !exercise.name.toLowerCase().contains(query)) {
        continue;
      }
      groups.putIfAbsent(exercise.muscleGroup, () => []).add(exercise);
    }
    final sortedKeys = groups.keys.toList()..sort();
    return {
      for (final key in sortedKeys)
        key: (groups[key]!..sort((a, b) => a.name.compareTo(b.name))),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = _grouped();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: false,
                decoration: const InputDecoration(
                  hintText: 'Buscar exercício',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: widget.exercises.isEmpty
                  ? const _Message('Nenhum exercício cadastrado ainda.')
                  : groups.isEmpty
                      ? const _Message('Nenhum exercício encontrado.')
                      : ListView(
                          children: [
                            for (final entry in groups.entries) ...[
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 4),
                                child: Text(
                                  entry.key.toUpperCase(),
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              for (final exercise in entry.value)
                                ListTile(
                                  title: Text(exercise.name),
                                  onTap: () =>
                                      Navigator.of(context).pop(exercise),
                                ),
                            ],
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}
