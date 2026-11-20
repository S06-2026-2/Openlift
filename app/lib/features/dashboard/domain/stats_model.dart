// Modelos do dashboard (RF-41, RF-42): volume semanal, volume e frequência
// por grupo muscular e a matriz do mapa de calor. Contrato de /stats (RF-54).
//
// Volume = Σ carga × repetições sem aquecimento (RN-03), calculado na API.

import '../../../core/utils/json_utils.dart';

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  throw const FormatException('Objeto esperado');
}

List<Object?> _list(Object? value) {
  if (value is List) return value;
  throw const FormatException('Lista esperada');
}

DateTime _date(Object? value) =>
    parseApiDate(value) ?? (throw const FormatException('Data inválida'));

int _int(Object? value) =>
    asInt(value) ?? (throw const FormatException('Número esperado'));

/// Volume de uma semana ISO (começa na segunda).
class WeekVolume {
  const WeekVolume({
    required this.weekStart,
    required this.volume,
    required this.workouts,
  });

  factory WeekVolume.fromJson(Map<String, dynamic> json) => WeekVolume(
        weekStart: _date(json['week_start']),
        volume: asDouble(json['volume']) ?? 0,
        workouts: asInt(json['workouts']) ?? 0,
      );

  final DateTime weekStart;
  final double volume;
  final int workouts;
}

class VolumeStats {
  const VolumeStats({
    required this.weeks,
    required this.totalVolume,
    required this.totalWorkouts,
  });

  factory VolumeStats.fromJson(Object? data) {
    final json = _map(data);
    return VolumeStats(
      weeks: [
        for (final item in _list(json['weeks']))
          WeekVolume.fromJson(_map(item)),
      ],
      totalVolume: asDouble(json['total_volume']) ?? 0,
      totalWorkouts: asInt(json['total_workouts']) ?? 0,
    );
  }

  /// Semanas da mais antiga para a mais nova.
  final List<WeekVolume> weeks;
  final double totalVolume;
  final int totalWorkouts;

  WeekVolume? get currentWeek => weeks.isEmpty ? null : weeks.last;

  WeekVolume? get previousWeek =>
      weeks.length < 2 ? null : weeks[weeks.length - 2];
}

/// Volume e frequência de um grupo muscular no período.
class MuscleGroupStats {
  const MuscleGroupStats({
    required this.id,
    required this.name,
    required this.volume,
    required this.sets,
    required this.sessions,
  });

  factory MuscleGroupStats.fromJson(Map<String, dynamic> json) =>
      MuscleGroupStats(
        id: _int(json['muscle_group_id']),
        name: json['muscle_group'] as String,
        volume: asDouble(json['volume']) ?? 0,
        sets: asInt(json['sets']) ?? 0,
        sessions: asInt(json['sessions']) ?? 0,
      );

  final int id;
  final String name;
  final double volume;
  final int sets;

  /// Dias diferentes em que o grupo foi treinado.
  final int sessions;
}

class HeatmapCell {
  const HeatmapCell({
    required this.date,
    required this.muscleGroupId,
    required this.volume,
  });

  factory HeatmapCell.fromJson(Map<String, dynamic> json) => HeatmapCell(
        date: _date(json['date']),
        muscleGroupId: _int(json['muscle_group_id']),
        volume: asDouble(json['volume']) ?? 0,
      );

  final DateTime date;
  final int muscleGroupId;
  final double volume;
}

/// Uma linha do mapa de calor: o volume do grupo em cada semana.
class HeatmapRow {
  const HeatmapRow({
    required this.muscleGroupId,
    required this.name,
    required this.weekly,
  });

  final int muscleGroupId;
  final String name;
  final List<double> weekly;

  double get total => weekly.fold(0, (sum, v) => sum + v);
}

class HeatmapData {
  const HeatmapData({
    required this.from,
    required this.to,
    required this.groups,
    required this.cells,
  });

  factory HeatmapData.fromJson(Object? data) {
    final json = _map(data);
    return HeatmapData(
      from: _date(json['date_from']),
      to: _date(json['date_to']),
      groups: {
        for (final item in _list(json['muscle_groups']))
          _int(_map(item)['id']): _map(item)['name'] as String,
      },
      cells: [
        for (final item in _list(json['cells']))
          HeatmapCell.fromJson(_map(item)),
      ],
    );
  }

  final DateTime from;
  final DateTime to;

  /// id → nome de todos os grupos musculares.
  final Map<int, String> groups;
  final List<HeatmapCell> cells;

  /// Segundas-feiras das semanas cobertas pelo período, em ordem.
  List<DateTime> get weekStarts {
    final first = weekStartOf(from);
    final last = weekStartOf(to);
    return [
      for (var week = first;
          !week.isAfter(last);
          week = DateTime(week.year, week.month, week.day + 7))
        week,
    ];
  }

  /// Linhas grupo × semana, do grupo mais treinado para o menos (empate em
  /// ordem alfabética). Grupos sem volume no período ficam no fim.
  List<HeatmapRow> weeklyRows() {
    final weeks = weekStarts;
    final index = {
      for (var i = 0; i < weeks.length; i++) weeks[i]: i,
    };
    final volumes = {
      for (final id in groups.keys) id: List<double>.filled(weeks.length, 0),
    };
    for (final cell in cells) {
      final column = index[weekStartOf(cell.date)];
      final row = volumes[cell.muscleGroupId];
      if (column == null || row == null) continue;
      row[column] += cell.volume;
    }
    final rows = [
      for (final entry in volumes.entries)
        HeatmapRow(
          muscleGroupId: entry.key,
          name: groups[entry.key]!,
          weekly: entry.value,
        ),
    ];
    rows.sort((a, b) {
      final byTotal = b.total.compareTo(a.total);
      return byTotal != 0 ? byTotal : a.name.compareTo(b.name);
    });
    return rows;
  }
}

/// Segunda-feira da semana de [day], à meia-noite.
DateTime weekStartOf(DateTime day) =>
    DateTime(day.year, day.month, day.day - (day.weekday - DateTime.monday));

/// Tudo o que o dashboard mostra, carregado de uma vez.
class DashboardData {
  const DashboardData({
    required this.volume,
    required this.muscleGroups,
    required this.heatmap,
  });

  final VolumeStats volume;

  /// Do mais treinado para o menos.
  final List<MuscleGroupStats> muscleGroups;
  final HeatmapData heatmap;

  bool get isEmpty => volume.totalWorkouts == 0 && heatmap.cells.isEmpty;

  /// Grupo com mais volume no período, ou `null` sem treino.
  MuscleGroupStats? get topMuscleGroup {
    if (muscleGroups.isEmpty || muscleGroups.first.volume <= 0) return null;
    return muscleGroups.first;
  }
}
