// Tema do app escolhido pela pessoa: claro ou escuro.
//
// Até a pessoa escolher, segue o sistema. A escolha fica salva no aparelho
// (shared_preferences: não é segredo) e volta na próxima abertura. Se o
// armazenamento falhar, o app continua com o tema da sessão.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Onde a escolha do tema fica salva. Override nos testes.
class ThemePreferenceStore {
  const ThemePreferenceStore();

  static const String key = 'ui.theme_mode';

  Future<ThemeMode?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return switch (prefs.getString(key)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => null,
    };
  }

  Future<void> save(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, mode == ThemeMode.light ? 'light' : 'dark');
  }
}

final themePreferenceStoreProvider = Provider<ThemePreferenceStore>(
  (ref) => const ThemePreferenceStore(),
);

class ThemeModeController extends Notifier<ThemeMode> {
  /// Já houve escolha nesta sessão: a leitura atrasada do disco não a desfaz.
  bool _chosen = false;

  @override
  ThemeMode build() {
    _restore();
    return ThemeMode.system;
  }

  Future<void> _restore() async {
    try {
      final saved = await ref.read(themePreferenceStoreProvider).load();
      if (saved != null && !_chosen) state = saved;
    } on Object {
      // Sem armazenamento (plugin ausente, modo privado): segue o sistema.
    }
  }

  /// Troca para o tema oposto ao que está na tela ([current]).
  Future<void> toggle(Brightness current) =>
      set(current == Brightness.dark ? ThemeMode.light : ThemeMode.dark);

  Future<void> set(ThemeMode mode) async {
    _chosen = true;
    state = mode;
    try {
      await ref.read(themePreferenceStoreProvider).save(mode);
    } on Object {
      // A escolha vale nesta sessão mesmo sem salvar.
    }
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
