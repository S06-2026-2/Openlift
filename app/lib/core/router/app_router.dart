// Sprint 1 — Navegação declarativa (go_router) com as rotas do app.
//
// Rotas previstas: /login, /signup, /dashboard, /workouts, /workouts/new,
// /social/feed, /social/compose, /profile.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Gerenciador de rotas declarativas do aplicativo.
class AppRouter {
  AppRouter._();

  // TODO(Sprint 2): guard de autenticação (redirect para /login se sem sessão).

  /// Configuração de rotas declarativas com GoRouter.
  static final GoRouter router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const _PlaceholderScreen(
          title: 'Login',
          routeName: '/login',
        ),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const _PlaceholderScreen(
          title: 'Cadastro',
          routeName: '/signup',
        ),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const _PlaceholderScreen(
          title: 'Dashboard',
          routeName: '/dashboard',
        ),
      ),
      GoRoute(
        path: '/workouts',
        builder: (context, state) => const _PlaceholderScreen(
          title: 'Treinos',
          routeName: '/workouts',
        ),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const _PlaceholderScreen(
              title: 'Novo Treino',
              routeName: '/workouts/new',
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/social/feed',
        builder: (context, state) => const _PlaceholderScreen(
          title: 'Feed Social',
          routeName: '/social/feed',
        ),
      ),
      GoRoute(
        path: '/social/compose',
        builder: (context, state) => const _PlaceholderScreen(
          title: 'Compartilhar',
          routeName: '/social/compose',
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const _PlaceholderScreen(
          title: 'Perfil',
          routeName: '/profile',
        ),
      ),
    ],
  );
}

/// Instância do GoRouter disponível globalmente para facilidade de uso.
final GoRouter appRouter = AppRouter.router;

/// Tela de Scaffold placeholder para rotas do Sprint 1.
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({
    required this.title,
    required this.routeName,
  });

  final String title;
  final String routeName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.fitness_center_rounded,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Rota: $routeName',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tela placeholder (implementação real a partir do Sprint 2)',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
