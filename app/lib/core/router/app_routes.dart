// Caminhos de navegação centralizados (evita strings espalhadas pelo app).

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
