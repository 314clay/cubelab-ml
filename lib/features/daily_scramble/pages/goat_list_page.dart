import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cubelab/core/theme/app_colors.dart';
import 'package:cubelab/core/utils/error_utils.dart';
import 'package:cubelab/core/theme/app_text_styles.dart';
import 'package:cubelab/core/theme/app_spacing.dart';
import 'package:cubelab/data/models/pro_solve.dart';
import 'package:cubelab/features/daily_scramble/providers/daily_scramble_providers.dart';
import 'package:cubelab/features/daily_scramble/widgets/goat_summary_card.dart';
import 'package:cubelab/features/daily_scramble/pages/goat_reconstruction_page.dart';
import 'package:cubelab/shared/providers/repository_providers.dart';

/// GOAT List Page - shows all professional reconstructions for today's scramble
class GoatListPage extends ConsumerWidget {
  const GoatListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengeAsync = ref.watch(todaysScrambleProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: challengeAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, stack) => _buildErrorView(context, friendlyError(error.toString())),
        data: (challenge) {
          // Fetch pro solves for this scramble
          return FutureBuilder<List<ProSolve>>(
            future: ref
                .read(dailyChallengeRepositoryProvider)
                .getAllProSolvesForScramble(challenge.scramble),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              if (snapshot.hasError) {
                return _buildErrorView(context, friendlyError(snapshot.error.toString()));
              }

              final proSolves = snapshot.data ?? [];

              if (proSolves.isEmpty) {
                return _buildEmptyState(context);
              }

              return _buildProSolvesList(context, proSolves);
            },
          );
        },
      ),
    );
  }

  Widget _buildProSolvesList(BuildContext context, List<ProSolve> proSolves) {
    return RefreshIndicator(
      onRefresh: () async {
        // Trigger a rebuild by waiting a bit
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView.builder(
        padding: AppSpacing.pagePaddingInsets,
        itemCount: proSolves.length,
        itemBuilder: (context, index) {
          final proSolve = proSolves[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: GoatSummaryCard(
              proSolve: proSolve,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GoatReconstructionPage(
                      proSolve: proSolve,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
                Icons.emoji_events_outlined,
                size: 64,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text(
              'No GOAT Reconstructions Yet',
              style: AppTextStyles.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Professional reconstructions for this scramble will appear here once available.',
              style: AppTextStyles.bodySecondary,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, String error) {
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

