// NOSTR-03 — Treino lido de um evento kind 1301 (meu ou de outra pessoa).
//
// Diferente do WorkoutModel, não tem id de banco nem exerciseId: o exercício
// é o endereço do modelo 33401 (`33401:<pubkey>:<d>`), e o nome vem do modelo
// quando ele foi encontrado.

import 'dart:math';

import '../../workouts/domain/set_model.dart';

class PublishedSet {
  const PublishedSet({
    required this.exerciseRef,
    required this.weightKg,
    required this.reps,
    this.rpe,
    this.type = SetType.normal,
  });

  /// Endereço do modelo de exercício (`33401:<pubkey>:<d>`).
  final String exerciseRef;

  /// Em kg (RN-09). Pode ser negativo em exercício assistido de terceiros.
  final double weightKg;
  final int reps;
  final double? rpe;
  final SetType type;

  /// RN-03: aquecimento fica fora; carga negativa (assistido) conta 0.
  double get volumeKg => type == SetType.warmup ? 0 : max(0.0, weightKg) * reps;
}

class PublishedWorkout {
  const PublishedWorkout({
    required this.eventId,
    required this.pubkey,
    required this.createdAt,
    required this.date,
    required this.sets,
    this.d,
    this.title,
    this.exerciseTitles = const {},
  });

  static const String unknownExercise = 'Exercício desconhecido';

  final String eventId;
  final String pubkey;

  /// Identificador estável do treino entre versões (RN-08).
  final String? d;
  final String? title;

  /// `created_at` do evento, em segundos Unix.
  final int createdAt;

  /// Dia do treino (tag `start`, ou `created_at` quando não há `start`).
  final DateTime date;
  final List<PublishedSet> sets;

  /// Endereço do modelo 33401 → nome do exercício.
  final Map<String, String> exerciseTitles;

  double get volumeKg => sets.fold(0, (total, s) => total + s.volumeKg);

  /// RN-07: série acima de 1000 kg ou 500 repetições é erro ou abuso. O
  /// treino é exibido, mas não entra em ranking nem agregação.
  bool get isPlausible =>
      sets.every((s) => s.weightKg <= 1000 && s.reps <= 500);

  String exerciseName(String ref) => exerciseTitles[ref] ?? unknownExercise;

  /// Nomes dos exercícios, na ordem da primeira série de cada um.
  List<String> get exerciseNames {
    final seen = <String>{};
    return [
      for (final set in sets)
        if (seen.add(set.exerciseRef)) exerciseName(set.exerciseRef),
    ];
  }
}
