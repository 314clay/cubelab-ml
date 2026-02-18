import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cubelab/core/theme/app_colors.dart';
import 'package:cubelab/core/utils/error_utils.dart';
import 'package:cubelab/core/theme/app_text_styles.dart';
import 'package:cubelab/core/theme/app_spacing.dart';
import 'package:cubelab/features/daily_scramble/models/daily_scramble_state.dart';
import 'package:cubelab/features/daily_scramble/providers/daily_scramble_providers.dart';
import 'package:cubelab/features/daily_scramble/widgets/scramble_display.dart';
import 'package:cubelab/features/daily_scramble/widgets/solve_timer.dart';
import 'package:cubelab/features/daily_scramble/pages/daily_scramble_submit_page.dart';
import 'package:cubelab/features/daily_scramble/pages/community_solves_page.dart';
import 'package:cubelab/features/daily_scramble/pages/daily_scramble_results_page.dart';

/// Daily Scramble solve page.
///
/// Flow:
/// 1. Display today's scramble with cube placeholder
/// 2. User holds to ready, releases to start timer
/// 3. User taps to stop timer
/// 4. Shows time with "Try Again" and "Continue" buttons
///
/// Uses DailyScrambleProvider for state management.
class DailyScramblePage extends ConsumerWidget {
  const DailyScramblePage({super.key});

  void _continue(BuildContext context, WidgetRef ref) {
    final state = ref.read(dailyScrambleProvider);

    if (state.challenge != null && state.elapsedMs > 0) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DailyScrambleSubmitPage(
            challenge: state.challenge!,
            solveTimeMs: state.elapsedMs,
          ),
        ),
      );
    }
  }

  String _formatTime(int ms) {
    final seconds = ms / 1000;
    return '${seconds.toStringAsFixed(2)}s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dailyScrambleProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Today's Scramble",
          style: AppTextStyles.h3,
        ),
      ),
      body: _buildBody(context, ref, state),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, DailyScrambleState state) {
    // Loading state
    if (state.phase == DailySolvePhase.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    // Error state
    if (state.error != null) {
      return Center(
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
                'Failed to load scramble',
                style: AppTextStyles.body.copyWith(color: AppColors.error),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                friendlyError(state.error!),
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // No challenge available
    if (state.challenge == null) {
      return const Center(
        child: Text('No challenge available'),
      );
    }

    // Already completed state - will be enhanced in Task 9
    if (state.phase == DailySolvePhase.alreadyCompleted) {
      return _buildAlreadyCompletedView(context, ref, state);
    }

    // Normal solve flow
    return SafeArea(
      child: Padding(
        padding: AppSpacing.pagePaddingInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Scramble display with cube placeholder
            ScrambleDisplay(scramble: state.challenge!.scramble),

            const Spacer(),

            // Timer or result section
            if (state.phase != DailySolvePhase.stopped) ...[
              // Active timer
              SolveTimer(
                phase: state.phase,
                elapsedMs: state.elapsedMs,
                onStartHolding: () => ref.read(dailyScrambleProvider.notifier).startHolding(),
                onCancelHold: () => ref.read(dailyScrambleProvider.notifier).cancelHold(),
                onStartTimer: () => ref.read(dailyScrambleProvider.notifier).startTimer(),
                onStopTimer: () => ref.read(dailyScrambleProvider.notifier).stopTimer(),
              ),
            ] else ...[
              // Result display
              _buildResultSection(context, ref, state),
            ],

            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildResultSection(BuildContext context, WidgetRef ref, DailyScrambleState state) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Time display
          Text(
            _formatTime(state.elapsedMs),
            style: AppTextStyles.timerLarge.copyWith(
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Solve complete',
            style: AppTextStyles.bodySecondary,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Action buttons
          Row(
            children: [
              // Try Again button
              Expanded(
                child: OutlinedButton(
                  onPressed: () => ref.read(dailyScrambleProvider.notifier).reset(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppSpacing.buttonRadius,
                    ),
                  ),
                  child: Text(
                    'Try Again',
                    style: AppTextStyles.buttonText.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Continue button
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _continue(context, ref),
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
                      Text(
                        'Continue',
                        style: AppTextStyles.buttonText,
                      ),
                      SizedBox(width: AppSpacing.xs),
                      Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// View shown when user has already completed today's challenge
  Widget _buildAlreadyCompletedView(BuildContext context, WidgetRef ref, DailyScrambleState state) {
    return SafeArea(
      child: Padding(
        padding: AppSpacing.pagePaddingInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Scramble display (show but don't allow solving)
            if (state.challenge != null)
              ScrambleDisplay(scramble: state.challenge!.scramble),

            const Spacer(),

            // Completed state card
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppSpacing.cardRadius,
                border: Border.all(color: AppColors.success, width: 2),
              ),
              child: Column(
                children: [
                  // Success icon
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      size: 48,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Title
                  const Text(
                    'Challenge Complete!',
                    style: AppTextStyles.h2,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // User's time
                  if (state.userSolve != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Your Time',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            _formatTime(state.userSolve!.timeMs),
                            style: AppTextStyles.timerLarge.copyWith(
                              color: AppColors.primary,
                              fontSize: 32,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // Message
                  Text(
                    'Come back tomorrow for a new challenge!',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Action buttons
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // View Community Solves button
                ElevatedButton(
                  onPressed: () {
                    // TODO: Navigate to community page in section (Task 7)
                    // For now, navigate to the standalone community page
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CommunitySolvesPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
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
                      Text(
                        'View Community Solves',
                        style: AppTextStyles.buttonText,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // View GOAT Reconstructions button
                OutlinedButton(
                  onPressed: () {
                    // TODO: Navigate to GOAT page in section (Task 7)
                    // For now, show the results page which has GOAT preview
                    if (state.userSolve != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DailyScrambleResultsPage(
                            userSolveTimeMs: state.userSolve!.timeMs,
                          ),
                        ),
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppSpacing.buttonRadius,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.emoji_events_outlined, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'View GOAT Reconstructions',
                        style: AppTextStyles.buttonText.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}
