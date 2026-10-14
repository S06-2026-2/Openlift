// Navegação declarativa (go_router) com as rotas do app e proteção por sessão.
//
// Rotas: /login, /signup, /dashboard, /workouts, /workouts/new, /social/feed,
// /social/compose, /profile.
//
// O roteador é um Provider porque o `redirect` depende da sessão
// (authControllerProvider): sem sessão, só /login e /signup são acessíveis;
// com sessão, /login e /signup levam ao /dashboard.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../shared/widgets/loading_indicator.dart';

/// Caminhos centralizados para não espalhar strings pelo app.
abstract final class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String dashboard = '/dashboard';
  static const String workouts = '/workouts';
  static const String newWorkout = '/workouts/new';
  static const String feed = '/social/feed';
  static const String compose = '/social/compose';
  static const String profile = '/profile';
}

class _RouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen<AsyncValue<AuthState>>(
    authControllerProvider,
    (_, __) => refresh.notify(),
  );
  ref.onDispose(refresh.dispose);

  String? redirect(BuildContext context, GoRouterState state) {
    final auth = ref.read(authControllerProvider);
    final location = state.matchedLocation;

    // Ainda restaurando a sessão salva: segura numa tela de carregamento.
    if (auth.isLoading && !auth.hasValue) {
      return location == AppRoutes.splash ? null : AppRoutes.splash;
    }

    final authenticated = auth.valueOrNull?.isAuthenticated ?? false;
    final isPublic =
        location == AppRoutes.login || location == AppRoutes.signup;

    if (location == AppRoutes.splash) {
      return authenticated ? AppRoutes.dashboard : AppRoutes.login;
    }
    if (!authenticated && !isPublic) return AppRoutes.login;
    if (authenticated && isPublic) return AppRoutes.dashboard;
    return null;
  }

  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    refreshListenable: refresh,
    redirect: redirect,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const Scaffold(
          body: LoadingIndicator(message: 'Carregando...'),
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const _PlaceholderScreen(
          title: 'Login',
          routeName: AppRoutes.login,
        ),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const _PlaceholderScreen(
          title: 'Cadastro',
          routeName: AppRoutes.signup,
        ),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (context, state) => const _PlaceholderScreen(
          title: 'Dashboard',
          routeName: AppRoutes.dashboard,
        ),
      ),
      GoRoute(
        path: AppRoutes.workouts,
        builder: (context, state) => const _PlaceholderScreen(
          title: 'Treinos',
          routeName: AppRoutes.workouts,
        ),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const _PlaceholderScreen(
              title: 'Novo Treino',
              routeName: AppRoutes.newWorkout,
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.feed,
        builder: (context, state) => const _PlaceholderScreen(
          title: 'Feed Social',
          routeName: AppRoutes.feed,
        ),
      ),
      GoRoute(
        path: AppRoutes.compose,
        builder: (context, state) => const _PlaceholderScreen(
          title: 'Compartilhar',
          routeName: AppRoutes.compose,
        ),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const _PlaceholderScreen(
          title: 'Perfil',
          routeName: AppRoutes.profile,
        ),
      ),
    ],
  );
});

/// Tela placeholder das rotas que ainda não têm implementação real.
/// Mostra o botão "Sair" para permitir testar logout/sessão de ponta a ponta.
class _PlaceholderScreen extends ConsumerWidget {
  const _PlaceholderScreen({
    required this.title,
    required this.routeName,
  });

  final String title;
  final String routeName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authenticated = ref.watch(
      authControllerProvider.select((s) => s.valueOrNull?.isAuthenticated),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (authenticated == true)
            IconButton(
              tooltip: 'Sair',
              icon: const Icon(Icons.logout_rounded),
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
            ),
        ],
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
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Rota: $routeName',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tela placeholder (implementação real a partir do Sprint 2)',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
