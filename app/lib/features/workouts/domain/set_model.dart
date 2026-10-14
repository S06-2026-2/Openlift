// FE-03 — Uma série dentro de um treino (exercício, reps, carga em kg, RPE
// opcional e tipo).
//
// Contrato (SetIn/SetOut do backend): exercise_id, reps, weight_kg, rpe.
// `set_type` (aquecimento/normal/falha — RF-13) ainda NÃO existe no backend:
// é enviado assim mesmo (o Pydantic ignora campo extra) e, quando a API não
// devolve, a série é lida como `normal`.

import '../../../core/utils/json_utils.dart';

enum SetType {
  warmup('warmup', 'Aquecimento', 'Aq.'),
  normal('normal', 'Normal', 'Norm'),
  failure('failure', 'Falha', 'Falha');

  const SetType(this.apiValue, this.label, this.shortLabel);

  final String apiValue;
  final String label;
  final String shortLabel;

  static SetType fromApi(Object? value) {
    for (final type in values) {
      if (type.apiValue == value) return type;
    }
    return SetType.normal;
  }
}

class SetModel {
  const SetModel({
    this.id,
    required this.exerciseId,
    required this.reps,
    required this.weightKg,
    this.rpe,
    this.type = SetType.normal,
  });

  final int? id;
  final int exerciseId;
  final int reps;

  /// Carga sempre em kg (RN-09).
  final double weightKg;
  final double? rpe;
  final SetType type;

  /// RN-02/RN-03: aquecimento não conta para volume nem PR.
  bool get countsForVolume => type != SetType.warmup;

  /// Carga × repetições.
  double get volumeKg => weightKg * reps;

  factory SetModel.fromJson(Map<String, dynamic> json) {
    final exerciseId = asInt(json['exercise_id']);
    final reps = asInt(json['reps']);
    final weight = asDouble(json['weight_kg']);
    if (exerciseId == null || reps == null || weight == null) {
      throw const FormatException('Série inválida');
    }
    return SetModel(
      id: asInt(json['id']),
      exerciseId: exerciseId,
      reps: reps,
      weightKg: weight,
      rpe: asDouble(json['rpe']),
      type: SetType.fromApi(json['set_type']),
    );
  }

  /// Corpo enviado à API (sem `id`: o servidor decide).
  Map<String, dynamic> toJson() => {
        'exercise_id': exerciseId,
        'reps': reps,
        'weight_kg': weightKg,
        'rpe': rpe,
        'set_type': type.apiValue,
      };

  SetModel copyWith({
    int? exerciseId,
    int? reps,
    double? weightKg,
    double? rpe,
    bool clearRpe = false,
    SetType? type,
  }) {
    return SetModel(
      id: id,
      exerciseId: exerciseId ?? this.exerciseId,
      reps: reps ?? this.reps,
      weightKg: weightKg ?? this.weightKg,
      rpe: clearRpe ? null : (rpe ?? this.rpe),
      type: type ?? this.type,
    );
  }
}
