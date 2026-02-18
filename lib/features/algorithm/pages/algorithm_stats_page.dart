import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cubelab/core/theme/app_colors.dart';
import 'package:cubelab/core/utils/error_utils.dart';
import 'package:cubelab/core/theme/app_text_styles.dart';
import 'package:cubelab/core/theme/app_spacing.dart';
import 'package:cubelab/data/models/stats.dart';
import 'package:cubelab/features/algorithm/providers/algorithm_providers.dart';

/// Statistics dashboard for algorithm training
class AlgorithmStatsPage extends ConsumerWidget {
  const AlgorithmStatsPage({super.key});

  String _formatTime(int ms) {
    final seconds = ms / 1000;
    return '${seconds.toStringAsFixed(2)}s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(algorithmStatsProvider);

    return statsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (error, _) => Center(
        child: Padding(
          padding: AppSpacing.pagePaddingInsets,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.error,
              ),
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
      data: (stats) => _buildStatsView(stats),
    );
  }

  Widget _buildStatsView(AlgorithmStats stats) {
    return ListView(
      padding: const EdgeInsets.only(
        left: AppSpacing.pagePadding,
        right: AppSpacing.pagePadding,
        top: AppSpacing.md,
        bottom: AppSpacing.xl,
      ),
      children: [
        // Summary cards
        _buildSummaryGrid(stats),
        const SizedBox(height: AppSpacing.lg),

        // Per-set breakdown
        const Text('By Set', style: AppTextStyles.h3),
        const SizedBox(height: AppSpacing.md),
        if (stats.bySet.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(
              child: Text(
                'No set data yet',
                style: AppTextStyles.bodySecondary,
              ),
            ),
          )
        else
          ...stats.bySet.entries.map(
            (entry) => _buildSetStatsCard(entry.value),
          ),

        // Weakest cases
        if (stats.weakestCases.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const Text('Weakest Cases', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.md),
          ...stats.weakestCases.map(
            (caseId) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppSpacing.buttonRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 20,
                      color: Color(0xFFFF9800),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(caseId, style: AppTextStyles.body),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryGrid(AlgorithmStats stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.5,
      children: [
        _buildSummaryCard(
          'Total Learned',
          stats.totalLearned.toString(),
          Icons.school,
          AppColors.primary,
        ),
        _buildSummaryCard(
          'Total Drills',
          stats.totalDrills.toString(),
          Icons.fitness_center,
          const Color(0xFF2196F3),
        ),
        _buildSummaryCard(
          'Avg Time',
          _formatTime(stats.avgTimeMs),
          Icons.timer,
          const Color(0xFFFF9800),
        ),
        _buildSummaryCard(
          'Due Today',
          stats.dueToday.toString(),
          Icons.schedule,
          stats.dueToday > 0 ? AppColors.error : AppColors.success,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppTextStyles.h2.copyWith(color: color),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }

  Widget _buildSetStatsCard(AlgorithmSetStats setStats) {
    final progress =
        setStats.total > 0 ? setStats.learned / setStats.total : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppSpacing.cardRadius,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  setStats.set.name.toUpperCase(),
                  style: AppTextStyles.h3.copyWith(fontSize: 16),
                ),
                Text(
                  '${setStats.learned}/${setStats.total}',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: AppSpacing.buttonRadius,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.background,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 6,
              ),
            ),
            if (setStats.avgTimeMs > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Avg: ${_formatTime(setStats.avgTimeMs)}',
                style: AppTextStyles.caption,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
