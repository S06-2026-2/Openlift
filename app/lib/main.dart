// Ponto de entrada do app.
//
// Sprint 1: inicializa o ProviderScope (Riverpod) e o MaterialApp.router
// apontando para o AppRouter. Sprint 2 em diante: inicialização de serviços
// (SecureStorageService, ApiClient) antes do runApp, se necessário.

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
class OpenLiftApp extends StatelessWidget {
  const OpenLiftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'OpenLift',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}
