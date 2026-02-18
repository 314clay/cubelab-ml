import 'package:flutter/material.dart';
import 'package:cubelab/core/theme/app_colors.dart';
import 'package:cubelab/core/theme/app_text_styles.dart';
import 'package:cubelab/core/theme/app_spacing.dart';

/// SRS integration prompt shown after solution reveal.
/// Offers to add unknown cases to the practice queue.
class SrsActionWidget extends StatelessWidget {
  final String? caseName;
  final VoidCallback onAddToQueue;
  final VoidCallback onSkip;

  const SrsActionWidget({
    super.key,
    required this.caseName,
    required this.onAddToQueue,
    required this.onSkip,
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
        children: [
          const Icon(Icons.lightbulb_outline, color: Color(0xFFFFC107), size: 32),
          const SizedBox(height: AppSpacing.md),
          Text('New case discovered!', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.sm),
          Text(
            caseName != null
                ? '$caseName isn\'t in your practice queue yet.'
                : 'This case isn\'t in your practice queue yet.',
            style: AppTextStyles.bodySecondary,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onSkip,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppSpacing.buttonRadius,
                    ),
                  ),
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: onAddToQueue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppSpacing.buttonRadius,
                    ),
                  ),
                  child: const Text('Add to Practice Queue'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
