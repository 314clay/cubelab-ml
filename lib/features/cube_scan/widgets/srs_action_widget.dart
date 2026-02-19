import 'package:flutter/material.dart';
import 'package:cubelab/core/theme/app_colors.dart';
import 'package:cubelab/core/theme/app_text_styles.dart';
import 'package:cubelab/core/theme/app_spacing.dart';
import 'package:cubelab/data/models/srs_state.dart';

/// SRS integration prompt shown after solution reveal.
/// Shows discovery prompt for new cases, or SRS rating for known cases.
class SrsActionWidget extends StatelessWidget {
  final String? caseName;
  final bool isKnownAlgorithm;
  final VoidCallback onAddToQueue;
  final VoidCallback onSkip;
  final void Function(SRSRating rating)? onRate;

  const SrsActionWidget({
    super.key,
    required this.caseName,
    this.isKnownAlgorithm = false,
    required this.onAddToQueue,
    required this.onSkip,
    this.onRate,
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
      child: isKnownAlgorithm
          ? _buildReviewContent()
          : _buildDiscoveryContent(),
    );
  }

  Widget _buildDiscoveryContent() {
    return Column(
      children: [
        const Icon(Icons.lightbulb_outline, color: Color(0xFFFFC107), size: 32),
        const SizedBox(height: AppSpacing.md),
        const Text('New case discovered!', style: AppTextStyles.h3),
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
                  shape: const RoundedRectangleBorder(
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
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppSpacing.buttonRadius,
                  ),
                ),
                child: const Text('Add to Practice Queue'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewContent() {
    return Column(
      children: [
        const Icon(Icons.psychology, color: AppColors.primary, size: 32),
        const SizedBox(height: AppSpacing.md),
        const Text('How was your recall?', style: AppTextStyles.h3),
        const SizedBox(height: AppSpacing.sm),
        Text(
          caseName != null
              ? 'Rate your recognition of $caseName'
              : 'Rate your recognition',
          style: AppTextStyles.bodySecondary,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            _buildRatingButton('Again', AppColors.error, SRSRating.again),
            const SizedBox(width: AppSpacing.sm),
            _buildRatingButton(
                'Hard', const Color(0xFFFFA726), SRSRating.hard),
            const SizedBox(width: AppSpacing.sm),
            _buildRatingButton('Good', AppColors.primary, SRSRating.good),
            const SizedBox(width: AppSpacing.sm),
            _buildRatingButton(
                'Easy', const Color(0xFF42A5F5), SRSRating.easy),
          ],
        ),
      ],
    );
  }

  Widget _buildRatingButton(String label, Color color, SRSRating rating) {
    return Expanded(
      child: ElevatedButton(
        onPressed: onRate != null ? () => onRate!(rating) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.15),
          foregroundColor: color,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.buttonRadius,
            side: BorderSide(color: color.withValues(alpha: 0.3)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}
