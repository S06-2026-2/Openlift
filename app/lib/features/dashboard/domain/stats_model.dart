// Modelos do dashboard (RF-40 a RF-43): volume semanal e mensal, treinos no
// mês, sequência (streak), volume e frequência por grupo muscular e a matriz
// do mapa de calor. Contrato de /stats (RF-54).
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

/// Agrupamento do volume e do mapa de calor: semana ISO ou mês.
enum StatsScale { week, month }

/// Volume de uma semana ISO (começa na segunda) ou de um mês.
class PeriodVolume {
  const PeriodVolume({
    required this.periodStart,
    required this.volume,
    required this.workouts,
  });

  factory PeriodVolume.fromJson(Map<String, dynamic> json) => PeriodVolume(
        periodStart: _date(json['period_start']),
        volume: asDouble(json['volume']) ?? 0,
        workouts: asInt(json['workouts']) ?? 0,
      );

  final DateTime periodStart;
  final double volume;
  final int workouts;
}

class VolumeStats {
  const VolumeStats({
    required this.scale,
    required this.periods,
    required this.totalVolume,
    required this.totalWorkouts,
    this.workoutsThisMonth = 0,
    this.streakDays = 0,
  });

  /// Sem treino nenhum (usado como valor inicial e nos testes).
  const VolumeStats.empty([this.scale = StatsScale.week])
      : periods = const [],
        totalVolume = 0,
        totalWorkouts = 0,
        workoutsThisMonth = 0,
        streakDays = 0;

  factory VolumeStats.fromJson(Object? data) {
    final json = _map(data);
    return VolumeStats(
      scale: json['group_by'] == 'month' ? StatsScale.month : StatsScale.week,
      periods: [
        for (final item in _list(json['periods']))
          PeriodVolume.fromJson(_map(item)),
      ],
      totalVolume: asDouble(json['total_volume']) ?? 0,
      totalWorkouts: asInt(json['total_workouts']) ?? 0,
      workoutsThisMonth: asInt(json['workouts_this_month']) ?? 0,
      streakDays: asInt(json['streak_days']) ?? 0,
    );
  }

  final StatsScale scale;

  /// Do período mais antigo para o mais novo.
  final List<PeriodVolume> periods;
  final double totalVolume;
  final int totalWorkouts;

  /// Treinos do mês corrente, até hoje.
  final int workoutsThisMonth;

  /// Dias seguidos com treino (streak).
  final int streakDays;

  PeriodVolume? get current => periods.isEmpty ? null : periods.last;

  PeriodVolume? get previous =>
      periods.length < 2 ? null : periods[periods.length - 2];
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

/// Uma linha do mapa de calor: o volume do grupo em cada coluna (semana ou
/// mês).
class HeatmapRow {
  const HeatmapRow({
    required this.muscleGroupId,
    required this.name,
    required this.values,
  });

  final int muscleGroupId;
  final String name;
  final List<double> values;

  double get total => values.fold(0, (sum, v) => sum + v);
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

  /// Início de cada coluna: as últimas [count] semanas (segundas-feiras) ou
  /// meses (dia 1) até [to], sem começar antes de [from].
  List<DateTime> columns(StatsScale scale, int count) {
    final last = scale == StatsScale.week ? weekStartOf(to) : monthStartOf(to);
    final first =
        scale == StatsScale.week ? weekStartOf(from) : monthStartOf(from);
    final starts = <DateTime>[];
    for (var i = count - 1; i >= 0; i--) {
      final start = scale == StatsScale.week
          ? DateTime(last.year, last.month, last.day - 7 * i)
          : DateTime(last.year, last.month - i);
      if (!start.isBefore(first)) starts.add(start);
    }
    return starts;
  }

  /// Linhas grupo × coluna, do grupo mais treinado para o menos (empate em
  /// ordem alfabética). Grupos sem volume no período ficam no fim.
  List<HeatmapRow> rows(StatsScale scale, List<DateTime> columns) {
    final index = {
      for (var i = 0; i < columns.length; i++) columns[i]: i,
    };
    final volumes = {
      for (final id in groups.keys) id: List<double>.filled(columns.length, 0),
    };
    for (final cell in cells) {
      final key = scale == StatsScale.week
          ? weekStartOf(cell.date)
          : monthStartOf(cell.date);
      final column = index[key];
      final row = volumes[cell.muscleGroupId];
      if (column == null || row == null) continue;
      row[column] += cell.volume;
    }
    final rows = [
      for (final entry in volumes.entries)
        HeatmapRow(
          muscleGroupId: entry.key,
          name: groups[entry.key]!,
          values: entry.value,
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

/// Dia 1 do mês de [day].
DateTime monthStartOf(DateTime day) => DateTime(day.year, day.month);

/// Tudo o que o dashboard mostra, carregado de uma vez.
class DashboardData {
  const DashboardData({
    required this.weekly,
    required this.monthly,
    required this.muscleGroups,
    required this.heatmap,
  });

  /// Volume por semana, com treinos no mês e sequência.
  final VolumeStats weekly;

  /// Volume por mês.
  final VolumeStats monthly;

  /// Do mais treinado para o menos.
  final List<MuscleGroupStats> muscleGroups;
  final HeatmapData heatmap;

  bool get isEmpty =>
      weekly.totalWorkouts == 0 &&
      monthly.totalWorkouts == 0 &&
      heatmap.cells.isEmpty;

  /// Grupo com mais volume no período, ou `null` sem treino.
  MuscleGroupStats? get topMuscleGroup {
    if (muscleGroups.isEmpty || muscleGroups.first.volume <= 0) return null;
    return muscleGroups.first;
  }
}
