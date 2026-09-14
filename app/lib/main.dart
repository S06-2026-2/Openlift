// Ponto de entrada do app.
//
// Sprint 1: inicializa o ProviderScope (Riverpod) e o MaterialApp.router
// apontando para o AppRouter. Sprint 2 em diante: inicialização de serviços
// (SecureStorageService, ApiClient) antes do runApp, se necessário.

import 'package:flutter/material.dart';

void main() {
  // TODO(Sprint 1): envolver com ProviderScope (flutter_riverpod).
  // TODO(Sprint 1): runApp(OpenLiftApp()).
  runApp(const _PlaceholderApp());
}

/// Placeholder até o AppRouter (core/router/app_router.dart) ser implementado.
class _PlaceholderApp extends StatelessWidget {
  const _PlaceholderApp();

  @override
  Widget build(BuildContext context) {
    // TODO(Sprint 1): substituir por MaterialApp.router(routerConfig: appRouter).
    throw UnimplementedError('OpenLiftApp ainda não implementado.');
  }
}
