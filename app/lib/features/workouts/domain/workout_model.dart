// FE-03 — Um treino: data + séries (planas, cada uma com seu exercício).
//
// Contrato (WorkoutIn/WorkoutOut do backend):
//   { id, date: "yyyy-MM-dd", created_at, shared_event_id, sets: [...] }

import '../../../core/utils/json_utils.dart';
import 'set_model.dart';

class WorkoutModel {
  const WorkoutModel({
    this.id,
    required this.date,
    this.sets = const [],
    this.createdAt,
    this.sharedEventId,
  });

  final int? id;
  final DateTime date;
  final List<SetModel> sets;
  final DateTime? createdAt;

  // TODO(Sprint 4): preenchido quando o treino é publicado no NOSTR (kind 1301).
  final String? sharedEventId;

  /// RN-03: volume = Σ carga × repetições, sem séries de aquecimento.
  double get volumeKg => sets
      .where((s) => s.countsForVolume)
      .fold<double>(0, (total, s) => total + s.volumeKg);

  /// IDs de exercício distintos, na ordem em que aparecem.
  List<int> get exerciseIds {
    final seen = <int>{};
    return [
      for (final set in sets)
        if (seen.add(set.exerciseId)) set.exerciseId,
    ];
  }

  factory WorkoutModel.fromJson(Map<String, dynamic> json) {
    final date = parseApiDate(json['date']);
    if (date == null) throw const FormatException('Treino sem data');
    final rawSets = json['sets'];
    return WorkoutModel(
      id: asInt(json['id']),
      date: date,
      sets: [
        if (rawSets is List)
          for (final raw in rawSets)
            if (raw is Map<String, dynamic>) SetModel.fromJson(raw),
      ],
      createdAt: json['created_at'] is String
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      sharedEventId: json['shared_event_id'] as String?,
    );
  }

  /// Corpo de POST/PATCH /workouts.
  Map<String, dynamic> toJson() => {
        'date': toApiDate(date),
        'sets': [for (final set in sets) set.toJson()],
      };

  WorkoutModel copyWith({DateTime? date, List<SetModel>? sets}) {
    return WorkoutModel(
      id: id,
      date: date ?? this.date,
      sets: sets ?? this.sets,
      createdAt: createdAt,
      sharedEventId: sharedEventId,
    );
  }
}
