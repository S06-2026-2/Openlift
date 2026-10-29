// FE-03 — Tela "Novo Treino" / "Editar treino".
//
// Data + blocos por exercício, cada um com séries (reps, carga em kg, RPE
// opcional, tipo). Meta RNF-13: registrar uma série em ≤ 3 toques — o botão
// "Repetir última" copia a série anterior em 1 toque.
//
// Limites (RN-07): carga ≤ 1000 kg e reps ≤ 500, validados aqui; o 422 do
// servidor também é tratado e mostrado em linguagem humana.
//
// FE-05 — Visibilidade Privado / Publicado (RF-21, só ida). Publicar pede
// confirmação antes de salvar (consentimento na 1ª vez, RNF-12); salvar um
// treino publicado pergunta se publica a nova versão (RN-08). A
// publicação segue em segundo plano e o resultado aparece no histórico.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/page_layout.dart';
import '../../social/presentation/publication_controller.dart';
import '../../social/presentation/widgets/publication_widgets.dart';
import '../domain/exercise_model.dart';
import '../domain/set_model.dart';
import '../domain/workout_model.dart';
import '../domain/workout_validators.dart';
import 'widgets/exercise_picker_sheet.dart';
import 'widgets/state_views.dart';
import 'workout_controller.dart';

class WorkoutFormScreen extends ConsumerWidget {
  const WorkoutFormScreen({super.key, this.workoutId});

  /// `null` = novo treino; preenchido = edição.
  final int? workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEdit = workoutId != null;
    final title = isEdit ? 'Editar treino' : 'Novo treino';

    final library = ref.watch(exerciseLibraryProvider);
    final existing = isEdit ? ref.watch(workoutByIdProvider(workoutId!)) : null;

    if (library.isLoading || (existing?.isLoading ?? false)) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const LoadingIndicator(message: 'Carregando...'),
      );
    }

    final failure = library.hasError
        ? library.error
        : (existing?.hasError ?? false)
            ? existing!.error
            : null;
    if (failure != null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ErrorStateView(
          message: failure is ApiException
              ? failure.message
              : 'Não foi possível carregar os dados do treino.',
          onRetry: () {
            ref.invalidate(exerciseLibraryProvider);
            if (isEdit) ref.invalidate(workoutByIdProvider(workoutId!));
          },
        ),
      );
    }

    return _WorkoutForm(
      key: ValueKey(workoutId),
      workoutId: workoutId,
      exercises: library.requireValue,
      initial: existing?.value,
    );
  }
}

// ---------------------------------------------------------------------------
// Estado local do formulário
// ---------------------------------------------------------------------------

class _SetRow {
  _SetRow({
    String repsText = '',
    String weightText = '',
    String rpeText = '',
    this.type = SetType.normal,
    this.id,
  })  : reps = TextEditingController(text: repsText),
        weight = TextEditingController(text: weightText),
        rpe = TextEditingController(text: rpeText);

  final int? id;
  final TextEditingController reps;
  final TextEditingController weight;
  final TextEditingController rpe;
  SetType type;

  /// Cópia dos valores (sem o id): usada por "Repetir última".
  _SetRow duplicate() => _SetRow(
        repsText: reps.text,
        weightText: weight.text,
        rpeText: rpe.text,
        type: type,
      );

  void dispose() {
    reps.dispose();
    weight.dispose();
    rpe.dispose();
  }
}

class _ExerciseBlock {
  _ExerciseBlock(this.exercise);

  final ExerciseModel exercise;
  final List<_SetRow> rows = [];
}

class _WorkoutForm extends ConsumerStatefulWidget {
  const _WorkoutForm({
    super.key,
    required this.workoutId,
    required this.exercises,
    this.initial,
  });

  final int? workoutId;
  final List<ExerciseModel> exercises;
  final WorkoutModel? initial;

  @override
  ConsumerState<_WorkoutForm> createState() => _WorkoutFormState();
}

class _WorkoutFormState extends ConsumerState<_WorkoutForm> {
  final _formKey = GlobalKey<FormState>();
  final List<_ExerciseBlock> _blocks = [];
  late DateTime _date;
  late bool _publish;
  bool _saving = false;
  bool _confirming = false;
  String? _error;

  bool get _isEdit => widget.workoutId != null;

  /// Já publicado: a visibilidade fica travada em Publicado.
  bool get _wasPublished => widget.initial?.isPublished ?? false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _date = DateUtils.dateOnly(initial?.date ?? DateTime.now());
    _publish = _wasPublished;
    if (initial != null) _loadBlocks(initial);
  }

  @override
  void dispose() {
    for (final block in _blocks) {
      for (final row in block.rows) {
        row.dispose();
      }
    }
    super.dispose();
  }

  void _loadBlocks(WorkoutModel workout) {
    final library = {for (final e in widget.exercises) e.id: e};
    final byExercise = <int, _ExerciseBlock>{};
    for (final set in workout.sets) {
      final block = byExercise.putIfAbsent(set.exerciseId, () {
        final exercise = library[set.exerciseId] ??
            ExerciseModel(
              id: set.exerciseId,
              name: 'Exercício #${set.exerciseId}',
              muscleGroup: ExerciseModel.fallbackGroup,
            );
        final created = _ExerciseBlock(exercise);
        _blocks.add(created);
        return created;
      });
      block.rows.add(
        _SetRow(
          id: set.id,
          repsText: set.reps.toString(),
          weightText: formatNumber(set.weightKg),
          rpeText: set.rpe == null ? '' : formatNumber(set.rpe!),
          type: set.type,
        ),
      );
    }
  }

  // ---- ações ---------------------------------------------------------------

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(today) ? today : _date,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked != null && mounted) {
      setState(() => _date = DateUtils.dateOnly(picked));
    }
  }

  Future<void> _addExercise() async {
    final picked = await showExercisePicker(
      context,
      exercises: widget.exercises,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _error = null;
      var block = _blocks.where((b) => b.exercise.id == picked.id).firstOrNull;
      if (block == null) {
        block = _ExerciseBlock(picked);
        _blocks.add(block);
      }
      block.rows.add(_SetRow());
    });
  }

  void _addRow(_ExerciseBlock block) {
    setState(() => block.rows.add(_SetRow()));
  }

  void _repeatLast(_ExerciseBlock block) {
    if (block.rows.isEmpty) return;
    setState(() => block.rows.add(block.rows.last.duplicate()));
  }

  void _removeRow(_ExerciseBlock block, _SetRow row) {
    setState(() => block.rows.remove(row));
    _disposeAfterFrame([row]);
  }

  void _removeBlock(_ExerciseBlock block) {
    setState(() => _blocks.remove(block));
    _disposeAfterFrame(block.rows);
  }

  /// Os campos ainda estão na árvore neste frame: descartar os controllers
  /// só depois que a reconstrução os tirou de cena.
  void _disposeAfterFrame(List<_SetRow> rows) {
    final doomed = List<_SetRow>.of(rows);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final row in doomed) {
        row.dispose();
      }
    });
  }

  Future<void> _save() async {
    if (_saving || _confirming) return;
    setState(() => _error = null);

    if (_blocks.isEmpty) {
      setState(() => _error = 'Adicione ao menos um exercício com uma série.');
      return;
    }
    final emptyBlock = _blocks.where((b) => b.rows.isEmpty).firstOrNull;
    if (emptyBlock != null) {
      setState(() {
        _error = 'Adicione uma série em "${emptyBlock.exercise.name}" '
            'ou remova o exercício.';
      });
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Trava antes de qualquer await: a confirmação consulta a API antes de
    // abrir o diálogo, e um 2º toque nesse intervalo abriria outro diálogo e
    // duplicaria treino e evento (S2-04). Sem setState, para o spinner do
    // botão não girar atrás do diálogo.
    _confirming = true;
    try {
      await _confirmAndSave();
    } finally {
      _confirming = false;
    }
  }

  Future<void> _confirmAndSave() async {
    // Decide antes de salvar: depois do PATCH esta tela é reconstruída.
    // Publicar um privado sem confirmação não salva nada (a pessoa pode
    // voltar ao Privado); num publicado, "Agora não" só salva.
    final bool publish;
    if (_wasPublished) {
      publish = await confirmRepublication(context);
    } else if (_publish) {
      if (!await confirmPublication(context, ref)) return;
      publish = true;
    } else {
      publish = false;
    }
    if (!mounted) return;

    final workout = WorkoutModel(
      date: _date,
      sets: [
        for (final block in _blocks)
          for (final row in block.rows)
            SetModel(
              id: row.id,
              exerciseId: block.exercise.id,
              reps: int.parse(row.reps.text.trim()),
              weightKg: WorkoutValidators.parseDecimal(row.weight.text)!,
              rpe: WorkoutValidators.parseDecimal(row.rpe.text),
              type: row.type,
            ),
      ],
    );

    setState(() => _saving = true);
    final controller = ref.read(workoutControllerProvider.notifier);
    try {
      final saved = _isEdit
          ? await controller.edit(widget.workoutId!, workout)
          : await controller.create(workout);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(SnackBar(
        content:
            Text(publish ? 'Treino salvo. Publicando...' : 'Treino salvo.'),
      ));
      if (publish) {
        // Segue depois que a tela fecha; o histórico mostra o andamento.
        unawaited(
          ref
              .read(publicationControllerProvider.notifier)
              .publish(saved)
              .then((result) {
            if (result != null) {
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(result.summary)));
            }
          }),
        );
      }
      context.go(AppRoutes.workouts);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Object {
      if (mounted) {
        setState(() => _error = 'Algo deu errado. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---- UI -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Editar treino' : 'Novo treino'),
        leading: BackButton(
          onPressed: () => context.go(AppRoutes.workouts),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Salvar'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) => ListView(
            padding: pagePadding(constraints),
            children: [
              _DateTile(date: _date, onTap: _pickDate),
              const SizedBox(height: 12),
              _VisibilityTile(
                publish: _publish,
                locked: _wasPublished,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _publish = value),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                ErrorBanner(message: _error!),
                const SizedBox(height: 16),
              ],
              if (_blocks.isEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Text(
                    'Nenhum exercício ainda. Adicione o primeiro para '
                    'registrar suas séries.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              for (final block in _blocks) ...[
                _ExerciseCard(
                  block: block,
                  onAddRow: () => _addRow(block),
                  onRepeatLast: () => _repeatLast(block),
                  onRemoveRow: (row) => _removeRow(block, row),
                  onRemoveBlock: () => _removeBlock(block),
                  onTypeChanged: (row, type) => setState(() => row.type = type),
                ),
                const SizedBox(height: 12),
              ],
              AppButton(
                label: 'Adicionar exercício',
                icon: Icons.add_rounded,
                variant: AppButtonVariant.secondary,
                onPressed: _saving ? null : _addExercise,
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Salvar treino',
                isLoading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final muted = theme.colorScheme.onSurfaceVariant;

    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Text('Data',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: muted,
                  )),
              const Spacer(),
              Text(formatDateBr(date), style: theme.textTheme.titleSmall),
              const SizedBox(width: 10),
              Icon(Icons.calendar_today_outlined, size: 16, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// RF-21: Privado / Publicado. Depois de publicado, não volta.
class _VisibilityTile extends StatelessWidget {
  const _VisibilityTile({
    required this.publish,
    required this.locked,
    required this.onChanged,
  });

  final bool publish;
  final bool locked;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Visibilidade',
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
            const Spacer(),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Privado'),
                  icon: Icon(Icons.lock_outline_rounded, size: 16),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Publicado'),
                  icon: Icon(Icons.public_rounded, size: 16),
                ),
              ],
              selected: {publish},
              onSelectionChanged: locked || onChanged == null
                  ? null
                  : (selection) => onChanged!(selection.first),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          locked
              ? 'Publicado no NOSTR. Não dá para voltar a privado.'
              : publish
                  ? 'Ao salvar, o treino fica público e permanente no NOSTR.'
                  : 'Só você vê este treino.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.block,
    required this.onAddRow,
    required this.onRepeatLast,
    required this.onRemoveRow,
    required this.onRemoveBlock,
    required this.onTypeChanged,
  });

  final _ExerciseBlock block;
  final VoidCallback onAddRow;
  final VoidCallback onRepeatLast;
  final void Function(_SetRow row) onRemoveRow;
  final VoidCallback onRemoveBlock;
  final void Function(_SetRow row, SetType type) onTypeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.labelSmall;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        block.exercise.name,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        block.exercise.muscleGroup,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remover exercício',
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  onPressed: onRemoveBlock,
                ),
              ],
            ),
            if (block.rows.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(width: 28, child: Text('#', style: headerStyle)),
                  Expanded(
                    flex: 3,
                    child: Center(child: Text('Reps', style: headerStyle)),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 4,
                    child:
                        Center(child: Text('Carga (kg)', style: headerStyle)),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 3,
                    child: Center(child: Text('RPE', style: headerStyle)),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 64,
                    child: Center(child: Text('Tipo', style: headerStyle)),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 6),
            ],
            for (var i = 0; i < block.rows.length; i++)
              KeyedSubtree(
                key: ObjectKey(block.rows[i]),
                child: _SetRowView(
                  index: i + 1,
                  row: block.rows[i],
                  onRemove: () => onRemoveRow(block.rows[i]),
                  onTypeChanged: (type) => onTypeChanged(block.rows[i], type),
                ),
              ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: onAddRow,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Série'),
                ),
                TextButton.icon(
                  onPressed: block.rows.isEmpty ? null : onRepeatLast,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Repetir última'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SetRowView extends StatelessWidget {
  const _SetRowView({
    required this.index,
    required this.row,
    required this.onRemove,
    required this.onTypeChanged,
  });

  final int index;
  final _SetRow row;
  final VoidCallback onRemove;
  final ValueChanged<SetType> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('$index'),
            ),
          ),
          Expanded(
            flex: 3,
            child: _NumberField(
              controller: row.reps,
              validator: WorkoutValidators.reps,
              digitsOnly: true,
              semanticLabel: 'Repetições da série $index',
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 4,
            child: _NumberField(
              controller: row.weight,
              validator: WorkoutValidators.weight,
              semanticLabel: 'Carga em quilos da série $index',
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: _NumberField(
              controller: row.rpe,
              validator: WorkoutValidators.rpe,
              semanticLabel: 'RPE da série $index',
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 64,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: PopupMenuButton<SetType>(
                tooltip: 'Tipo da série',
                initialValue: row.type,
                onSelected: onTypeChanged,
                itemBuilder: (_) => [
                  for (final type in SetType.values)
                    PopupMenuItem(value: type, child: Text(type.label)),
                ],
                child: Container(
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: row.type == SetType.normal
                        ? null
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: Text(
                    row.type.shortLabel,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              tooltip: 'Remover série',
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: onRemove,
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.validator,
    required this.semanticLabel,
    this.digitsOnly = false,
  });

  final TextEditingController controller;
  final String? Function(String?) validator;
  final String semanticLabel;
  final bool digitsOnly;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: TextFormField(
        controller: controller,
        validator: validator,
        textAlign: TextAlign.center,
        keyboardType: digitsOnly
            ? TextInputType.number
            : const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            RegExp(digitsOnly ? r'[0-9]' : r'[0-9.,]'),
          ),
        ],
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          errorMaxLines: 2,
          errorStyle: TextStyle(fontSize: 11, height: 1.1),
        ),
      ),
    );
  }
}
