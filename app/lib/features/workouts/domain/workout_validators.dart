// FE-03 — Validação do formulário de séries (funções puras).
//
// Limites do RN-07: carga máxima 1000 kg e repetições máximo 500 — acima
// disso é erro de digitação ou abuso. O servidor também recusa (422); validar
// aqui evita a viagem de ida e volta.
//
// As mensagens são curtas de propósito: aparecem embaixo de campos pequenos.

abstract final class WorkoutLimits {
  static const int minReps = 1;
  static const int maxReps = 500;
  static const double minWeightKg = 0;
  static const double maxWeightKg = 1000;
  static const double minRpe = 0;
  static const double maxRpe = 10;
}

abstract final class WorkoutValidators {
  /// Aceita vírgula ou ponto como separador decimal ("62,5" / "62.5").
  static double? parseDecimal(String? value) {
    final text = value?.trim().replaceAll(',', '.') ?? '';
    return double.tryParse(text);
  }

  static String? reps(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Informe';
    final reps = int.tryParse(text);
    if (reps == null) return 'Inteiro';
    if (reps < WorkoutLimits.minReps || reps > WorkoutLimits.maxReps) {
      return 'De ${WorkoutLimits.minReps} a ${WorkoutLimits.maxReps}';
    }
    return null;
  }

  static String? weight(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Informe';
    final weight = parseDecimal(text);
    if (weight == null) return 'Número';
    if (weight < WorkoutLimits.minWeightKg ||
        weight > WorkoutLimits.maxWeightKg) {
      return 'De 0 a ${WorkoutLimits.maxWeightKg.toInt()}';
    }
    return null;
  }

  /// RPE é opcional: vazio é válido.
  static String? rpe(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final rpe = parseDecimal(text);
    if (rpe == null || rpe < WorkoutLimits.minRpe || rpe > WorkoutLimits.maxRpe) {
      return 'De 0 a ${WorkoutLimits.maxRpe.toInt()}';
    }
    return null;
  }
}
