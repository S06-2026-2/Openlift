// FE-03 — Um treino: data + séries (planas, cada uma com seu exercício).
//
// Contrato (WorkoutIn/WorkoutOut do backend):
//   { id, date: "yyyy-MM-dd", created_at, visibility, publish_status, d_tag,
//     sets: [...] }
//
// FE-05: `visibility`, `publishStatus` e `dTag` só mudam pelas rotas de
// publicação; o corpo de POST/PATCH não os envia.

import '../../../core/utils/json_utils.dart';
import 'set_model.dart';

/// RF-21: só ida. Um treino publicado não volta a ser privado.
enum WorkoutVisibility {
  private,
  published;

  static WorkoutVisibility fromApi(Object? value) =>
      value == 'published' ? published : private;
}

/// RF-25: status da publicação no NOSTR.
enum PublishStatus {
  /// Nunca publicado (só no OpenLift).
  local,

  /// Pelo menos um relay aceitou o evento.
  published,

  /// A última tentativa não chegou a nenhum relay.
  failed;

  static PublishStatus fromApi(Object? value) => switch (value) {
        'published' => published,
        'failed' => failed,
        _ => local,
      };
}

class WorkoutModel {
  const WorkoutModel({
    this.id,
    required this.date,
    this.sets = const [],
    this.createdAt,
    this.visibility = WorkoutVisibility.private,
    this.publishStatus = PublishStatus.local,
    this.dTag,
  });

  final int? id;
  final DateTime date;
  final List<SetModel> sets;
  final DateTime? createdAt;

  final WorkoutVisibility visibility;
  final PublishStatus publishStatus;

  /// `d` do evento kind 1301, fixo entre versões (RN-08). `null` até a 1ª
  /// publicação aceita.
  final String? dTag;

  bool get isPublished => visibility == WorkoutVisibility.published;

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
    final dTag = json['d_tag'];
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
      visibility: WorkoutVisibility.fromApi(json['visibility']),
      publishStatus: PublishStatus.fromApi(json['publish_status']),
      dTag: dTag is String ? dTag : null,
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
      visibility: visibility,
      publishStatus: publishStatus,
      dTag: dTag,
    );
  }
}
