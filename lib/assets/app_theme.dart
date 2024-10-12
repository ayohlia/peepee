import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

class AppTheme {
  static final ColorScheme lightColorScheme = ColorScheme.fromSeed(
    brightness: Brightness.light,
    seedColor: AppColors.seedColor,
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    secondary: AppColors.secondary,
    surface: AppColors.surface,
  );

  static final ThemeData lightTheme = ThemeData(
    textTheme: TextTheme(
        displayLarge: TextStyle(
            fontFamily: 'FredokaOne',
            fontSize: 32,
            color: lightColorScheme.onPrimary),
        bodyLarge: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 16,
            color: lightColorScheme.onSecondary)),
    useMaterial3: true,
    colorScheme: lightColorScheme,
    appBarTheme: AppBarTheme(
        systemOverlayStyle: SystemUiOverlayStyle(
            statusBarIconBrightness:
                lightColorScheme.brightness == Brightness.dark
                    ? Brightness.dark
                    : Brightness.light,
            statusBarColor: lightColorScheme.onPrimaryContainer,
            systemNavigationBarColor: lightColorScheme.onPrimaryContainer)),
  );
}
