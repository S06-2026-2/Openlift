// Design system: paleta "energia" (academia, cardio, vida fitness),
// tipografia e ThemeData do app, nos temas claro e escuro.
//
// Direção visual: fundo neutro e frio, com cor de ação forte. Laranja-energia
// é a cor primária (botões, seleção, gráficos); verde-volt é o destaque
// (conquistas, "curtido", o que está em alta) e ciano lembra cardio.
// Hierarquia ainda vem de peso, tamanho e espaçamento; bordas finas no lugar
// de sombras.

import 'package:flutter/material.dart';

/// Design system do OpenLift com temas claro e escuro.
class AppTheme {
  AppTheme._();

  // Marca
  static const Color primaryColor = Color(0xFFF04A12); // laranja-energia
  static const Color primaryColorDark = Color(0xFFFF6A2B);
  static const Color voltColor = Color(0xFF5DA700); // verde-volt (claro)
  static const Color voltColorDark = Color(0xFFC6FF3D);
  static const Color cardioColor = Color(0xFF0891B2); // ciano (claro)
  static const Color cardioColorDark = Color(0xFF22D3EE);

  static const Color dangerColor = Color(0xFFDC2626);
  static const Color dangerColorDark = Color(0xFFF87171);
  static const Color successColor = Color(0xFF16A34A);

  // Neutros — claro
  static const Color lightBackground = Color(0xFFF5F6FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFECEEF4);
  static const Color lightBorder = Color(0xFFDDE1EA);
  static const Color lightText = Color(0xFF0D1018);
  static const Color lightMuted = Color(0xFF666D7E);

  // Neutros — escuro
  static const Color darkBackground = Color(0xFF0A0C11);
  static const Color darkSurface = Color(0xFF12151D);
  static const Color darkSurfaceVariant = Color(0xFF1B1F2A);
  static const Color darkBorder = Color(0xFF272C3A);
  static const Color darkText = Color(0xFFF5F6FA);
  static const Color darkMuted = Color(0xFF9AA1B2);

  /// Escala do mapa de calor (RF-41), do menor volume para o maior. A
  /// célula sem treino usa `surfaceContainerHighest` do tema.
  static const List<Color> heatScale = [
    Color(0xFFFFE08A),
    Color(0xFFFFB547),
    Color(0xFFFF7A1A),
    Color(0xFFE5341B),
  ];

  /// Raios usados em todo o app.
  static const double radiusSm = 8;
  static const double radiusMd = 12;

  /// Largura máxima do conteúdo em telas largas (web).
  static const double contentMaxWidth = 720;

  /// Tema claro do aplicativo.
  static ThemeData light() => _build(
        const ColorScheme.light(
          primary: primaryColor,
          onPrimary: Colors.white,
          primaryContainer: Color(0xFFFFE3D6),
          onPrimaryContainer: Color(0xFF5A1600),
          secondary: voltColor,
          onSecondary: Colors.white,
          secondaryContainer: Color(0xFFE4F7C4),
          onSecondaryContainer: Color(0xFF1E3A00),
          tertiary: cardioColor,
          onTertiary: Colors.white,
          error: dangerColor,
          onError: Colors.white,
          surface: lightSurface,
          onSurface: lightText,
          onSurfaceVariant: lightMuted,
          surfaceContainerLowest: lightSurface,
          surfaceContainerLow: lightBackground,
          surfaceContainer: lightSurfaceVariant,
          surfaceContainerHigh: lightSurfaceVariant,
          surfaceContainerHighest: lightSurfaceVariant,
          outline: lightBorder,
          outlineVariant: lightBorder,
          inverseSurface: Color(0xFF151923),
          onInverseSurface: Color(0xFFF5F6FA),
        ),
        background: lightBackground,
      );

  /// Tema escuro do aplicativo.
  static ThemeData dark() => _build(
        const ColorScheme.dark(
          primary: primaryColorDark,
          onPrimary: Colors.white,
          primaryContainer: Color(0xFF3D1A0C),
          onPrimaryContainer: Color(0xFFFFD2BF),
          secondary: voltColorDark,
          onSecondary: Color(0xFF142300),
          secondaryContainer: Color(0xFF243512),
          onSecondaryContainer: Color(0xFFDFFF9E),
          tertiary: cardioColorDark,
          onTertiary: Color(0xFF00333D),
          error: dangerColorDark,
          onError: Color(0xFF0A0C11),
          surface: darkSurface,
          onSurface: darkText,
          onSurfaceVariant: darkMuted,
          surfaceContainerLowest: darkBackground,
          surfaceContainerLow: darkSurface,
          surfaceContainer: darkSurfaceVariant,
          surfaceContainerHigh: darkSurfaceVariant,
          surfaceContainerHighest: darkSurfaceVariant,
          outline: darkBorder,
          outlineVariant: darkBorder,
          inverseSurface: Color(0xFFF5F6FA),
          onInverseSurface: Color(0xFF0A0C11),
        ),
        background: darkBackground,
      );

  static ThemeData _build(ColorScheme scheme, {required Color background}) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: scheme.brightness,
    );
    final text = _textTheme(base.textTheme, scheme);
    final border = BorderSide(color: scheme.outline);
    final smallShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusSm),
    );
    const buttonText = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    );
    const buttonSize = Size(64, 44);

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: text,
      dividerColor: scheme.outline,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        titleTextStyle: text.titleLarge,
        shape: Border(bottom: border),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: border,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outline,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        border: inputBorder(scheme.outline),
        enabledBorder: inputBorder(scheme.outline),
        disabledBorder: inputBorder(scheme.outline.withValues(alpha: 0.6)),
        focusedBorder: inputBorder(scheme.primary, 1.5),
        errorBorder: inputBorder(scheme.error),
        focusedErrorBorder: inputBorder(scheme.error, 1.5),
        errorStyle: TextStyle(color: scheme.error, fontSize: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: buttonSize,
          shape: smallShape,
          textStyle: buttonText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: buttonSize,
          shape: smallShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: buttonSize,
          side: border,
          shape: smallShape,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          shape: smallShape,
          textStyle: buttonText.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          shape: smallShape,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: smallShape,
        extendedTextStyle: buttonText,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        indicatorShape: smallShape,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: background,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        indicatorShape: smallShape,
        selectedIconTheme: IconThemeData(color: scheme.primary, size: 22),
        unselectedIconTheme:
            IconThemeData(color: scheme.onSurfaceVariant, size: 22),
        selectedLabelTextStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: scheme.onSurfaceVariant,
        ),
      ),
      listTileTheme: ListTileThemeData(
        dense: true,
        shape: smallShape,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        titleTextStyle: text.bodyLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        dragHandleColor: scheme.outline,
        dragHandleSize: const Size(36, 4),
        constraints: const BoxConstraints(maxWidth: 640),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusMd)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: border,
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle:
            text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          side: border,
        ),
        textStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: scheme.onInverseSurface,
          fontSize: 14,
        ),
        elevation: 0,
        width: 400,
        shape: smallShape,
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: scheme.primary,
        smallSize: 7,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        circularTrackColor: Colors.transparent,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: TextStyle(color: scheme.onInverseSurface, fontSize: 12),
        waitDuration: const Duration(milliseconds: 400),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: border,
        ),
      ),
    );
  }

  /// Escala tipográfica enxuta: títulos com tracking negativo, corpo neutro.
  static TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
    final ink = scheme.onSurface;
    // Cor base primeiro; os estilos "muted" abaixo sobrescrevem a cor.
    base = base.apply(bodyColor: ink, displayColor: ink);
    return base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        height: 1.15,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        height: 1.2,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        height: 1.25,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 15, letterSpacing: 0),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 14, letterSpacing: 0),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 13,
        letterSpacing: 0,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}
