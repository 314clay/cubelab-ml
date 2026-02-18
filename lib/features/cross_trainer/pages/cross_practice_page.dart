import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cubelab/core/theme/app_colors.dart';
import 'package:cubelab/core/theme/app_text_styles.dart';
import 'package:cubelab/core/theme/app_spacing.dart';
import 'package:cubelab/features/cross_trainer/providers/cross_trainer_providers.dart';

/// Main cross training practice page.
///
/// Flow:
/// 1. Idle: Shows scramble + "Tap to start inspection"
/// 2. Inspecting: Timer counting (user studies scramble)
/// 3. Executing: Timer counting (user executes blindfolded)
/// 4. Reviewing: Shows times + Success/Fail buttons
class CrossPracticePage extends ConsumerWidget {
  const CrossPracticePage({super.key});

  String _formatTime(int ms) {
    final seconds = ms / 1000;
    return '${seconds.toStringAsFixed(2)}s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(crossPracticeProvider);

    // Show error state when repository/initialization fails
    if (state.error != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: AppSpacing.pagePaddingInsets,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Failed to load practice',
                    style: AppTextStyles.body.copyWith(color: AppColors.error),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Unable to connect to the server. Check your connection.',
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.pagePaddingInsets,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Difficulty selector
              _buildDifficultySelector(ref, state),
              const SizedBox(height: AppSpacing.lg),

              // Scramble display
              _buildScrambleDisplay(state),
              const Spacer(),

              // Timer area
              _buildTimerArea(ref, state),
              const Spacer(),

              // Action buttons
              _buildActions(ref, state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultySelector(WidgetRef ref, CrossPracticeState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PAIRS ATTEMPTING',
          style: AppTextStyles.overline,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: List.generate(4, (index) {
            final level = index + 1;
            final isSelected = state.pairsAttempting == level;
            return Padding(
              padding: EdgeInsets.only(right: index < 3 ? AppSpacing.sm : 0),
              child: ChoiceChip(
                label: Text('$level'),
                selected: isSelected,
                onSelected: state.phase == CrossPracticePhase.idle
                    ? (_) => ref.read(crossPracticeProvider.notifier).setPairsAttempting(level)
                    : null,
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surface,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildScrambleDisplay(CrossPracticeState state) {
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
          const Text(
            'SCRAMBLE',
            style: AppTextStyles.overline,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            state.currentScramble ?? 'Generating...',
            style: AppTextStyles.scramble,
          ),
        ],
      ),
    );
  }

  Widget _buildTimerArea(WidgetRef ref, CrossPracticeState state) {
    return GestureDetector(
      onTap: () {
        switch (state.phase) {
          case CrossPracticePhase.idle:
            ref.read(crossPracticeProvider.notifier).startInspection();
          case CrossPracticePhase.inspecting:
            ref.read(crossPracticeProvider.notifier).startExecution();
          case CrossPracticePhase.executing:
            ref.read(crossPracticeProvider.notifier).stopExecution();
          case CrossPracticePhase.reviewing:
            break;
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xl,
          horizontal: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: _timerBackgroundColor(state.phase),
          borderRadius: AppSpacing.cardRadius,
          border: Border.all(
            color: _timerBorderColor(state.phase),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Phase label
            if (state.phase != CrossPracticePhase.idle)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  _phaseLabel(state.phase),
                  style: AppTextStyles.overline.copyWith(
                    color: _timerBorderColor(state.phase),
                  ),
                ),
              ),

            // Time display
            Text(
              _displayTime(state),
              style: AppTextStyles.timerLarge.copyWith(
                color: _timerTextColor(state.phase),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Instruction
            Text(
              _instructionText(state.phase),
              style: AppTextStyles.bodySecondary.copyWith(
                color: AppColors.textSecondary,
              ),
            ),

            // Inspection time in execution/review phases
            if (state.phase == CrossPracticePhase.executing ||
                state.phase == CrossPracticePhase.reviewing)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'Inspection: ${_formatTime(state.inspectionTimeMs)}',
                  style: AppTextStyles.caption,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(WidgetRef ref, CrossPracticeState state) {
    if (state.phase == CrossPracticePhase.reviewing) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => ref.read(crossPracticeProvider.notifier).recordFail(),
              icon: const Icon(Icons.close, size: 20),
              label: const Text('Fail', style: AppTextStyles.buttonText),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppSpacing.buttonRadius,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => ref.read(crossPracticeProvider.notifier).recordSuccess(),
              icon: const Icon(Icons.check, size: 20),
              label: const Text('Success', style: AppTextStyles.buttonText),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppSpacing.buttonRadius,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (state.phase == CrossPracticePhase.idle) {
      return OutlinedButton.icon(
        onPressed: () => ref.read(crossPracticeProvider.notifier).generateNewScramble(),
        icon: const Icon(Icons.refresh, size: 20),
        label: Text(
          'New Scramble',
          style: AppTextStyles.buttonText.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          shape: const RoundedRectangleBorder(
            borderRadius: AppSpacing.buttonRadius,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  String _displayTime(CrossPracticeState state) {
    switch (state.phase) {
      case CrossPracticePhase.idle:
        return '0.00s';
      case CrossPracticePhase.inspecting:
        return _formatTime(state.inspectionTimeMs);
      case CrossPracticePhase.executing:
      case CrossPracticePhase.reviewing:
        return _formatTime(state.executionTimeMs);
    }
  }

  String _phaseLabel(CrossPracticePhase phase) {
    switch (phase) {
      case CrossPracticePhase.idle:
        return '';
      case CrossPracticePhase.inspecting:
        return 'INSPECTION';
      case CrossPracticePhase.executing:
        return 'EXECUTION';
      case CrossPracticePhase.reviewing:
        return 'REVIEW';
    }
  }

  String _instructionText(CrossPracticePhase phase) {
    switch (phase) {
      case CrossPracticePhase.idle:
        return 'Tap to start inspection';
      case CrossPracticePhase.inspecting:
        return 'Tap when ready to execute';
      case CrossPracticePhase.executing:
        return 'Tap to stop';
      case CrossPracticePhase.reviewing:
        return 'Rate your solve below';
    }
  }

  Color _timerBackgroundColor(CrossPracticePhase phase) {
    switch (phase) {
      case CrossPracticePhase.idle:
        return AppColors.surface;
      case CrossPracticePhase.inspecting:
        return AppColors.primary.withValues(alpha: 0.1);
      case CrossPracticePhase.executing:
        return AppColors.error.withValues(alpha: 0.1);
      case CrossPracticePhase.reviewing:
        return AppColors.surface;
    }
  }

  Color _timerBorderColor(CrossPracticePhase phase) {
    switch (phase) {
      case CrossPracticePhase.idle:
        return AppColors.border;
      case CrossPracticePhase.inspecting:
        return AppColors.primary;
      case CrossPracticePhase.executing:
        return AppColors.error;
      case CrossPracticePhase.reviewing:
        return AppColors.border;
    }
  }

  Color _timerTextColor(CrossPracticePhase phase) {
    switch (phase) {
      case CrossPracticePhase.idle:
        return AppColors.textTertiary;
      case CrossPracticePhase.inspecting:
        return AppColors.primary;
      case CrossPracticePhase.executing:
        return AppColors.textPrimary;
      case CrossPracticePhase.reviewing:
        return AppColors.primary;
    }
  }
}
