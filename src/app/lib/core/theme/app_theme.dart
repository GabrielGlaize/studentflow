import 'package:flutter/material.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(
    brightness: Brightness.light,
    primary: AppColors.petrol,
    onPrimary: Colors.white,
    secondary: AppColors.mint,
    background: AppColors.background,
    surface: Colors.white,
    surfaceHigh: AppColors.background,
    text: AppColors.ink,
    muted: AppColors.muted,
    line: AppColors.line,
    selectedSoft: AppColors.primarySoft,
  );

  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    primary: AppColors.mint,
    onPrimary: AppColors.petrolDark,
    secondary: AppColors.sky,
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    surfaceHigh: AppColors.darkSurfaceHigh,
    text: AppColors.darkText,
    muted: AppColors.darkMuted,
    line: AppColors.darkLine,
    selectedSoft: AppColors.mint.withValues(alpha: 0.16),
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color primary,
    required Color onPrimary,
    required Color secondary,
    required Color background,
    required Color surface,
    required Color surfaceHigh,
    required Color text,
    required Color muted,
    required Color line,
    required Color selectedSoft,
  }) {
    final isDark = brightness == Brightness.dark;
    final base = isDark ? ThemeData.dark() : ThemeData.light();
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.petrol,
          brightness: brightness,
          primary: primary,
          onPrimary: onPrimary,
          secondary: secondary,
          surface: surface,
          onSurface: text,
          error: AppColors.danger,
        ).copyWith(
          surfaceContainerLowest: surface,
          surfaceContainerLow: surface,
          surfaceContainer: surfaceHigh,
          surfaceContainerHigh: surfaceHigh,
          surfaceContainerHighest: surfaceHigh,
          outline: line,
          outlineVariant: line,
        );
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: line),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerTheme: DividerThemeData(color: line, space: 1, thickness: 1),
      iconTheme: IconThemeData(color: isDark ? text : AppColors.petrol),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          color: text,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: line),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: muted.withValues(alpha: 0.4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.darkSurfaceHigh : AppColors.ink,
        contentTextStyle: TextStyle(
          color: isDark ? text : Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        indicatorColor: selectedSoft,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected) ? text : muted,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? (isDark ? AppColors.mint : AppColors.petrol)
                : muted,
            size: 24,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: selectedSoft,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? text : AppColors.petrol,
          minimumSize: const Size(64, 48),
          side: BorderSide(color: line, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? AppColors.mint : AppColors.petrol,
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: surface,
          foregroundColor: muted,
          selectedBackgroundColor: selectedSoft,
          selectedForegroundColor: text,
          side: BorderSide(color: line),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: selectedSoft,
        checkmarkColor: isDark ? AppColors.mint : AppColors.petrol,
        side: BorderSide(color: line),
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          color: text,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? onPrimary
              : (isDark ? AppColors.darkMuted : Colors.white),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary
              : (isDark ? AppColors.darkSurfaceHigh : AppColors.line),
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: isDark ? text : AppColors.petrol,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          color: text,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: 'Inter',
          color: muted,
          fontSize: 13,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: TextStyle(color: muted),
        floatingLabelStyle: TextStyle(
          color: isDark ? AppColors.mint : AppColors.petrol,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: TextStyle(color: muted.withValues(alpha: 0.8)),
        prefixIconColor: muted,
        suffixIconColor: muted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: primary, width: 1.6),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: isDark ? surfaceHigh : AppColors.petrol,
        headerForegroundColor: isDark ? text : Colors.white,
        todayBorder: BorderSide(color: primary),
      ),
      timePickerTheme: TimePickerThemeData(backgroundColor: surface),
      textTheme: base.textTheme.apply(
        fontFamily: 'Inter',
        bodyColor: text,
        displayColor: text,
      ),
    );
  }
}
