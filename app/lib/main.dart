// Ponto de entrada do app.
//
// Sprint 1: inicializa o ProviderScope (Riverpod) e o MaterialApp.router
// apontando para o roteador (routerProvider), que protege as rotas por sessão.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(
    const ProviderScope(
      child: OpenLiftApp(),
    ),
  );
}

/// Aplicação principal do OpenLift com roteamento declarativo e design system.
class OpenLiftApp extends ConsumerWidget {
  const OpenLiftApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'OpenLift',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
