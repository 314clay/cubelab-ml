import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cubelab/core/theme/app_colors.dart';
import 'package:cubelab/core/theme/app_text_styles.dart';
import 'package:cubelab/core/theme/app_spacing.dart';
import 'package:cubelab/data/models/srs_state.dart';
import 'package:cubelab/features/algorithm/providers/algorithm_providers.dart';

/// Active training/drill page with timer and SRS rating
class AlgorithmTrainingPage extends ConsumerWidget {
  const AlgorithmTrainingPage({super.key});

  String _formatTime(int ms) {
    final seconds = ms / 1000;
    return '${seconds.toStringAsFixed(2)}s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(trainingProvider);

    if (state.error != null) {
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
                'Failed to load training',
                style: AppTextStyles.h3.copyWith(color: AppColors.error),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Unable to connect to the server. Check your connection.',
                style: AppTextStyles.bodySecondary,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: AppSpacing.pagePaddingInsets,
        child: switch (state.phase) {
          TrainingPhase.idle => _buildIdleView(context, ref, state),
          TrainingPhase.showing => _buildShowingView(context, ref, state),
          TrainingPhase.timing => _buildTimingView(context, ref, state),
          TrainingPhase.reviewing => _buildReviewingView(context, ref, state),
        },
      ),
    );
  }

  Widget _buildIdleView(
    BuildContext context,
    WidgetRef ref,
    TrainingState state,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        // Show session results if we just finished
        if (state.casesCompleted > 0) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppSpacing.cardRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.emoji_events_outlined,
                  size: 48,
                  color: AppColors.primary,
                ),
                const SizedBox(height: AppSpacing.md),
                const Text('Session Complete', style: AppTextStyles.h2),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatColumn(
                      'Cases',
                      state.casesCompleted.toString(),
                    ),
                    _buildStatColumn(
                      'Accuracy',
                      state.casesCompleted > 0
                          ? '${((state.casesCorrect / state.casesCompleted) * 100).toStringAsFixed(0)}%'
                          : '0%',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ] else ...[
          const Icon(
            Icons.fitness_center,
            size: 64,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Algorithm Training',
            style: AppTextStyles.h2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Practice algorithm recognition and execution',
            style: AppTextStyles.bodySecondary,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        ElevatedButton(
          onPressed: () => ref.read(trainingProvider.notifier).startTraining(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textPrimary,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            shape: const RoundedRectangleBorder(
              borderRadius: AppSpacing.buttonRadius,
            ),
          ),
          child: Text(
            state.casesCompleted > 0 ? 'Train Again' : 'Start Training',
            style: AppTextStyles.buttonText,
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildShowingView(
    BuildContext context,
    WidgetRef ref,
    TrainingState state,
  ) {
    final alg = state.currentAlgorithm;
    if (alg == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Session progress
        _buildSessionProgress(state),
        const Spacer(),

        // Algorithm case display
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppSpacing.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              // Image placeholder
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: AppSpacing.cardRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.grid_view_rounded,
                  size: 48,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(alg.name, style: AppTextStyles.h2),
              if (alg.subset != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${alg.set.name.toUpperCase()} - ${alg.subset}',
                  style: AppTextStyles.bodySecondary,
                ),
              ],
            ],
          ),
        ),

        const Spacer(),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () =>
                    ref.read(trainingProvider.notifier).startTimer(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppSpacing.buttonRadius,
                  ),
                ),
                child: Text(
                  'Show Solution',
                  style: AppTextStyles.buttonText.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: ElevatedButton(
                onPressed: () =>
                    ref.read(trainingProvider.notifier).startTimer(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppSpacing.buttonRadius,
                  ),
                ),
                child: const Text('I Know This!', style: AppTextStyles.buttonText),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimingView(
    BuildContext context,
    WidgetRef ref,
    TrainingState state,
  ) {
    return GestureDetector(
      onTap: () => ref.read(trainingProvider.notifier).stopTimer(),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSessionProgress(state),
          const Spacer(),
          Center(
            child: Text(
              _formatTime(state.timeMs),
              style: AppTextStyles.timerLarge.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Center(
            child: Text(
              'Tap anywhere to stop',
              style: AppTextStyles.bodySecondary,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildReviewingView(
    BuildContext context,
    WidgetRef ref,
    TrainingState state,
  ) {
    final alg = state.currentAlgorithm;
    if (alg == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSessionProgress(state),
        const Spacer(),

        // Time result
        Center(
          child: Text(
            _formatTime(state.timeMs),
            style: AppTextStyles.timerLarge.copyWith(color: AppColors.primary),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Solution display
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppSpacing.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(alg.name, style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.sm),
              for (final algStr in alg.defaultAlgs)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(algStr, style: AppTextStyles.scramble),
                ),
            ],
          ),
        ),

        const Spacer(),

        // SRS rating buttons
        const Text(
          'How did it go?',
          style: AppTextStyles.bodySecondary,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            _buildRatingButton(ref, 'Again', SRSRating.again, AppColors.error),
            const SizedBox(width: AppSpacing.sm),
            _buildRatingButton(
                ref, 'Hard', SRSRating.hard, const Color(0xFFFF9800)),
            const SizedBox(width: AppSpacing.sm),
            _buildRatingButton(
                ref, 'Good', SRSRating.good, AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            _buildRatingButton(
                ref, 'Easy', SRSRating.easy, const Color(0xFF2196F3)),
          ],
        ),
      ],
    );
  }

  Widget _buildRatingButton(
    WidgetRef ref,
    String label,
    SRSRating rating,
    Color color,
  ) {
    return Expanded(
      child: ElevatedButton(
        onPressed: () =>
            ref.read(trainingProvider.notifier).ratePerformance(rating),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: AppColors.textPrimary,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          shape: const RoundedRectangleBorder(
            borderRadius: AppSpacing.buttonRadius,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.buttonText.copyWith(fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildSessionProgress(TrainingState state) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Cases: ${state.casesCompleted}',
            style: AppTextStyles.caption,
          ),
          const SizedBox(width: AppSpacing.lg),
          Text(
            'Accuracy: ${state.casesCompleted > 0 ? ((state.casesCorrect / state.casesCompleted) * 100).toStringAsFixed(0) : 0}%',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.h2),
        const SizedBox(height: AppSpacing.xs),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}
