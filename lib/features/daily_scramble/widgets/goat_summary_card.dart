import 'package:flutter/material.dart';
import 'package:cubelab/core/theme/app_colors.dart';
import 'package:cubelab/core/theme/app_text_styles.dart';
import 'package:cubelab/core/theme/app_spacing.dart';
import 'package:cubelab/core/theme/widgets/app_card.dart';
import 'package:cubelab/data/models/pro_solve.dart';

/// Card showing a ProSolve summary for the GOAT list.
class GoatSummaryCard extends StatelessWidget {
  final ProSolve proSolve;
  final VoidCallback onTap;

  const GoatSummaryCard({
    super.key,
    required this.proSolve,
    required this.onTap,
  });

  String _formatTime(int ms) {
    final seconds = ms / 1000;
    return '${seconds.toStringAsFixed(2)}s';
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          // Solver info on left
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  proSolve.solver,
                  style: AppTextStyles.body,
                ),
                if (proSolve.reconstruction != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'View reconstruction \u2192',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Time on right
          Text(
            _formatTime(proSolve.timeMs),
            style: AppTextStyles.h3.copyWith(
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
