import 'package:flutter/material.dart';

/// PROSMART-style dark identity: near-black background, charcoal cards,
/// teal score accent, warm orange strain accent.
class AppColors {
  static const bg = Color(0xFF0B0B0D);
  static const card = Color(0xFF141417);
  static const cardElevated = Color(0xFF1B1B1F);
  static const border = Color(0x26FFFFFF);

  static const teal = Color(0xFF2FE0A8);
  static const orange = Color(0xFFF6915A);
  static const periwinkle = Color(0xFF8B93B8);
  static const ringBlue = Color(0xFF7C8CF8);
  static const sparkGreen = Color(0xFF4ADE80);

  static const textPrimary = Color(0xFFF2F2F4);
  static const textSecondary = Color(0xFFB9B9C0);
  static const textMuted = Color(0xFF7A7A84);
}

class AppTheme {
  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: AppColors.teal,
      secondary: AppColors.orange,
      surface: AppColors.bg,
      surfaceContainerHighest: AppColors.card,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bg,
        selectedItemColor: AppColors.textPrimary,
        unselectedItemColor: AppColors.textMuted,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? AppColors.cardElevated
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? AppColors.textPrimary
                : AppColors.textMuted,
          ),
          side: WidgetStateProperty.all(
            const BorderSide(color: AppColors.border),
          ),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.teal,
        inactiveTrackColor: Color(0xFF2A2A30),
        thumbColor: AppColors.teal,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.teal
              : AppColors.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.teal.withValues(alpha: 0.3)
              : const Color(0xFF2A2A30),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
            color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(
            color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(
            color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(
            color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: AppColors.textSecondary),
        bodyMedium: TextStyle(color: AppColors.textSecondary),
        bodySmall: TextStyle(color: AppColors.textMuted),
        labelMedium: TextStyle(color: AppColors.textMuted),
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary),
    );
  }
}
