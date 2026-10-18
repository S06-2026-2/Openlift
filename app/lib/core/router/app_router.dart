// Navegação declarativa (go_router) com as rotas do app e proteção por sessão.
//
// Rotas: /login, /signup, /dashboard, /workouts, /workouts/new, /social/feed,
// /social/compose, /profile.
//
// As 4 áreas principais (Início, Treinos, Social, Perfil) ficam dentro da
// AppShell (navegação inferior/lateral). Formulários e "Compartilhar" abrem em
// tela cheia, fora da casca.
//
// O roteador é um Provider porque o `redirect` depende da sessão
// (authControllerProvider): sem sessão, só /login e /signup são acessíveis;
// com sessão, /login e /signup levam ao /dashboard.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/workouts/presentation/workout_form_screen.dart';
import '../../features/workouts/presentation/workout_history_screen.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/coming_soon_view.dart';
import '../../shared/widgets/loading_indicator.dart';
import 'app_routes.dart';

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
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      // Tela cheia (fora da casca) — declaradas antes de /workouts.
      GoRoute(
        path: AppRoutes.newWorkout,
        builder: (context, state) => const WorkoutFormScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.workouts}/:id/edit',
        redirect: (context, state) =>
            int.tryParse(state.pathParameters['id'] ?? '') == null
                ? AppRoutes.workouts
                : null,
        builder: (context, state) => WorkoutFormScreen(
          workoutId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: AppRoutes.compose,
        builder: (context, state) => Scaffold(
          appBar: AppBar(
            title: const Text('Compartilhar'),
            leading: BackButton(onPressed: () => context.go(AppRoutes.feed)),
          ),
          body: const ComingSoonView(
            icon: Icons.ios_share_rounded,
            title: 'Compartilhar treino',
            description: 'Publique um treino ou artigo na rede aberta NOSTR. '
                'Disponível nas próximas versões.',
          ),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(
          location: state.matchedLocation,
          child: child,
        ),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.workouts,
            builder: (context, state) => const WorkoutHistoryScreen(),
          ),
          GoRoute(
            path: AppRoutes.feed,
            builder: (context, state) => Scaffold(
              appBar: AppBar(title: const Text('Social')),
              body: const ComingSoonView(
                icon: Icons.people_outline_rounded,
                title: 'Feed social em breve',
                description: 'Treinos de quem você segue, publicados na rede '
                    'aberta NOSTR, vão aparecer aqui.',
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const _ProfilePlaceholder(),
          ),
        ],
      ),
    ],
  );
});

/// Perfil ainda sem dados reais: mostra o "em breve" e permite sair da conta.
class _ProfilePlaceholder extends ConsumerWidget {
  const _ProfilePlaceholder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ComingSoonView(
        icon: Icons.person_outline_rounded,
        title: 'Perfil em breve',
        description: 'Seus dados, sua identidade na rede aberta e as '
            'preferências do app ficarão aqui.',
        action: AppButton(
          label: 'Sair da conta',
          icon: Icons.logout_rounded,
          variant: AppButtonVariant.secondary,
          isFullWidth: false,
          onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
        ),
      ),
    );
  }
}
