import 'package:flutter/material.dart';
import 'package:cubelab/core/theme/app_colors.dart';
import 'package:cubelab/core/theme/app_text_styles.dart';
import 'package:cubelab/core/theme/app_spacing.dart';
import 'package:cubelab/data/models/cube_scan_result.dart';

/// Expandable card displaying a single solve path with its steps.
class SolvePathCard extends StatelessWidget {
  final SolvePath path;
  final int rank;
  final bool isExpanded;
  final VoidCallback onTap;

  const SolvePathCard({
    super.key,
    required this.path,
    required this.rank,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Header (always visible)
          InkWell(
            onTap: onTap,
            borderRadius: isExpanded
                ? const BorderRadius.vertical(top: Radius.circular(12))
                : AppSpacing.cardRadius,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$rank',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(path.description, style: AppTextStyles.body),
                  ),
                  Text(
                    '${path.totalMoves} moves',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Steps (visible when expanded)
          if (isExpanded) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  for (int i = 0; i < path.steps.length; i++) ...[
                    if (i > 0)
                      Padding(
                        padding:
                            const EdgeInsets.only(left: 14, top: 4, bottom: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 2,
                              height: 16,
                              color: AppColors.border,
                            ),
                          ],
                        ),
                      ),
                    _StepRow(step: path.steps[i], stepNumber: i + 1),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final SolveStep step;
  final int stepNumber;

  const _StepRow({required this.step, required this.stepNumber});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$stepNumber',
            style: AppTextStyles.caption,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${step.algorithmSet}: ',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(step.caseName, style: AppTextStyles.body),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(step.algorithm, style: AppTextStyles.scramble),
            ],
          ),
        ),
        Text('${step.moveCount}', style: AppTextStyles.caption),
      ],
    );
  }
}
