import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Identidade visual "Grafite": papel envelhecido, tinta de grafite e
/// marca-texto amarelo. Todas as cores do app saem daqui.
class GrafiteColors {
  // Tema claro (papel)
  static const paper = Color(0xFFF3EEE4);
  static const sheet = Color(0xFFFBF8F2);
  static const ink = Color(0xFF23211E);
  static const pencil = Color(0xFF6E6A63);
  static const rule = Color(0xFFDDD5C7);
  static const margin = Color(0xFFE59A8C);

  // Tema escuro (grafite)
  static const graphite = Color(0xFF1A1917);
  static const graphiteSheet = Color(0xFF24221F);
  static const chalk = Color(0xFFEFE9DD);
  static const chalkMuted = Color(0xFFA39D92);
  static const graphiteRule = Color(0xFF3A3732);

  // Acentos
  static const highlighter = Color(0xFFF5D547);
  static const eraser = Color(0xFFD2553F);
}

/// Cores de marca-texto usadas nas categorias. A categoria guarda apenas o
/// índice, assim a paleta pode evoluir sem migrar dados.
class CategoryPalette {
  static const colors = <Color>[
    Color(0xFFF5D547), // amarelo
    Color(0xFFF59AB5), // rosa
    Color(0xFF9BD77E), // verde
    Color(0xFF8EC5F2), // azul
    Color(0xFFF6A85B), // laranja
    Color(0xFFC3A6F0), // lilás
  ];

  static Color of(int index) => colors[index % colors.length];
}

class AppTheme {
  static TextStyle display(BuildContext context, {double size = 28}) {
    return GoogleFonts.fraunces(
      fontSize: size,
      fontWeight: FontWeight.w600,
      height: 1.15,
      color: Theme.of(context).colorScheme.onSurface,
    );
  }

  static TextStyle handwritten(BuildContext context, {double size = 20}) {
    return GoogleFonts.caveat(
      fontSize: size,
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }

  static ThemeData light() => _build(
    brightness: Brightness.light,
    background: GrafiteColors.paper,
    surface: GrafiteColors.sheet,
    onSurface: GrafiteColors.ink,
    muted: GrafiteColors.pencil,
    outline: GrafiteColors.rule,
  );

  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    background: GrafiteColors.graphite,
    surface: GrafiteColors.graphiteSheet,
    onSurface: GrafiteColors.chalk,
    muted: GrafiteColors.chalkMuted,
    outline: GrafiteColors.graphiteRule,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color onSurface,
    required Color muted,
    required Color outline,
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: onSurface,
      onPrimary: background,
      secondary: GrafiteColors.highlighter,
      onSecondary: GrafiteColors.ink,
      error: GrafiteColors.eraser,
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: muted,
      outline: outline,
      outlineVariant: outline,
      surfaceContainerHighest: background,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final body = GoogleFonts.interTextTheme(
      base.textTheme,
    ).apply(bodyColor: onSurface, displayColor: onSurface);
    const corner = BorderRadius.all(Radius.circular(6));

    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: body,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.fraunces(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: corner,
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: corner,
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: corner,
          borderSide: BorderSide(color: onSurface, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: onSurface,
          foregroundColor: background,
          minimumSize: const Size.fromHeight(54),
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: corner),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: onSurface),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: onSurface,
        foregroundColor: GrafiteColors.highlighter,
        elevation: 2,
        shape: const RoundedRectangleBorder(borderRadius: corner),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surface,
        side: BorderSide(color: outline),
        shape: const RoundedRectangleBorder(borderRadius: corner),
        labelStyle: TextStyle(color: onSurface, fontWeight: FontWeight.w500),
      ),
      dividerTheme: DividerThemeData(color: outline, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: onSurface,
        contentTextStyle: TextStyle(color: background),
        shape: const RoundedRectangleBorder(borderRadius: corner),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(borderRadius: corner),
      ),
    );
  }
}
