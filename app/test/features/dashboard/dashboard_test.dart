// Dashboard (RF-41, RF-42): leitura de /stats (RF-54), matriz do mapa de
// calor por semana e a seção "Visão geral" do Início.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlift/core/network/api_client.dart';
import 'package:openlift/core/network/api_exception.dart';
import 'package:openlift/core/theme/app_theme.dart';
import 'package:openlift/features/auth/data/auth_repository.dart';
import 'package:openlift/features/dashboard/data/stats_repository.dart';
import 'package:openlift/features/dashboard/domain/stats_model.dart';
import 'package:openlift/features/dashboard/presentation/dashboard_controller.dart';
import 'package:openlift/features/dashboard/presentation/volume_heatmap_widget.dart';
import 'package:openlift/main.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_stats_repository.dart';

Map<String, Object> _heatmapJson() => {
      'date_from': '2026-11-02',
      'date_to': '2026-11-19',
      'muscle_groups': [
        {'id': 1, 'name': 'Costas'},
        {'id': 2, 'name': 'Peito'},
        {'id': 3, 'name': 'Quadríceps'},
      ],
      'cells': [
        {
          'date': '2026-11-03',
          'muscle_group_id': 2,
          'muscle_group': 'Peito',
          'volume': 1000,
        },
        {
          'date': '2026-11-05',
          'muscle_group_id': 2,
          'muscle_group': 'Peito',
          'volume': 500.5,
        },
        {
          'date': '2026-11-18',
          'muscle_group_id': 1,
          'muscle_group': 'Costas',
          'volume': 800,
        },
      ],
    };

VolumeStats _volume() => VolumeStats(
      weeks: [
        WeekVolume(weekStart: DateTime(2026, 11, 9), volume: 2000, workouts: 2),
        WeekVolume(
            weekStart: DateTime(2026, 11, 16), volume: 2500, workouts: 3),
      ],
      totalVolume: 4500,
      totalWorkouts: 5,
    );

const _groups = [
  MuscleGroupStats(id: 2, name: 'Peito', volume: 3200, sets: 12, sessions: 4),
  MuscleGroupStats(id: 1, name: 'Costas', volume: 800, sets: 3, sessions: 1),
  MuscleGroupStats(id: 3, name: 'Quadríceps', volume: 0, sets: 0, sessions: 0),
];

void main() {
  group('HeatmapData', () {
    test('soma o volume por grupo e semana ISO', () {
      final heatmap = HeatmapData.fromJson(_heatmapJson());

      expect(heatmap.weekStarts, [
        DateTime(2026, 11, 2),
        DateTime(2026, 11, 9),
        DateTime(2026, 11, 16),
      ]);
      final rows = heatmap.weeklyRows();
      expect(rows.map((r) => r.name), ['Peito', 'Costas', 'Quadríceps']);
      expect(rows[0].weekly, [1500.5, 0, 0]);
      expect(rows[1].weekly, [0, 0, 800]);
      expect(rows[2].weekly, [0, 0, 0]);
    });

    test('weekStartOf volta para a segunda-feira', () {
      expect(weekStartOf(DateTime(2026, 11, 19)), DateTime(2026, 11, 16));
      expect(weekStartOf(DateTime(2026, 11, 16)), DateTime(2026, 11, 16));
      expect(weekStartOf(DateTime(2026, 11, 22)), DateTime(2026, 11, 16));
    });

    test('heatColor: vazio sem volume e nível mais quente no máximo', () {
      const empty = Color(0xFF000000);
      expect(heatColor(0, 100, empty), empty);
      expect(heatColor(100, 100, empty), AppTheme.heatScale.last);
      expect(heatColor(1, 100, empty), AppTheme.heatScale.first);
    });

    test('resposta sem cells é fora do contrato', () {
      expect(
        () => HeatmapData.fromJson({'date_from': '2026-11-01'}),
        throwsFormatException,
      );
    });
  });

  group('DashboardData', () {
    test('músculo mais treinado é o primeiro com volume', () {
      final data = DashboardData(
        volume: _volume(),
        muscleGroups: _groups,
        heatmap: HeatmapData.fromJson(_heatmapJson()),
      );
      expect(data.topMuscleGroup?.name, 'Peito');
      expect(data.isEmpty, isFalse);
    });

    test('sem volume não há músculo mais treinado', () {
      final data = DashboardData(
        volume: const VolumeStats(weeks: [], totalVolume: 0, totalWorkouts: 0),
        muscleGroups: const [
          MuscleGroupStats(
              id: 1, name: 'Peito', volume: 0, sets: 0, sessions: 0),
        ],
        heatmap: HeatmapData(
          from: DateTime(2026),
          to: DateTime(2026),
          groups: const {},
          cells: const [],
        ),
      );
      expect(data.topMuscleGroup, isNull);
      expect(data.isEmpty, isTrue);
    });
  });

  group('StatsRepository', () {
    late FakeHttpAdapter adapter;
    late ApiClient client;
    late StatsRepository repository;

    void build(RequestHandler handler) {
      adapter = FakeHttpAdapter(handler);
      final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))
        ..httpClientAdapter = adapter;
      client = ApiClient(storage: MemorySecureStorage(access: 'a'), dio: dio);
      repository = StatsRepository(api: client);
    }

    tearDown(() => client.dispose());

    test('volume manda semanas e a data local', () async {
      build((_) => jsonResponse({
            'weeks': [
              {'week_start': '2026-11-16', 'volume': '2500.00', 'workouts': 3},
            ],
            'total_volume': 2500,
            'total_workouts': 3,
          }));

      final volume = await repository.getVolume(
        until: DateTime(2026, 11, 19),
        weeks: 8,
      );

      final uri = adapter.requests.single.uri;
      expect(uri.path, '/api/v1/stats/volume');
      expect(uri.queryParameters, {'weeks': '8', 'date_to': '2026-11-19'});
      expect(volume.weeks.single.volume, 2500);
      expect(volume.currentWeek?.workouts, 3);
    });

    test('grupos musculares e heatmap usam date_from e date_to', () async {
      build((options) => options.path.endsWith('heatmap')
          ? jsonResponse(_heatmapJson())
          : jsonResponse([
              {
                'muscle_group_id': 2,
                'muscle_group': 'Peito',
                'volume': 3200,
                'sets': 12,
                'sessions': 4,
              },
            ]));

      final groups = await repository.getMuscleGroups(
        from: DateTime(2026, 10, 23),
        to: DateTime(2026, 11, 19),
      );
      final heatmap = await repository.getHeatmap(
        from: DateTime(2026, 11, 2),
        to: DateTime(2026, 11, 19),
      );

      expect(adapter.requests.first.uri.queryParameters, {
        'date_from': '2026-10-23',
        'date_to': '2026-11-19',
      });
      expect(groups.single.sessions, 4);
      expect(heatmap.cells, hasLength(3));
    });

    test('erro da API vira ApiException', () async {
      build((_) => jsonResponse({'detail': 'x', 'code': 'y'}, status: 500));

      await expectLater(
        repository.getVolume(until: DateTime(2026, 11, 19)),
        throwsA(isA<ApiException>()),
      );
    });

    test('resposta fora do contrato vira ApiException', () async {
      build((_) => jsonResponse({'nada': true}));

      await expectLater(
        repository.getHeatmap(
          from: DateTime(2026, 11, 2),
          to: DateTime(2026, 11, 19),
        ),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('Início', () {
    Future<void> pump(WidgetTester tester, FakeStatsRepository stats) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider
                .overrideWithValue(FakeAuthRepository(session: true)),
            statsRepositoryProvider.overrideWithValue(stats),
            dashboardTodayProvider
                .overrideWithValue(() => DateTime(2026, 11, 19, 21)),
          ],
          child: const OpenLiftApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('pede as janelas de 8 semanas e 28 dias até hoje',
        (tester) async {
      final stats = FakeStatsRepository();
      await pump(tester, stats);

      expect(stats.calls, [
        'volume weeks=8 until=2026-11-19T00:00:00.000',
        'groups from=2026-10-23T00:00:00.000 to=2026-11-19T00:00:00.000',
        'heatmap from=2026-09-28T00:00:00.000 to=2026-11-19T00:00:00.000',
      ]);
    });

    testWidgets('sem treinos convida a registrar o primeiro', (tester) async {
      await pump(tester, FakeStatsRepository());

      expect(
        find.textContaining('Registre seu primeiro treino'),
        findsOneWidget,
      );
      expect(find.text('Volume semanal'), findsNothing);
    });

    testWidgets('mostra resumo, volume, mapa de calor e frequência',
        (tester) async {
      await pump(
        tester,
        FakeStatsRepository(
          volume: _volume(),
          muscleGroups: _groups,
          heatmap: HeatmapData.fromJson(_heatmapJson()),
        ),
      );

      expect(find.text('Volume da semana'), findsOneWidget);
      expect(find.text('2.500 kg'), findsOneWidget);
      expect(find.text('+25% vs. semana passada'), findsOneWidget);
      expect(find.text('Músculo mais treinado'), findsOneWidget);
      expect(find.text('Volume semanal'), findsOneWidget);
      expect(find.text('Mapa de calor por grupo muscular'), findsOneWidget);
      expect(find.text('Frequência por grupo muscular'), findsOneWidget);
      expect(find.text('4 dias'), findsOneWidget);
      expect(find.text('1 dia'), findsOneWidget);
      // Peito tem o maior volume no mapa: célula mais quente na 1ª semana.
      final hottest =
          tester.widget<Container>(find.byKey(const ValueKey('heat-2-0')));
      expect(
        (hottest.decoration! as BoxDecoration).color,
        AppTheme.heatScale.last,
      );
      expect(find.byIcon(Icons.local_fire_department_rounded), findsWidgets);
    });

    testWidgets('falha mostra a mensagem e tenta de novo', (tester) async {
      final stats = FakeStatsRepository()
        ..error = const ApiException('Sem conexão com o servidor.');
      await pump(tester, stats);

      expect(find.text('Sem conexão com o servidor.'), findsOneWidget);

      stats.error = null;
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();

      expect(find.text('Sem conexão com o servidor.'), findsNothing);
      expect(
        find.textContaining('Registre seu primeiro treino'),
        findsOneWidget,
      );
    });
  });
}
