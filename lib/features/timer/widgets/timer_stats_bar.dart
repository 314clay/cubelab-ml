import 'package:flutter/material.dart';
import 'package:cubelab/core/theme/app_colors.dart';
import 'package:cubelab/core/theme/app_text_styles.dart';
import 'package:cubelab/core/theme/app_spacing.dart';
import 'package:cubelab/data/models/timer_session.dart';
import 'package:cubelab/data/models/user.dart';

class TimerStatsBar extends StatelessWidget {
  final TimerSession? session;
  final TimerStats? allTimeStats;

  const TimerStatsBar({
    super.key,
    this.session,
    this.allTimeStats,
  });

  String _formatMs(int? ms) {
    if (ms == null) return '-';
    final seconds = ms / 1000;
    return seconds.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildStat('PB Single', _formatMs(allTimeStats?.pbSingleMs ?? session?.bestSingle)),
        _buildStat('Ao5', _formatMs(session?.currentAo5)),
        _buildStat('Ao12', _formatMs(session?.currentAo12)),
        _buildStat('Solves', '${session?.solveCount ?? 0}'),
      ],
    );
  }

  Widget _buildStat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
