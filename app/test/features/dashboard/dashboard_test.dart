// Dashboard (RF-40 a RF-43): leitura de /stats (RF-54), mapa de calor por
// semana e por mês e a seção "Visão geral" do Início, com treinos no mês,
// sequência e os seletores semana/mês.

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
      'date_from': '2026-09-01',
      'date_to': '2026-11-19',
      'muscle_groups': [
        {'id': 1, 'name': 'Costas'},
        {'id': 2, 'name': 'Peito'},
        {'id': 3, 'name': 'Quadríceps'},
      ],
      'cells': [
        {
          'date': '2026-09-15',
          'muscle_group_id': 3,
          'muscle_group': 'Quadríceps',
          'volume': 5000,
        },
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

VolumeStats _weekly() => VolumeStats(
      scale: StatsScale.week,
      periods: [
        PeriodVolume(
          periodStart: DateTime(2026, 11, 9),
          volume: 2000,
          workouts: 2,
        ),
        PeriodVolume(
          periodStart: DateTime(2026, 11, 16),
          volume: 2500,
          workouts: 3,
        ),
      ],
      totalVolume: 4500,
      totalWorkouts: 5,
      workoutsThisMonth: 6,
      streakDays: 3,
    );

VolumeStats _monthly() => VolumeStats(
      scale: StatsScale.month,
      periods: [
        PeriodVolume(
          periodStart: DateTime(2026, 10),
          volume: 9000,
          workouts: 9,
        ),
        PeriodVolume(
          periodStart: DateTime(2026, 11),
          volume: 7000,
          workouts: 6,
        ),
      ],
      totalVolume: 16000,
      totalWorkouts: 15,
    );

const _groups = [
  MuscleGroupStats(id: 2, name: 'Peito', volume: 3200, sets: 12, sessions: 4),
  MuscleGroupStats(id: 1, name: 'Costas', volume: 800, sets: 3, sessions: 1),
  MuscleGroupStats(id: 3, name: 'Quadríceps', volume: 0, sets: 0, sessions: 0),
];

void main() {
  group('HeatmapData', () {
    final heatmap = HeatmapData.fromJson(_heatmapJson());

    test('colunas: últimas N semanas ou meses, sem passar do período', () {
      expect(heatmap.columns(StatsScale.week, 3), [
        DateTime(2026, 11, 2),
        DateTime(2026, 11, 9),
        DateTime(2026, 11, 16),
      ]);
      expect(heatmap.columns(StatsScale.month, 6), [
        DateTime(2026, 9),
        DateTime(2026, 10),
        DateTime(2026, 11),
      ]);
    });

    test('soma o volume por grupo e semana ISO', () {
      final columns = heatmap.columns(StatsScale.week, 3);
      final rows = heatmap.rows(StatsScale.week, columns);

      expect(rows.map((r) => r.name), ['Peito', 'Costas', 'Quadríceps']);
      expect(rows[0].values, [1500.5, 0, 0]);
      expect(rows[1].values, [0, 0, 800]);
      // O treino de setembro fica fora das 3 semanas.
      expect(rows[2].values, [0, 0, 0]);
    });

    test('soma o volume por grupo e mês', () {
      final columns = heatmap.columns(StatsScale.month, 3);
      final rows = heatmap.rows(StatsScale.month, columns);

      expect(rows.map((r) => r.name), ['Quadríceps', 'Peito', 'Costas']);
      expect(rows[0].values, [5000, 0, 0]);
      expect(rows[1].values, [0, 0, 1500.5]);
      expect(rows[2].values, [0, 0, 800]);
    });

    test('meses atravessam a virada do ano', () {
      final data = HeatmapData(
        from: DateTime(2026, 11),
        to: DateTime(2027, 1, 10),
        groups: const {},
        cells: const [],
      );
      expect(data.columns(StatsScale.month, 6), [
        DateTime(2026, 11),
        DateTime(2026, 12),
        DateTime(2027, 1),
      ]);
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
        weekly: _weekly(),
        monthly: _monthly(),
        muscleGroups: _groups,
        heatmap: HeatmapData.fromJson(_heatmapJson()),
      );
      expect(data.topMuscleGroup?.name, 'Peito');
      expect(data.isEmpty, isFalse);
    });

    test('sem volume não há músculo mais treinado', () {
      final data = DashboardData(
        weekly: const VolumeStats.empty(),
        monthly: const VolumeStats.empty(StatsScale.month),
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

    test('volume manda agrupamento, períodos e a data local', () async {
      build((_) => jsonResponse({
            'group_by': 'month',
            'periods': [
              {
                'period_start': '2026-11-01',
                'volume': '2500.00',
                'workouts': 3
              },
            ],
            'total_volume': 2500,
            'total_workouts': 3,
            'workouts_this_month': 3,
            'streak_days': 2,
          }));

      final volume = await repository.getVolume(
        until: DateTime(2026, 11, 19),
        scale: StatsScale.month,
        periods: 6,
      );

      final uri = adapter.requests.single.uri;
      expect(uri.path, '/api/v1/stats/volume');
      expect(uri.queryParameters, {
        'group_by': 'month',
        'periods': '6',
        'date_to': '2026-11-19',
      });
      expect(volume.scale, StatsScale.month);
      expect(volume.periods.single.volume, 2500);
      expect(volume.current?.workouts, 3);
      expect(volume.workoutsThisMonth, 3);
      expect(volume.streakDays, 2);
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
        from: DateTime(2026, 6),
        to: DateTime(2026, 11, 19),
      );

      expect(adapter.requests.first.uri.queryParameters, {
        'date_from': '2026-10-23',
        'date_to': '2026-11-19',
      });
      expect(groups.single.sessions, 4);
      expect(heatmap.cells, hasLength(4));
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
      tester.view.physicalSize = const Size(800, 2800);
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

    FakeStatsRepository full() => FakeStatsRepository(
          volume: _weekly(),
          monthly: _monthly(),
          muscleGroups: _groups,
          heatmap: HeatmapData.fromJson(_heatmapJson()),
        );

    testWidgets('pede semanas, meses, 28 dias e 6 meses de mapa de calor',
        (tester) async {
      final stats = FakeStatsRepository();
      await pump(tester, stats);

      expect(stats.calls, [
        'volume week periods=8 until=2026-11-19T00:00:00.000',
        'volume month periods=6 until=2026-11-19T00:00:00.000',
        'groups from=2026-10-23T00:00:00.000 to=2026-11-19T00:00:00.000',
        'heatmap from=2026-06-01T00:00:00.000 to=2026-11-19T00:00:00.000',
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

    testWidgets('mostra os 4 cards, volume, mapa de calor e frequência',
        (tester) async {
      await pump(tester, full());

      expect(find.text('Volume da semana'), findsOneWidget);
      expect(find.text('2.500 kg'), findsOneWidget);
      expect(find.text('+25% vs. semana passada'), findsOneWidget);
      expect(find.text('Treinos no mês'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('Sequência'), findsOneWidget);
      expect(find.text('3 dias'), findsOneWidget);
      expect(find.text('Músculo mais treinado'), findsOneWidget);
      expect(find.text('Volume semanal'), findsOneWidget);
      expect(find.text('Mapa de calor por grupo muscular'), findsOneWidget);
      expect(find.text('Frequência por grupo muscular'), findsOneWidget);
      expect(find.text('4 dias'), findsOneWidget);
      expect(find.text('1 dia'), findsOneWidget);
    });

    testWidgets('volume troca entre semanal e mensal', (tester) async {
      await pump(tester, full());

      await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('volume-scale')),
        matching: find.text('Meses'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Volume mensal'), findsOneWidget);
      expect(find.text('Volume semanal'), findsNothing);
      expect(find.text('nov'), findsWidgets);
    });

    testWidgets('mapa de calor troca entre semanas e meses', (tester) async {
      await pump(tester, full());

      // Por semana (8 semanas): Peito é o mais quente na semana de 02/11.
      expect(find.textContaining('últimas 8 semanas'), findsOneWidget);
      final weekCell = tester.widget<Container>(
        find.byKey(const ValueKey('heat-2-5')),
      );
      expect(
        (weekCell.decoration! as BoxDecoration).color,
        AppTheme.heatScale.last,
      );

      await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('heatmap-scale')),
        matching: find.text('Meses'),
      ));
      await tester.pumpAndSettle();

      // Por mês (setembro a novembro): Quadríceps em setembro é o máximo.
      expect(find.textContaining('últimos 3 meses'), findsOneWidget);
      final monthCell = tester.widget<Container>(
        find.byKey(const ValueKey('heat-3-0')),
      );
      expect(
        (monthCell.decoration! as BoxDecoration).color,
        AppTheme.heatScale.last,
      );
    });

    testWidgets('sequência zerada convida a treinar hoje', (tester) async {
      final stats = full()
        ..volume = VolumeStats(
          scale: StatsScale.week,
          periods: _weekly().periods,
          totalVolume: 4500,
          totalWorkouts: 5,
        );
      await pump(tester, stats);

      // "0 dias" também aparece na frequência (Quadríceps).
      expect(find.text('0 dias'), findsNWidgets(2));
      expect(find.text('Treine hoje para começar'), findsOneWidget);
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
