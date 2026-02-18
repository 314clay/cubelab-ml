import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cubelab/core/theme/app_colors.dart';
import 'package:cubelab/core/utils/error_utils.dart';
import 'package:cubelab/core/theme/app_text_styles.dart';
import 'package:cubelab/core/theme/app_spacing.dart';
import 'package:cubelab/data/models/stats.dart';
import 'package:cubelab/features/cross_trainer/providers/cross_trainer_providers.dart';

/// Stats dashboard for cross training performance.
class CrossStatsPage extends ConsumerWidget {
  const CrossStatsPage({super.key});

  String _formatTime(int ms) {
    final seconds = ms / 1000;
    return '${seconds.toStringAsFixed(2)}s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(crossStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: statsAsync.when(
          data: (stats) => stats.totalSolves == 0
              ? _buildEmptyState()
              : _buildStats(stats),
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (error, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Failed to load stats',
                  style: AppTextStyles.body.copyWith(color: AppColors.error),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  friendlyError(error.toString()),
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: AppSpacing.pagePaddingInsets,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 64,
              color: AppColors.textTertiary,
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              'No stats yet',
              style: AppTextStyles.h2,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Complete some cross training solves\nto see your stats here.',
              style: AppTextStyles.bodySecondary,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(CrossStats stats) {
    return SingleChildScrollView(
      padding: AppSpacing.pagePaddingInsets,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Overview cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Solves',
                  '${stats.totalSolves}',
                  Icons.fitness_center,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildStatCard(
                  'Success Rate',
                  '${(stats.successRate * 100).toStringAsFixed(1)}%',
                  Icons.check_circle_outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Avg Inspection',
                  _formatTime(stats.avgInspectionTimeMs),
                  Icons.visibility,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildStatCard(
                  'Avg Execution',
                  _formatTime(stats.avgExecutionTimeMs),
                  Icons.speed,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildStatCard(
            'Sessions',
            '${stats.sessionCount}',
            Icons.calendar_today,
          ),

          // Per-level breakdown
          if (stats.byLevel.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const Text('BY LEVEL', style: AppTextStyles.overline),
            const SizedBox(height: AppSpacing.sm),
            ...stats.byLevel.entries.map((entry) =>
                _buildLevelCard(entry.key, entry.value)),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
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
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppTextStyles.h2.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }

  Widget _buildLevelCard(int level, LevelStats levelStats) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppSpacing.cardRadius,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Level badge
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: AppSpacing.buttonRadius,
              ),
              alignment: Alignment.center,
              child: Text(
                '$level',
                style: AppTextStyles.h3.copyWith(color: AppColors.primary),
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // Stats
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$level pair${level > 1 ? 's' : ''}',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${levelStats.solveCount} solves  |  '
                    '${(levelStats.successRate * 100).toStringAsFixed(0)}% success',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),

            // Times
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTime(levelStats.avgInspectionTimeMs),
                  style: AppTextStyles.body.copyWith(color: AppColors.primary),
                ),
                Text(
                  _formatTime(levelStats.avgExecutionTimeMs),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
