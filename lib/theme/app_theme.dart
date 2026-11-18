import 'package:flutter/material.dart';

/// Spacing scale used across the app (4-pt grid).
abstract final class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Horizontal page gutter.
  static const double page = 20;
}

/// Brand colors that stay the same in light and dark mode (app icon,
/// pick reveal stage).
abstract final class Brand {
  static const navy = Color(0xFF1B2A4A);
  static const amber = Color(0xFFE8A838);
}

/// Semantic colors for the current brightness. Read with `context.palette`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.ink,
    required this.muted,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.accentInk,
    required this.success,
    required this.danger,
    required this.background,
    required this.surface,
    required this.line,
  });

  /// Main text.
  final Color ink;

  /// Secondary text.
  final Color muted;

  /// Buttons, selection, highlighted avatars.
  final Color primary;
  final Color onPrimary;

  /// Reward / progress accent.
  final Color accent;

  /// Accent used for text (readable on [surface]).
  final Color accentInk;

  final Color success;
  final Color danger;

  /// Page background.
  final Color background;

  /// Cards, sheets, dialogs.
  final Color surface;

  /// Hairlines and borders.
  final Color line;

  static const light = AppPalette(
    ink: Color(0xFF172033),
    muted: Color(0xFF5E6778),
    primary: Brand.navy,
    onPrimary: Colors.white,
    accent: Brand.amber,
    accentInk: Color(0xFF6B4300),
    success: Color(0xFF2F7D70),
    danger: Color(0xFFB3261E),
    background: Color(0xFFF6F4EF),
    surface: Colors.white,
    line: Color(0xFFE4E0D6),
  );

  static const dark = AppPalette(
    ink: Color(0xFFE8EAEE),
    muted: Color(0xFF9AA2AF),
    primary: Color(0xFFC5D3F0),
    onPrimary: Color(0xFF13203B),
    accent: Color(0xFFE8A838),
    accentInk: Color(0xFFF2C46A),
    success: Color(0xFF6CC3B2),
    danger: Color(0xFFF2877F),
    background: Color(0xFF131518),
    surface: Color(0xFF1C1F24),
    line: Color(0xFF2C3037),
  );

  @override
  AppPalette copyWith({
    Color? ink,
    Color? muted,
    Color? primary,
    Color? onPrimary,
    Color? accent,
    Color? accentInk,
    Color? success,
    Color? danger,
    Color? background,
    Color? surface,
    Color? line,
  }) {
    return AppPalette(
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      accent: accent ?? this.accent,
      accentInk: accentInk ?? this.accentInk,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      line: line ?? this.line,
    );
  }

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      ink: l(ink, other.ink),
      muted: l(muted, other.muted),
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      accent: l(accent, other.accent),
      accentInk: l(accentInk, other.accentInk),
      success: l(success, other.success),
      danger: l(danger, other.danger),
      background: l(background, other.background),
      surface: l(surface, other.surface),
      line: l(line, other.line),
    );
  }
}

extension PaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}

abstract final class AppTheme {
  /// Bundled typeface (assets/fonts, SIL Open Font License).
  static const fontFamily = 'PlusJakartaSans';

  static ThemeData light() => _build(AppPalette.light, Brightness.light);
  static ThemeData dark() => _build(AppPalette.dark, Brightness.dark);

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: Brand.navy,
      brightness: brightness,
    ).copyWith(
      primary: p.primary,
      onPrimary: p.onPrimary,
      secondary: p.accent,
      onSecondary: const Color(0xFF2B1B00),
      tertiary: p.success,
      error: p.danger,
      surface: p.background,
      onSurface: p.ink,
      onSurfaceVariant: p.muted,
      outline: p.muted,
      outlineVariant: p.line,
      surfaceContainerLowest: p.surface,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.surface,
      inverseSurface: p.ink,
      onInverseSurface: p.background,
    );

    // Build the base typography with the app font so every style carries
    // it — including styles passed directly to buttons and app bars.
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
    );
    final text = base.textTheme.merge(_textTheme(p));
    final line = BorderSide(color: p.line);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      textTheme: text,
      extensions: [p],
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0.5,
        foregroundColor: p.ink,
        titleTextStyle: text.titleMedium?.copyWith(fontSize: 18),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: line,
        ),
        clipBehavior: Clip.antiAlias,
      ),
      dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodySmall,
        iconColor: p.muted,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.accent.withValues(alpha: 0.3),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(
          text.labelMedium?.copyWith(color: p.ink),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? p.ink : p.muted,
          ),
        ),
        height: 68,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Brand.navy,
        indicatorColor: Brand.amber.withValues(alpha: 0.3),
        selectedIconTheme: const IconThemeData(color: Brand.amber),
        unselectedIconTheme:
            IconThemeData(color: Colors.white.withValues(alpha: 0.7)),
        selectedLabelTextStyle:
            text.labelLarge?.copyWith(color: Brand.amber),
        unselectedLabelTextStyle: text.labelLarge
            ?.copyWith(color: Colors.white.withValues(alpha: 0.7)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        extendedTextStyle: text.labelLarge?.copyWith(fontSize: 14),
        extendedSizeConstraints: const BoxConstraints.tightFor(height: 48),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 18),
        extendedIconLabelSpacing: 8,
        iconSize: 20,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: text.labelLarge,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: text.labelLarge,
          foregroundColor: p.ink,
          side: line,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 40),
          foregroundColor: p.primary,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: p.ink),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(0, 40),
          textStyle: text.labelLarge,
          side: line,
          backgroundColor: p.surface,
          selectedBackgroundColor: p.primary,
          selectedForegroundColor: p.onPrimary,
          foregroundColor: p.ink,
          visualDensity: VisualDensity.compact,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        labelStyle: text.bodyMedium?.copyWith(color: p.muted),
        hintStyle: text.bodyMedium?.copyWith(color: p.muted),
        helperStyle: text.bodySmall,
        helperMaxLines: 2,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: line,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: line,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.primary, width: 1.5),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.success : null,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: text.bodyMedium,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: p.background),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// One type scale for the whole app: clear hierarchy, tight headings,
  /// relaxed body line height.
  static TextTheme _textTheme(AppPalette p) {
    final ink = p.ink;
    final muted = p.muted;
    return TextTheme(
      displaySmall: TextStyle(
        fontSize: 40,
        height: 1.1,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        color: ink,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: ink,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: ink,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: ink,
      ),
      titleMedium: TextStyle(
        letterSpacing: 0,
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      titleSmall: TextStyle(
        letterSpacing: 0,
        fontSize: 14,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      bodyLarge: TextStyle(
        letterSpacing: 0,
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: ink,
      ),
      bodyMedium: TextStyle(
        letterSpacing: 0,
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: ink,
      ),
      bodySmall: TextStyle(
        letterSpacing: 0,
        fontSize: 13,
        height: 1.4,
        fontWeight: FontWeight.w400,
        color: muted,
      ),
      labelLarge: const TextStyle(
        fontSize: 15,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      labelMedium: const TextStyle(
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: muted,
      ),
    );
  }
}
