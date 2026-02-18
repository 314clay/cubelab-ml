import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cubelab/core/theme/app_colors.dart';
import 'package:cubelab/core/theme/app_text_styles.dart';
import 'package:cubelab/core/theme/app_spacing.dart';
import 'package:cubelab/core/utils/navigation_utils.dart';
import 'package:cubelab/data/models/daily_challenge.dart';
import 'package:cubelab/data/models/pro_solve.dart';
import 'package:cubelab/features/daily_scramble/pages/community_solves_page.dart';
import 'package:cubelab/features/daily_scramble/pages/goat_reconstruction_page.dart';
import 'package:cubelab/features/daily_scramble/providers/daily_scramble_providers.dart';
import 'package:cubelab/features/daily_scramble/widgets/goat_summary_card.dart';
import 'package:cubelab/shared/providers/repository_providers.dart';

/// Results page shown after submitting a daily scramble solve.
class DailyScrambleResultsPage extends ConsumerWidget {
  final int userSolveTimeMs;

  const DailyScrambleResultsPage({
    super.key,
    required this.userSolveTimeMs,
  });

  String _formatTime(int ms) {
    final seconds = ms / 1000;
    return '${seconds.toStringAsFixed(2)}s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Results', style: AppTextStyles.h3),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.pagePaddingInsets,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User's time with success icon
              _buildTimeCard(),
              const SizedBox(height: AppSpacing.lg),

              // Community ranking section
              _buildRankingSection(ref),
              const SizedBox(height: AppSpacing.lg),

              // GOAT preview section
              _buildGoatPreview(context, ref),
              const SizedBox(height: AppSpacing.xl),

              // Action buttons
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.cardRadius,
        border: Border.all(color: AppColors.success, width: 2),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.check_circle,
            size: 48,
            color: AppColors.success,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('Your Time', style: AppTextStyles.bodySecondary),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _formatTime(userSolveTimeMs),
            style: AppTextStyles.timerLarge.copyWith(
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingSection(WidgetRef ref) {
    return FutureBuilder<List<DailyScrambleSolve>>(
      future: ref
          .read(dailyChallengeRepositoryProvider)
          .getCommunitySolves(DateTime.now()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppSpacing.cardRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final solves = snapshot.data ?? [];
        int rank = 1;
        for (final solve in solves) {
          if (solve.timeMs < userSolveTimeMs) {
            rank++;
          }
        }
        final total = solves.isEmpty ? 1 : solves.length;

        return Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppSpacing.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              const Text('Your Ranking', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '#$rank',
                    style: AppTextStyles.timerLarge.copyWith(
                      color: AppColors.primary,
                      fontSize: 36,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'of $total',
                    style: AppTextStyles.bodySecondary,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGoatPreview(BuildContext context, WidgetRef ref) {
    final challengeAsync = ref.watch(todaysScrambleProvider);

    return challengeAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (challenge) {
        return FutureBuilder<List<ProSolve>>(
          future: ref
              .read(dailyChallengeRepositoryProvider)
              .getAllProSolvesForScramble(challenge.scramble),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox.shrink();
            }

            final proSolves = snapshot.data ?? [];
            if (proSolves.isEmpty) return const SizedBox.shrink();

            final firstSolve = proSolves.first;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('GOAT Reconstruction', style: AppTextStyles.h3),
                const SizedBox(height: AppSpacing.md),
                GoatSummaryCard(
                  proSolve: firstSolve,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GoatReconstructionPage(
                          proSolve: firstSolve,
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CommunitySolvesPage(),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textPrimary,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            shape: const RoundedRectangleBorder(
              borderRadius: AppSpacing.buttonRadius,
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline, size: 20),
              SizedBox(width: AppSpacing.sm),
              Text('View Community Solves', style: AppTextStyles.buttonText),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(
          onPressed: () => NavigationUtils.goHome(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            shape: const RoundedRectangleBorder(
              borderRadius: AppSpacing.buttonRadius,
            ),
          ),
          child: Text(
            'Back to Home',
            style: AppTextStyles.buttonText.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
