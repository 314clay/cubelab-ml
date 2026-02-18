import 'package:flutter/material.dart';
import 'package:cubelab/core/theme/app_colors.dart';

/// Text styles for CubeLab.
abstract class AppTextStyles {
  static const h2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const h3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const body = TextStyle(
    fontSize: 16,
    color: AppColors.textPrimary,
  );

  static const bodySecondary = TextStyle(
    fontSize: 16,
    color: AppColors.textSecondary,
  );

  static const caption = TextStyle(
    fontSize: 12,
    color: AppColors.textTertiary,
  );

  static const overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    color: AppColors.textSecondary,
  );

  static const buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const timerLarge = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.bold,
    fontFamily: 'monospace',
    color: AppColors.textPrimary,
  );

  static const scramble = TextStyle(
    fontSize: 15,
    fontFamily: 'monospace',
    color: AppColors.textPrimary,
    height: 1.5,
  );
}
