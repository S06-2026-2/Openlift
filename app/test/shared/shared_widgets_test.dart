// Testes dos componentes compartilhados do design system (Sprint 1).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlift/core/theme/app_theme.dart';
import 'package:openlift/shared/widgets/app_button.dart';
import 'package:openlift/shared/widgets/app_text_field.dart';
import 'package:openlift/shared/widgets/loading_indicator.dart';

void main() {
  group('AppTheme', () {
    test('AppTheme.light configura Material 3 e esquema de cores', () {
      final lightTheme = AppTheme.light();
      expect(lightTheme.useMaterial3, isTrue);
      expect(lightTheme.colorScheme.primary, equals(AppTheme.primaryColor));
      expect(lightTheme.brightness, equals(Brightness.light));
    });

    test('AppTheme.dark configura Material 3 e esquema de cores', () {
      final darkTheme = AppTheme.dark();
      expect(darkTheme.useMaterial3, isTrue);
      expect(darkTheme.colorScheme.primary, equals(AppTheme.primaryColor));
      expect(darkTheme.brightness, equals(Brightness.dark));
    });
  });

  group('AppButton', () {
    testWidgets('renderiza label e dispara onPressed ao ser clicado', (tester) async {
      var clicked = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: AppButton(
              label: 'Entrar',
              onPressed: () {
                clicked = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Entrar'), findsOneWidget);
      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(clicked, isTrue);
    });

    testWidgets('em estado de loading exibe LoadingIndicator e não dispara clique', (tester) async {
      var clicked = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: AppButton(
              label: 'Salvar',
              isLoading: true,
              onPressed: () {
                clicked = true;
              },
            ),
          ),
        ),
      );

      expect(find.byType(LoadingIndicator), findsOneWidget);
      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(clicked, isFalse);
    });

    testWidgets('renderiza variante secondary e danger', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: Column(
              children: [
                AppButton(
                  label: 'Cancelar',
                  variant: AppButtonVariant.secondary,
                  onPressed: null,
                ),
                AppButton(
                  label: 'Excluir',
                  variant: AppButtonVariant.danger,
                  onPressed: null,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Excluir'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });

  group('AppTextField', () {
    testWidgets('renderiza label, hintText e aceita digitação', (tester) async {
      final controller = TextEditingController();
      String? changedText;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: AppTextField(
              controller: controller,
              label: 'E-mail',
              hintText: 'seu@email.com',
              onChanged: (val) {
                changedText = val;
              },
            ),
          ),
        ),
      );

      expect(find.text('E-mail'), findsOneWidget);
      expect(find.text('seu@email.com'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'teste@openlift.com');
      await tester.pump();

      expect(controller.text, equals('teste@openlift.com'));
      expect(changedText, equals('teste@openlift.com'));
    });
  });

  group('LoadingIndicator', () {
    testWidgets('renderiza CircularProgressIndicator com e sem mensagem', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: Column(
              children: [
                LoadingIndicator(),
                LoadingIndicator(message: 'Carregando treinos...'),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
      expect(find.text('Carregando treinos...'), findsOneWidget);
    });
  });
}
