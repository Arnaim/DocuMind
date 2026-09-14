import 'package:flutter/material.dart';

/// DocuMind's visual identity: a warm "colorful research desk".
///
/// Light theme — warm ivory paper, deep plum ink, coral/lavender/mint/gold
/// accents. Dark theme — deep plum-charcoal (never pure black) with the same
/// warm accents lifted for contrast. Both share one semantic color map
/// ([DocuMindColors]) so every component picks colors consistently.
class DocuMindColors extends ThemeExtension<DocuMindColors> {
  final Color plum; // primary ink / headings / primary buttons
  final Color coral; // primary actions, PDF accents
  final Color coralSoft;
  final Color lavender; // AI elements
  final Color lavenderSoft;
  final Color mint; // success, ready states, citations
  final Color mintSoft;
  final Color gold; // highlights, personal, warnings
  final Color goldSoft;
  final Color pink; // secondary accents, favorites
  final Color pinkSoft;
  final Color surface; // page background
  final Color surfaceWarm; // raised cards
  final Color outline; // hairlines
  final Color danger; // destructive (rarely used)
  final Color onAccent; // text on coral/plum fills

  const DocuMindColors({
    required this.plum,
    required this.coral,
    required this.coralSoft,
    required this.lavender,
    required this.lavenderSoft,
    required this.mint,
    required this.mintSoft,
    required this.gold,
    required this.goldSoft,
    required this.pink,
    required this.pinkSoft,
    required this.surface,
    required this.surfaceWarm,
    required this.outline,
    required this.danger,
    required this.onAccent,
  });

  static const light = DocuMindColors(
    plum: Color(0xFF4A2545),
    coral: Color(0xFFE8604C),
    coralSoft: Color(0xFFFFE9E2),
    lavender: Color(0xFF8B6FC7),
    lavenderSoft: Color(0xFFEFE9FB),
    mint: Color(0xFF1E8E7A),
    mintSoft: Color(0xFFDFF3EC),
    gold: Color(0xFFB98214),
    goldSoft: Color(0xFFFFF3D6),
    pink: Color(0xFFD2548C),
    pinkSoft: Color(0xFFFCE4EE),
    surface: Color(0xFFFAF5EC),
    surfaceWarm: Color(0xFFFFFCF6),
    outline: Color(0xFFE7DCCB),
    danger: Color(0xFFC63D2F),
    onAccent: Color(0xFFFFFCF6),
  );

  static const dark = DocuMindColors(
    plum: Color(0xFFE8D9EC),
    coral: Color(0xFFFF8A70),
    coralSoft: Color(0xFF4A2733),
    lavender: Color(0xFFB9A0E8),
    lavenderSoft: Color(0xFF33254A),
    mint: Color(0xFF63D2B4),
    mintSoft: Color(0xFF1E3A38),
    gold: Color(0xFFF2C14E),
    goldSoft: Color(0xFF40351E),
    pink: Color(0xFFEE8FB8),
    pinkSoft: Color(0xFF42283A),
    surface: Color(0xFF241B2E),
    surfaceWarm: Color(0xFF2E2340),
    outline: Color(0xFF443559),
    danger: Color(0xFFFF7B6B),
    onAccent: Color(0xFF2A1B26),
  );

  @override
  DocuMindColors copyWith({
    Color? plum,
    Color? coral,
    Color? coralSoft,
    Color? lavender,
    Color? lavenderSoft,
    Color? mint,
    Color? mintSoft,
    Color? gold,
    Color? goldSoft,
    Color? pink,
    Color? pinkSoft,
    Color? surface,
    Color? surfaceWarm,
    Color? outline,
    Color? danger,
    Color? onAccent,
  }) =>
      DocuMindColors(
        plum: plum ?? this.plum,
        coral: coral ?? this.coral,
        coralSoft: coralSoft ?? this.coralSoft,
        lavender: lavender ?? this.lavender,
        lavenderSoft: lavenderSoft ?? this.lavenderSoft,
        mint: mint ?? this.mint,
        mintSoft: mintSoft ?? this.mintSoft,
        gold: gold ?? this.gold,
        goldSoft: goldSoft ?? this.goldSoft,
        pink: pink ?? this.pink,
        pinkSoft: pinkSoft ?? this.pinkSoft,
        surface: surface ?? this.surface,
        surfaceWarm: surfaceWarm ?? this.surfaceWarm,
        outline: outline ?? this.outline,
        danger: danger ?? this.danger,
        onAccent: onAccent ?? this.onAccent,
      );

  @override
  DocuMindColors lerp(DocuMindColors other, double t) => DocuMindColors(
        plum: Color.lerp(plum, other.plum, t)!,
        coral: Color.lerp(coral, other.coral, t)!,
        coralSoft: Color.lerp(coralSoft, other.coralSoft, t)!,
        lavender: Color.lerp(lavender, other.lavender, t)!,
        lavenderSoft: Color.lerp(lavenderSoft, other.lavenderSoft, t)!,
        mint: Color.lerp(mint, other.mint, t)!,
        mintSoft: Color.lerp(mintSoft, other.mintSoft, t)!,
        gold: Color.lerp(gold, other.gold, t)!,
        goldSoft: Color.lerp(goldSoft, other.goldSoft, t)!,
        pink: Color.lerp(pink, other.pink, t)!,
        pinkSoft: Color.lerp(pinkSoft, other.pinkSoft, t)!,
        surface: Color.lerp(surface, other.surface, t)!,
        surfaceWarm: Color.lerp(surfaceWarm, other.surfaceWarm, t)!,
        outline: Color.lerp(outline, other.outline, t)!,
        danger: Color.lerp(danger, other.danger, t)!,
        onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      );
}

/// Convenience accessor: `context.docColors`.
extension DocuMindColorsX on BuildContext {
  DocuMindColors get docColors =>
      Theme.of(this).extension<DocuMindColors>() ?? DocuMindColors.light;
}

class AppTheme {
  AppTheme._();

  static const String fontDisplay = 'Fraunces';
  static const String fontBody = 'Manrope';

  static ThemeData light() => _build(DocuMindColors.light, Brightness.light);
  static ThemeData dark() => _build(DocuMindColors.dark, Brightness.dark);

  static ThemeData _build(DocuMindColors c, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: brightness == Brightness.light ? c.coral : c.coral,
      onPrimary: c.onAccent,
      primaryContainer: c.coralSoft,
      onPrimaryContainer: c.plum,
      secondary: c.lavender,
      onSecondary: c.onAccent,
      secondaryContainer: c.lavenderSoft,
      onSecondaryContainer: c.plum,
      tertiary: c.mint,
      onTertiary: c.onAccent,
      tertiaryContainer: c.mintSoft,
      onTertiaryContainer: c.plum,
      error: c.danger,
      onError: c.onAccent,
      surface: c.surfaceWarm,
      onSurface: c.plum,
      surfaceContainerHighest: c.coralSoft,
      surfaceContainerHigh: c.lavenderSoft,
      surfaceContainer: c.goldSoft,
      surfaceContainerLow: c.pinkSoft,
      surfaceContainerLowest: c.surfaceWarm,
      onSurfaceVariant: c.plum.withValues(alpha: 0.65),
      outline: c.outline,
      outlineVariant: c.outline,
      inverseSurface: c.plum,
      onInverseSurface: c.surfaceWarm,
      shadow: c.plum.withValues(alpha: 0.25),
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    return base.copyWith(
      scaffoldBackgroundColor: c.surface,
      textTheme: _textTheme(base.textTheme, c, brightness),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: c.surface,
        foregroundColor: c.plum,
        titleTextStyle: TextStyle(
          fontFamily: fontDisplay,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: c.plum,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: c.surfaceWarm,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: c.outline.withValues(alpha: 0.8)),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: c.outline),
        backgroundColor: c.surfaceWarm,
        labelStyle: TextStyle(color: c.plum, fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceWarm,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: c.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: c.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: c.lavender, width: 1.6),
        ),
        hintStyle: TextStyle(color: c.plum.withValues(alpha: 0.45)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.coral,
          foregroundColor: c.onAccent,
          textStyle: TextStyle(
            fontFamily: fontBody,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.plum,
          side: BorderSide(color: c.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.coral,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: c.outline.withValues(alpha: 0.7),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.plum,
        contentTextStyle: TextStyle(color: c.surfaceWarm),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surfaceWarm,
        indicatorColor: c.lavenderSoft,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: fontBody,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: c.plum,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? c.lavender : c.plum.withValues(alpha: 0.55),
          );
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.coral;
          return null;
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.coral;
          return null;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.coral,
        linearTrackColor: c.outline.withValues(alpha: 0.6),
        circularTrackColor: c.outline.withValues(alpha: 0.6),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.coral,
        foregroundColor: c.onAccent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceWarm,
        modalBackgroundColor: c.surfaceWarm,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceWarm,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        titleTextStyle: TextStyle(
          fontFamily: fontDisplay,
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: c.plum,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.plum,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[c],
    );
  }

  /// Editorial headings (Fraunces) + readable body (Manrope).
  static TextTheme _textTheme(TextTheme base, DocuMindColors c, Brightness b) {
    final display = const TextStyle(
      fontFamily: fontDisplay,
      color: Color(0xFF4A2545),
    );
    final body = const TextStyle(fontFamily: fontBody);
    final ink = b == Brightness.light ? const Color(0xFF4A2545) : const Color(0xFFE8D9EC);

    return base.copyWith(
      displaySmall: display.copyWith(
          fontSize: 32, fontWeight: FontWeight.w700, color: ink, height: 1.1),
      headlineMedium: display.copyWith(
          fontSize: 26, fontWeight: FontWeight.w700, color: ink, height: 1.15),
      titleLarge: display.copyWith(
          fontSize: 20, fontWeight: FontWeight.w600, color: ink),
      titleMedium: body.copyWith(
          fontSize: 16, fontWeight: FontWeight.w700, color: ink),
      titleSmall: body.copyWith(
          fontSize: 14, fontWeight: FontWeight.w700, color: ink),
      bodyLarge: body.copyWith(fontSize: 15.5, height: 1.5, color: ink),
      bodyMedium: body.copyWith(fontSize: 14, height: 1.45, color: ink),
      bodySmall: body.copyWith(
          fontSize: 12.5,
          height: 1.35,
          color: ink.withValues(alpha: 0.72)),
      labelLarge: body.copyWith(
          fontSize: 13.5, fontWeight: FontWeight.w700, color: ink),
      labelMedium: body.copyWith(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: ink.withValues(alpha: 0.85)),
      labelSmall: body.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: ink.withValues(alpha: 0.62)),
    );
  }
}
