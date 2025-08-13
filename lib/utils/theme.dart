import 'package:flutter/material.dart';
import 'package:office_task_managemet/utils/colors.dart';

final appTheme = ThemeData(
  scaffoldBackgroundColor: AppColors.gray50,
  primaryColor: AppColors.yellow,
  colorScheme: ColorScheme(
    primary: AppColors.yellow,
    onPrimary: AppColors.black,
    secondary: AppColors.blue,
    onSecondary: AppColors.white,
    surface: AppColors.gray100,
    background: AppColors.gray50,
    error: AppColors.error,
    onError: AppColors.white,
    onSurface: AppColors.gray700,
    onBackground: AppColors.gray700,
    brightness: Brightness.light,
  ),
  textTheme: const TextTheme(
    titleLarge: TextStyle(color: AppColors.gray900), // headline6
    bodyMedium: TextStyle(color: AppColors.gray700), // bodyText2
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.white,
    border: OutlineInputBorder(
      borderSide: BorderSide(color: AppColors.gray200),
      borderRadius: BorderRadius.circular(8),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.gray900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(vertical: 16),
    ),
  ),
);
