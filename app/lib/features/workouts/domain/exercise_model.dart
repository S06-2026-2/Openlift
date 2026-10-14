// FE-03 — Exercício da biblioteca (nome + grupo muscular), usado no seletor
// do formulário e na taxonomia do dashboard/heatmap.
//
// Contrato esperado (BE-03): GET /exercises -> [{id, name, muscle_group}],
// onde `muscle_group` pode ser texto ("Peito") ou objeto ({id, name}).

import '../../../core/utils/json_utils.dart';

class ExerciseModel {
  const ExerciseModel({
    required this.id,
    required this.name,
    required this.muscleGroup,
  });

  /// Grupo exibido quando a API não informa um.
  static const String fallbackGroup = 'Outros';

  final int id;
  final String name;
  final String muscleGroup;

  factory ExerciseModel.fromJson(Map<String, dynamic> json) {
    final group = json['muscle_group'];
    String? groupName;
    if (group is String) {
      groupName = group;
    } else if (group is Map) {
      final name = group['name'];
      if (name is String) groupName = name;
    }
    final id = asInt(json['id']);
    final name = json['name'];
    if (id == null || name is! String) {
      throw const FormatException('Exercício inválido');
    }
    return ExerciseModel(
      id: id,
      name: name,
      muscleGroup: (groupName == null || groupName.trim().isEmpty)
          ? fallbackGroup
          : groupName,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'muscle_group': muscleGroup,
      };

  @override
  bool operator ==(Object other) =>
      other is ExerciseModel && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}
