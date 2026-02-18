import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cubelab/core/theme/app_colors.dart';
import 'package:cubelab/core/utils/error_utils.dart';
import 'package:cubelab/core/theme/app_text_styles.dart';
import 'package:cubelab/core/theme/app_spacing.dart';
import 'package:cubelab/data/models/daily_challenge.dart';
import 'package:cubelab/shared/providers/repository_providers.dart';

/// Community Solves Page - shows ranked list of community solves for today's scramble
class CommunitySolvesPage extends ConsumerWidget {
  const CommunitySolvesPage({super.key});

  String _formatTime(int ms) {
    final seconds = ms / 1000;
    return '${seconds.toStringAsFixed(2)}s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<List<DailyScrambleSolve>> futuresolves;
    try {
      futuresolves = ref
          .read(dailyChallengeRepositoryProvider)
          .getCommunitySolves(DateTime.now());
    } catch (e) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: _buildErrorView(friendlyError(e.toString())),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<List<DailyScrambleSolve>>(
        future: futuresolves,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (snapshot.hasError) {
            return _buildErrorView(friendlyError(snapshot.error.toString()));
          }

          final solves = snapshot.data ?? [];

          if (solves.isEmpty) {
            return _buildEmptyState();
          }

          return _buildSolvesList(solves);
        },
      ),
    );
  }

  Widget _buildSolvesList(List<DailyScrambleSolve> solves) {
    return ListView.builder(
      padding: AppSpacing.pagePaddingInsets,
      itemCount: solves.length,
      itemBuilder: (context, index) {
        final solve = solves[index];
        final rank = index + 1;
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppSpacing.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              // Rank number
              SizedBox(
                width: 32,
                child: Text(
                  '$rank',
                  style: AppTextStyles.h3.copyWith(
                    color: rank <= 3 ? AppColors.primary : AppColors.textTertiary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Username
              Expanded(
                child: Text(
                  solve.username ?? 'Anonymous',
                  style: AppTextStyles.body,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Time
              Text(
                _formatTime(solve.timeMs),
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: AppSpacing.pagePaddingInsets,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline,
                size: 64,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text(
              'No Community Solves Yet',
              style: AppTextStyles.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Be the first to submit a solve for today\'s scramble!',
              style: AppTextStyles.bodySecondary,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: AppSpacing.pagePaddingInsets,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Failed to Load',
              style: AppTextStyles.h3.copyWith(color: AppColors.error),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              error,
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
