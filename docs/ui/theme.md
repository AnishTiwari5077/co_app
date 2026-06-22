# SahakariMS — UI: Theme & Flutter Theme System

## Overview

SahakariMS uses Flutter's **Material Design 3** theme system with a custom cooperative-branded theme. All colors, typography, and component styles are defined centrally in `AppTheme` and never hardcoded in widgets.

---

## ThemeData Configuration

```dart
// lib/core/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary:         AppColors.primary,
      onPrimary:       Colors.white,
      primaryContainer:  AppColors.primaryLight.withOpacity(0.15),
      onPrimaryContainer: AppColors.primaryDark,
      secondary:       AppColors.secondary,
      onSecondary:     Colors.white,
      secondaryContainer: AppColors.secondary.withOpacity(0.15),
      onSecondaryContainer: AppColors.secondary,
      tertiary:        AppColors.accent,
      onTertiary:      Colors.white,
      error:           AppColors.error,
      onError:         Colors.white,
      errorContainer:  AppColors.error.withOpacity(0.15),
      onErrorContainer: AppColors.error,
      background:      AppColors.background,
      onBackground:    AppColors.textPrimary,
      surface:         AppColors.surface,
      onSurface:       AppColors.textPrimary,
      surfaceVariant:  AppColors.surfaceVariant,
      onSurfaceVariant: AppColors.textSecondary,
      outline:         const Color(0xFFCDD5E0),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,

      // Typography
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge:   AppTextStyles.displayLarge,
        headlineLarge:  AppTextStyles.headlineLarge,
        headlineMedium: AppTextStyles.headlineMedium,
        headlineSmall:  AppTextStyles.headlineSmall,
        titleLarge:     AppTextStyles.titleLarge,
        titleMedium:    AppTextStyles.titleMedium,
        titleSmall:     AppTextStyles.titleSmall,
        bodyLarge:      AppTextStyles.bodyLarge,
        bodyMedium:     AppTextStyles.bodyMedium,
        bodySmall:      AppTextStyles.bodySmall,
        labelLarge:     AppTextStyles.labelLarge,
        labelSmall:     AppTextStyles.labelSmall,
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
        titleTextStyle: AppTextStyles.titleLarge,
        iconTheme: const IconThemeData(color: AppColors.primary),
        surfaceTintColor: Colors.transparent,
      ),

      // Cards
      cardTheme: CardTheme(
        elevation: 0,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          side: const BorderSide(color: Color(0xFFE8EDF3), width: 1),
        ),
        margin: const EdgeInsets.all(0),
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(120, AppDimensions.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          textStyle: AppTextStyles.labelLarge,
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(120, AppDimensions.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          textStyle: AppTextStyles.labelLarge,
        ),
      ),

      // Input Fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(color: Color(0xFFE0E7EF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        labelStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textDisabled),
        errorStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
      ),

      // Data Table
      dataTableTheme: DataTableThemeData(
        headingRowColor: MaterialStateProperty.all(AppColors.surfaceVariant),
        headingTextStyle: AppTextStyles.labelLarge.copyWith(color: AppColors.textPrimary),
        dataTextStyle: AppTextStyles.bodyMedium,
        dividerThickness: 1,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE8EDF3)),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        labelStyle: AppTextStyles.labelSmall,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
        ),
      ),

      // Bottom Navigation
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withOpacity(0.12),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected))
            return const IconThemeData(color: AppColors.primary, size: 24);
          return const IconThemeData(color: AppColors.textSecondary, size: 24);
        }),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected))
            return AppTextStyles.labelSmall.copyWith(color: AppColors.primary);
          return AppTextStyles.labelSmall;
        }),
      ),

      // Snack bar
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE8EDF3),
        thickness: 1,
        space: 1,
      ),
    );
  }

  // Dark theme
  static ThemeData get darkTheme {
    return lightTheme.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColorsDark.background,
      colorScheme: ColorScheme.dark(
        primary: AppColorsDark.primary,
        surface: AppColorsDark.surface,
        background: AppColorsDark.background,
        onBackground: AppColorsDark.textPrimary,
        onSurface: AppColorsDark.textPrimary,
      ),
    );
  }
}
```

---

## Theme Usage in main.dart

```dart
// lib/main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DotEnv.load();

  runApp(
    ProviderScope(
      child: Consumer(
        builder: (context, ref, _) {
          final themeMode = ref.watch(themeModeProvider);

          return MaterialApp.router(
            title: 'SahakariMS',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            routerConfig: AppRouter.router,
            debugShowCheckedModeBanner: false,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en', 'US'),
              Locale('ne', 'NP'),
            ],
          );
        },
      ),
    ),
  );
}
```

---

## Component Showcase (Storybook)

During development, components are previewed using `widgetbook`:

```dart
// widgetbook/main.dart
@App()
class WidgetbookApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      directories: [
        WidgetbookCategory(
          name: 'Buttons',
          widgets: [
            WidgetbookComponent(
              name: 'AppButton',
              useCases: [
                WidgetbookUseCase(
                  name: 'Primary',
                  builder: (context) => AppButton(
                    label: 'Approve Loan',
                    onPressed: () {},
                    icon: Icons.check,
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Loading',
                  builder: (context) => AppButton(
                    label: 'Processing',
                    onPressed: null,
                    isLoading: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
```

---

## Dark Mode Toggle

```dart
// lib/core/theme/theme_provider.dart
@riverpod
class ThemeModeNotifier extends _$ThemeModeNotifier {
  @override
  ThemeMode build() => ThemeMode.system;

  void toggle() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    // Persist preference
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString('theme_mode', state.name));
  }
}
```
