import 'package:flutter/material.dart';
import 'package:cubelab/core/theme/app_colors.dart';
import 'package:cubelab/core/theme/app_text_styles.dart';
import 'package:cubelab/core/theme/app_spacing.dart';
import 'package:cubelab/data/models/timer_solve.dart';

class SolveList extends StatelessWidget {
  final List<TimerSolve> solves;
  final void Function(String id) onDelete;
  final void Function(String id, int? currentPenalty) onTogglePenalty;

  const SolveList({
    super.key,
    required this.solves,
    required this.onDelete,
    required this.onTogglePenalty,
  });

  String _formatMs(int ms) {
    final seconds = ms / 1000;
    return seconds.toStringAsFixed(2);
  }

  String _penaltyLabel(int? penalty) {
    if (penalty == 2) return '+2';
    if (penalty == -1) return 'DNF';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (solves.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'No solves yet',
            style: AppTextStyles.bodySecondary,
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: solves.length,
      itemBuilder: (context, index) {
        final solve = solves[index];
        final solveNumber = solves.length - index;

        return Dismissible(
          key: Key(solve.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            color: AppColors.error,
            child: const Icon(Icons.delete, color: AppColors.textPrimary),
          ),
          onDismissed: (_) => onDelete(solve.id),
          child: InkWell(
            onTap: () => onTogglePenalty(solve.id, solve.penalty),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.border,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Solve number
                  SizedBox(
                    width: 32,
                    child: Text(
                      '$solveNumber.',
                      style: AppTextStyles.caption,
                    ),
                  ),

                  // Time
                  Expanded(
                    child: Text(
                      solve.isDNF ? 'DNF' : _formatMs(solve.displayTimeMs),
                      style: AppTextStyles.body.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        color: solve.isDNF ? AppColors.error : AppColors.textPrimary,
                      ),
                    ),
                  ),

                  // Penalty indicator
                  if (solve.penalty != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.15),
                        borderRadius: AppSpacing.buttonRadius,
                      ),
                      child: Text(
                        _penaltyLabel(solve.penalty),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  const SizedBox(width: AppSpacing.sm),

                  // Timestamp
                  Text(
                    '${solve.timestamp.hour.toString().padLeft(2, '0')}:${solve.timestamp.minute.toString().padLeft(2, '0')}',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
