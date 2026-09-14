// Sprint 1 — Smoke test inicial (app sobe sem quebrar).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlift/main.dart';

void main() {
  testWidgets('app inicia sem erros', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: OpenLiftApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Rota: /dashboard'), findsOneWidget);
  });
}
