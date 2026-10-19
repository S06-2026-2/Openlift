// NOSTR-03 — Adapter único entre o treino do OpenLift e os eventos do
// mini-NIP (docs/nips/openlift-workout-event.md, ADR-0003).
//
// Escrita é estrita (RN-01, RN-07, RN-09, números canônicos): o que sai daqui
// valida contra docs/nips/*.schema.json. Leitura é tolerante com eventos de
// terceiros (mini-NIP §5), mas descarta assinatura inválida (RF-51).
//
// Se o rascunho NIP-101e mudar, a mudança fica neste arquivo.

import 'package:unorm_dart/unorm_dart.dart' as unorm;
import 'package:uuid/uuid.dart';

import '../../../core/nostr/nostr_event.dart';
import '../../../core/nostr/nostr_kinds.dart';
import '../../../core/utils/formatters.dart';
import '../../workouts/domain/exercise_model.dart';
import '../../workouts/domain/set_model.dart';
import '../../workouts/domain/workout_model.dart';
import '../../workouts/domain/workout_validators.dart';
import 'published_workout.dart';

/// Equipamento do modelo de exercício (valores do NIP-101e).
enum ExerciseEquipment { barbell, dumbbell, bodyweight, machine, cardio }

/// Treino que não pode virar evento. A [message] é para o usuário.
class WorkoutEventException implements Exception {
  const WorkoutEventException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WorkoutEventAdapter {
  const WorkoutEventAdapter({required this.relayHint});

  /// Relay onde os modelos 33401 são publicados (primeiro da lista
  /// configurada, ADR-0007). Vazio quando não há.
  final String relayHint;

  /// `UUIDv5(NAMESPACE_URL, "https://github.com/S06-2026-2/Openlift/nips/exercise")`.
  static const String exerciseNamespace =
      '1556e53f-1af3-5f85-97f3-b8a979c5e169';

  static const double minRpe = 1;
  static const double maxRpe = 10;

  /// Vocabulário fixo de grupo muscular (mini-NIP §3).
  static const Map<String, String> muscleGroupTags = {
    'Peito': 'chest',
    'Costas': 'back',
    'Ombros': 'shoulders',
    'Bíceps': 'biceps',
    'Tríceps': 'triceps',
    'Quadríceps': 'quadriceps',
    'Posterior': 'hamstrings',
    'Glúteos': 'glutes',
    'Panturrilha': 'calves',
    'Abdômen': 'abs',
  };

  static const Uuid _uuid = Uuid();
  static final RegExp _combiningMark = RegExp('[̀-ͯ᪰-᫿᷀-᷿⃐-⃿︠-︯]');
  static final RegExp _notSlugChar = RegExp('[^a-z0-9]+');
  static final RegExp _edgeDashes = RegExp(r'^-+|-+$');

  /// `Supino reto` → `supino-reto`; `Leg press 45°` → `leg-press-45`.
  static String exerciseSlug(String name) => unorm
      .nfd(name)
      .replaceAll(_combiningMark, '')
      .toLowerCase()
      .replaceAll(_notSlugChar, '-')
      .replaceAll(_edgeDashes, '');

  /// `d` do modelo 33401: o mesmo exercício tem o mesmo `d` em qualquer
  /// dispositivo, sem guardar estado.
  static String exerciseTemplateD(String name) =>
      _uuid.v5(exerciseNamespace, exerciseSlug(name));

  /// `d` de um treino novo. É gerado uma vez e reaproveitado quando o mesmo
  /// treino é republicado após edição (RN-08).
  static String newRecordD() => _uuid.v4();

  static String exerciseAddress(String pubkey, String exerciseName) =>
      '${NostrKinds.exerciseTemplate}:$pubkey:${exerciseTemplateD(exerciseName)}';

  // ---------------------------------------------------------------- escrita

  UnsignedNostrEvent exerciseTemplate({
    required String pubkey,
    required int createdAt,
    required ExerciseModel exercise,
    required ExerciseEquipment equipment,
  }) {
    final muscle = muscleGroupTags[exercise.muscleGroup];
    return UnsignedNostrEvent(
      pubkey: pubkey,
      createdAt: createdAt,
      kind: NostrKinds.exerciseTemplate,
      content: '',
      tags: [
        ['d', exerciseTemplateD(exercise.name)],
        ['title', exercise.name],
        ['format', 'weight', 'reps', 'rpe', 'set_type'],
        ['format_units', 'kg', 'count', '0-10', 'warmup|normal|drop|failure'],
        ['equipment', equipment.name],
        if (muscle != null) ['t', muscle],
        ['alt', 'Modelo de exercício (NIP-101e): ${exercise.name}'],
      ],
    );
  }

  /// Monta o kind 1301 do treino. Lança [WorkoutEventException] quando o
  /// treino não pode ser publicado.
  UnsignedNostrEvent workoutRecord({
    required String pubkey,
    required int createdAt,
    required String d,
    required WorkoutModel workout,
    required Map<int, ExerciseModel> exercises,
  }) {
    if (workout.sets.isEmpty) {
      throw const WorkoutEventException(
          'Registre pelo menos uma série antes de publicar.');
    }

    final setTags = <List<String>>[];
    final setCounts = <String, int>{};
    for (final set in workout.sets) {
      final exercise = exercises[set.exerciseId];
      if (exercise == null) {
        throw const WorkoutEventException(
            'O treino tem um exercício que não está na biblioteca.');
      }
      setTags.add([
        'exercise',
        exerciseAddress(pubkey, exercise.name),
        relayHint,
        _weight(set.weightKg),
        _reps(set.reps),
        _rpe(set.rpe),
        set.type.apiValue,
      ]);
      setCounts.update(exercise.name, (n) => n + 1, ifAbsent: () => 1);
    }

    final start = '${_noonLocal(workout.date)}';
    final date = formatDateBr(workout.date);
    final summary = setCounts.entries
        .map(
            (e) => '${e.key} (${e.value} ${e.value == 1 ? 'série' : 'séries'})')
        .join(', ');

    return UnsignedNostrEvent(
      pubkey: pubkey,
      createdAt: createdAt,
      kind: NostrKinds.workoutRecord,
      content: '',
      tags: [
        ['d', d],
        ['title', 'Treino de $date'],
        ['type', 'strength'],
        ['start', start],
        ['end', start],
        ['completed', 'true'],
        ...setTags,
        [
          'alt',
          'Registro de treino de $date: $summary. '
              'Volume: ${formatKg(workout.volumeKg)}.',
        ],
      ],
    );
  }

  /// 12:00 do dia no fuso do dispositivo (mini-NIP §2.4).
  static int _noonLocal(DateTime date) =>
      DateTime(date.year, date.month, date.day, 12).millisecondsSinceEpoch ~/
      1000;

  static String _weight(double kg) {
    if (!kg.isFinite ||
        kg < WorkoutLimits.minWeightKg ||
        kg > WorkoutLimits.maxWeightKg) {
      throw WorkoutEventException('Carga deve ficar entre 0 e '
          '${WorkoutLimits.maxWeightKg.toInt()} kg.');
    }
    return _canonical(kg, 2);
  }

  static String _reps(int reps) {
    if (reps < WorkoutLimits.minReps || reps > WorkoutLimits.maxReps) {
      throw const WorkoutEventException(
          'Repetições devem ficar entre ${WorkoutLimits.minReps} e '
          '${WorkoutLimits.maxReps}.');
    }
    return '$reps';
  }

  static String _rpe(double? rpe) {
    if (rpe == null) return '';
    if (!rpe.isFinite || rpe < minRpe || rpe > maxRpe) {
      throw const WorkoutEventException('RPE deve ficar entre 1 e 10.');
    }
    return _canonical(rpe, 1);
  }

  /// Decimal com até [places] casas, sem zero à direita: 80, 82.5, 0.3.
  static String _canonical(double value, int places) {
    final fixed = value.toStringAsFixed(places);
    if (!fixed.contains('.')) return fixed;
    final trimmed = fixed.replaceFirst(RegExp(r'\.?0+$'), '');
    return trimmed == '-0' ? '0' : trimmed;
  }

  // ---------------------------------------------------------------- leitura

  /// Endereço → nome, a partir de modelos 33401 válidos. Havendo versões, a
  /// mais nova vence.
  static Map<String, String> exerciseTitles(Iterable<NostrEvent> templates) {
    final titles = <String, String>{};
    final newest = <String, int>{};
    for (final event in templates) {
      if (event.kind != NostrKinds.exerciseTemplate || !event.isValid) continue;
      final d = event.firstTagValue('d');
      final title = event.firstTagValue('title');
      if (d == null || title == null || title.isEmpty) continue;
      final address = '${NostrKinds.exerciseTemplate}:${event.pubkey}:$d';
      if ((newest[address] ?? -1) >= event.createdAt) continue;
      newest[address] = event.createdAt;
      titles[address] = title;
    }
    return titles;
  }

  /// Lê um kind 1301. Devolve `null` quando o evento deve ser descartado:
  /// kind errado, `id`/assinatura inválidos (RF-51) ou nenhuma série válida.
  static PublishedWorkout? parseWorkoutRecord(
    NostrEvent event, {
    Map<String, String> exerciseTitles = const {},
  }) {
    if (event.kind != NostrKinds.workoutRecord || !event.isValid) return null;

    final sets = <PublishedSet>[];
    for (final tag in event.tags) {
      if (tag.first != 'exercise' || tag.length < 5) continue;
      final reps = int.tryParse(tag[4]);
      final weight = tag[3].isEmpty ? 0.0 : double.tryParse(tag[3]);
      if (reps == null || reps <= 0 || weight == null || !weight.isFinite) {
        continue;
      }
      final rpe = tag.length > 5 ? double.tryParse(tag[5]) : null;
      sets.add(PublishedSet(
        exerciseRef: tag[1],
        weightKg: weight,
        reps: reps,
        rpe: (rpe != null && rpe.isFinite && rpe >= 0 && rpe <= maxRpe)
            ? rpe
            : null,
        type: SetType.fromApi(tag.length > 6 ? tag[6] : null),
      ));
    }
    if (sets.isEmpty) return null;

    final start = int.tryParse(event.firstTagValue('start') ?? '');
    final moment =
        DateTime.fromMillisecondsSinceEpoch((start ?? event.createdAt) * 1000);
    return PublishedWorkout(
      eventId: event.id,
      pubkey: event.pubkey,
      d: event.firstTagValue('d'),
      title: event.firstTagValue('title'),
      createdAt: event.createdAt,
      date: DateTime(moment.year, moment.month, moment.day),
      sets: sets,
      exerciseTitles: exerciseTitles,
    );
  }

  /// Treinos para exibir: um por `id` (RF-24) e, por par `(pubkey, d)`, só a
  /// versão mais nova (RN-08). Mais recentes primeiro.
  static List<PublishedWorkout> latestVersions(
    Iterable<NostrEvent> events, {
    Map<String, String> exerciseTitles = const {},
  }) {
    final seen = <String>{};
    final latest = <String, PublishedWorkout>{};
    for (final event in events) {
      if (!seen.add(event.id)) continue;
      final workout = parseWorkoutRecord(event, exerciseTitles: exerciseTitles);
      if (workout == null) continue;
      final key = '${workout.pubkey}:${workout.d ?? workout.eventId}';
      final current = latest[key];
      if (current == null ||
          workout.createdAt > current.createdAt ||
          (workout.createdAt == current.createdAt &&
              workout.eventId.compareTo(current.eventId) < 0)) {
        latest[key] = workout;
      }
    }
    return latest.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}
