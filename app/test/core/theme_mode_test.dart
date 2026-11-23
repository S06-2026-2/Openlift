// Tema claro/escuro escolhido pela pessoa: segue o sistema até a escolha,
// troca pelo botão e volta salvo na próxima abertura.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlift/core/theme/app_theme.dart';
import 'package:openlift/core/theme/theme_mode_controller.dart';
import 'package:openlift/features/auth/data/auth_repository.dart';
import 'package:openlift/features/dashboard/data/stats_repository.dart';
import 'package:openlift/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_auth_repository.dart';
import '../helpers/fake_stats_repository.dart';

class _MemoryThemeStore implements ThemePreferenceStore {
  _MemoryThemeStore([this.saved]);

  ThemeMode? saved;
  bool fail = false;

  @override
  Future<ThemeMode?> load() async {
    if (fail) throw StateError('sem armazenamento');
    return saved;
  }

  @override
  Future<void> save(ThemeMode mode) async {
    if (fail) throw StateError('sem armazenamento');
    saved = mode;
  }
}

Future<void> _pump(WidgetTester tester, _MemoryThemeStore store) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider
            .overrideWithValue(FakeAuthRepository(session: true)),
        statsRepositoryProvider.overrideWithValue(FakeStatsRepository()),
        themePreferenceStoreProvider.overrideWithValue(store),
      ],
      child: const OpenLiftApp(),
    ),
  );
  await tester.pumpAndSettle();
}

ThemeMode _mode(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

void main() {
  testWidgets('sem escolha salva, segue o sistema', (tester) async {
    await _pump(tester, _MemoryThemeStore());

    expect(_mode(tester), ThemeMode.system);
  });

  testWidgets('o botão do Início troca o tema e salva a escolha',
      (tester) async {
    final store = _MemoryThemeStore(ThemeMode.dark);
    await _pump(tester, store);
    expect(_mode(tester), ThemeMode.dark);

    await tester.tap(find.byTooltip('Usar tema claro'));
    await tester.pumpAndSettle();

    expect(_mode(tester), ThemeMode.light);
    expect(store.saved, ThemeMode.light);
    expect(find.byTooltip('Usar tema escuro'), findsOneWidget);

    await tester.tap(find.byTooltip('Usar tema escuro'));
    await tester.pumpAndSettle();
    expect(_mode(tester), ThemeMode.dark);
    expect(store.saved, ThemeMode.dark);
  });

  testWidgets('armazenamento quebrado não impede trocar o tema',
      (tester) async {
    final store = _MemoryThemeStore()..fail = true;
    await _pump(tester, store);

    await tester.tap(find.byType(IconButton).first);
    await tester.pumpAndSettle();

    expect(_mode(tester), isNot(ThemeMode.system));
  });

  test('ThemePreferenceStore grava e lê do shared_preferences', () async {
    SharedPreferences.setMockInitialValues({});
    const store = ThemePreferenceStore();

    expect(await store.load(), isNull);
    await store.save(ThemeMode.light);
    expect(await store.load(), ThemeMode.light);
    await store.save(ThemeMode.dark);
    expect(await store.load(), ThemeMode.dark);
  });

  test('cor primária é a laranja-energia nos dois temas', () {
    expect(AppTheme.light().colorScheme.primary, AppTheme.primaryColor);
    expect(AppTheme.dark().colorScheme.primary, AppTheme.primaryColorDark);
    expect(AppTheme.dark().colorScheme.secondary, AppTheme.voltColorDark);
  });
}
