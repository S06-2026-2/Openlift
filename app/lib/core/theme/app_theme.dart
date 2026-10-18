// Design system: paleta neutra (escala zinc), tipografia e ThemeData do app.
//
// Direção visual: minimalista. A cor primária é a própria "tinta" do texto
// (quase preto no claro, quase branco no escuro); hierarquia vem de peso,
// tamanho e espaçamento, não de cor. Bordas finas no lugar de sombras.

import 'package:flutter/material.dart';

/// Design system do OpenLift com temas claro e escuro.
class AppTheme {
  AppTheme._();

  // Primária = tinta do texto em cada tema.
  static const Color primaryColor = Color(0xFF18181B); // zinc-900
  static const Color primaryColorDark = Color(0xFFFAFAFA); // zinc-50

  static const Color dangerColor = Color(0xFFDC2626);
  static const Color dangerColorDark = Color(0xFFF87171);
  static const Color successColor = Color(0xFF16A34A);

  // Neutros — claro
  static const Color lightBackground = Color(0xFFFAFAFA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF4F4F5);
  static const Color lightBorder = Color(0xFFE4E4E7);
  static const Color lightText = Color(0xFF09090B);
  static const Color lightMuted = Color(0xFF71717A);

  // Neutros — escuro
  static const Color darkBackground = Color(0xFF09090B);
  static const Color darkSurface = Color(0xFF111113);
  static const Color darkSurfaceVariant = Color(0xFF1C1C1F);
  static const Color darkBorder = Color(0xFF27272A);
  static const Color darkText = Color(0xFFFAFAFA);
  static const Color darkMuted = Color(0xFFA1A1AA);

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
          primaryContainer: lightSurfaceVariant,
          onPrimaryContainer: lightText,
          secondary: lightMuted,
          onSecondary: Colors.white,
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
          inverseSurface: Color(0xFF18181B),
          onInverseSurface: Color(0xFFFAFAFA),
        ),
        background: lightBackground,
      );

  /// Tema escuro do aplicativo.
  static ThemeData dark() => _build(
        const ColorScheme.dark(
          primary: primaryColorDark,
          onPrimary: Color(0xFF09090B),
          primaryContainer: darkSurfaceVariant,
          onPrimaryContainer: darkText,
          secondary: darkMuted,
          onSecondary: Color(0xFF09090B),
          error: dangerColorDark,
          onError: Color(0xFF09090B),
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
          inverseSurface: Color(0xFFFAFAFA),
          onInverseSurface: Color(0xFF09090B),
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
        focusedBorder: inputBorder(scheme.onSurface, 1.5),
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
          foregroundColor: scheme.onSurface,
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
        indicatorColor: scheme.surfaceContainerHighest,
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
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: background,
        indicatorColor: scheme.surfaceContainerHighest,
        indicatorShape: smallShape,
        selectedIconTheme: IconThemeData(color: scheme.onSurface, size: 22),
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
        backgroundColor: scheme.onSurface,
        smallSize: 7,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.onSurface,
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
