import 'package:flutter/material.dart';
import 'package:cubelab/core/theme/app_colors.dart';
import 'package:cubelab/core/theme/app_text_styles.dart';
import 'package:cubelab/core/theme/app_spacing.dart';

/// Displays a scramble string in a styled container with a label.
class ScrambleDisplay extends StatelessWidget {
  final String scramble;

  const ScrambleDisplay({
    super.key,
    required this.scramble,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SCRAMBLE',
            style: AppTextStyles.overline,
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Text(
              scramble,
              style: AppTextStyles.scramble,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
