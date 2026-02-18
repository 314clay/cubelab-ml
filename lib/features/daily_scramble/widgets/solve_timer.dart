import 'package:flutter/material.dart';
import 'package:cubelab/core/theme/app_colors.dart';
import 'package:cubelab/core/theme/app_text_styles.dart';
import 'package:cubelab/core/theme/app_spacing.dart';
import 'package:cubelab/features/daily_scramble/models/daily_scramble_state.dart';

/// Display-only timer widget for daily scramble solves.
///
/// This widget reflects the state from DailyScrambleProvider and calls
/// callbacks for user interactions. All timer logic is managed by the provider.
///
/// Flow:
/// 1. notStarted: Shows "0.00" with "Hold to ready" instruction
/// 2. holding: User holding, background turns green, "Release to start"
/// 3. solving: Timer counting up, tap anywhere to stop
/// 4. stopped: Shows final time
class SolveTimer extends StatelessWidget {
  /// Current phase of the solve flow (from provider)
  final DailySolvePhase phase;

  /// Elapsed time in milliseconds (from provider)
  final int elapsedMs;

  /// Called when user starts holding
  final VoidCallback onStartHolding;

  /// Called when user cancels hold
  final VoidCallback onCancelHold;

  /// Called when timer should start (on release)
  final VoidCallback onStartTimer;

  /// Called when timer should stop
  final VoidCallback onStopTimer;

  const SolveTimer({
    super.key,
    required this.phase,
    required this.elapsedMs,
    required this.onStartHolding,
    required this.onCancelHold,
    required this.onStartTimer,
    required this.onStopTimer,
  });

  void _onPointerDown(PointerDownEvent event) {
    if (phase == DailySolvePhase.notStarted) {
      onStartHolding();
    } else if (phase == DailySolvePhase.solving) {
      onStopTimer();
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (phase == DailySolvePhase.holding) {
      onStartTimer();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (phase == DailySolvePhase.holding) {
      onCancelHold();
    }
  }

  String _formatTime(int ms) {
    final seconds = ms / 1000;
    return seconds.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xl,
          horizontal: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: _getBackgroundColor(),
          borderRadius: AppSpacing.cardRadius,
          border: Border.all(
            color: _getBorderColor(),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Timer display
            Text(
              _formatTime(elapsedMs),
              style: AppTextStyles.timerLarge.copyWith(
                color: _getTimerTextColor(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Instruction text
            Text(
              _getInstructionText(),
              style: AppTextStyles.bodySecondary.copyWith(
                color: _getInstructionTextColor(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (phase) {
      case DailySolvePhase.loading:
      case DailySolvePhase.notStarted:
        return AppColors.surface;
      case DailySolvePhase.holding:
        return AppColors.success.withValues(alpha: 0.2);
      case DailySolvePhase.solving:
        return AppColors.surface;
      case DailySolvePhase.stopped:
        return AppColors.surface;
      case DailySolvePhase.alreadyCompleted:
        return AppColors.surface;
    }
  }

  Color _getBorderColor() {
    switch (phase) {
      case DailySolvePhase.loading:
      case DailySolvePhase.notStarted:
        return AppColors.border;
      case DailySolvePhase.holding:
        return AppColors.success;
      case DailySolvePhase.solving:
        return AppColors.primary;
      case DailySolvePhase.stopped:
        return AppColors.border;
      case DailySolvePhase.alreadyCompleted:
        return AppColors.border;
    }
  }

  Color _getTimerTextColor() {
    switch (phase) {
      case DailySolvePhase.loading:
      case DailySolvePhase.notStarted:
        return AppColors.textTertiary;
      case DailySolvePhase.holding:
        return AppColors.success;
      case DailySolvePhase.solving:
        return AppColors.textPrimary;
      case DailySolvePhase.stopped:
        return AppColors.primary;
      case DailySolvePhase.alreadyCompleted:
        return AppColors.textSecondary;
    }
  }

  Color _getInstructionTextColor() {
    switch (phase) {
      case DailySolvePhase.loading:
      case DailySolvePhase.notStarted:
        return AppColors.textSecondary;
      case DailySolvePhase.holding:
        return AppColors.success;
      case DailySolvePhase.solving:
        return AppColors.textSecondary;
      case DailySolvePhase.stopped:
        return AppColors.textSecondary;
      case DailySolvePhase.alreadyCompleted:
        return AppColors.textSecondary;
    }
  }

  String _getInstructionText() {
    switch (phase) {
      case DailySolvePhase.loading:
        return 'Loading...';
      case DailySolvePhase.notStarted:
        return 'Hold anywhere to start';
      case DailySolvePhase.holding:
        return 'Release to start';
      case DailySolvePhase.solving:
        return 'Tap to stop';
      case DailySolvePhase.stopped:
        return 'Solve complete';
      case DailySolvePhase.alreadyCompleted:
        return 'Challenge completed';
    }
  }
}
