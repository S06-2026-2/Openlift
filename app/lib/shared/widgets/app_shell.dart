// Casca das telas autenticadas: barra de navegação inferior no celular e
// barra lateral em telas largas (web). Destinos: Início, Treinos, Social,
// Perfil (wireframe BottomNav da Sprint 1).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import 'brand_mark.dart';

class _Destination {
  const _Destination(this.path, this.label, this.icon, this.selectedIcon);

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _Destination(
    AppRoutes.dashboard,
    'Início',
    Icons.home_outlined,
    Icons.home_rounded,
  ),
  _Destination(
    AppRoutes.workouts,
    'Treinos',
    Icons.fitness_center_outlined,
    Icons.fitness_center_rounded,
  ),
  _Destination(
    AppRoutes.feed,
    'Social',
    Icons.people_outline_rounded,
    Icons.people_rounded,
  ),
  _Destination(
    AppRoutes.profile,
    'Perfil',
    Icons.person_outline_rounded,
    Icons.person_rounded,
  ),
];

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  /// Largura a partir da qual a navegação vira barra lateral.
  static const double sidebarBreakpoint = 840;

  final String location;
  final Widget child;

  int get _selectedIndex {
    // /social/feed e /social/compose ficam sob "Social".
    final index = _destinations.indexWhere(
      (d) => location.startsWith(d.path.split('/').take(2).join('/')),
    );
    return index < 0 ? 0 : index;
  }

  void _go(BuildContext context, int index) =>
      context.go(_destinations[index].path);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= sidebarBreakpoint;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: true,
              minExtendedWidth: 232,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => _go(context, i),
              leading: const Padding(
                padding: EdgeInsets.fromLTRB(4, 12, 0, 24),
                child: BrandMark(),
              ),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            VerticalDivider(width: 1, color: scheme.outline),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outline)),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (i) => _go(context, i),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            for (final d in _destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
          ],
        ),
      ),
    );
  }
}
