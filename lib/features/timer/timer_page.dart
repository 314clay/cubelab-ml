import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cubelab/core/theme/app_colors.dart';
import 'package:cubelab/core/theme/app_text_styles.dart';
import 'package:cubelab/core/theme/app_spacing.dart';
import 'package:cubelab/features/timer/providers/timer_providers.dart';
import 'package:cubelab/features/timer/widgets/timer_stats_bar.dart';
import 'package:cubelab/features/timer/widgets/solve_list.dart';

class TimerPage extends ConsumerWidget {
  const TimerPage({super.key});

  String _formatTime(int ms) {
    final seconds = ms / 1000;
    return seconds.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(timerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Timer', style: AppTextStyles.h3),
      ),
      body: state.error != null
          ? Center(
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
                      'Failed to load timer',
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
            )
          : SafeArea(
        child: Column(
          children: [
            // Scramble display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              color: AppColors.surface,
              child: Text(
                state.currentScramble,
                style: AppTextStyles.scramble,
                textAlign: TextAlign.center,
              ),
            ),

            // Timer area with hold-to-start interaction
            Expanded(
              flex: 3,
              child: Listener(
                onPointerDown: (_) {
                  if (state.phase == TimerPhase.idle) {
                    ref.read(timerProvider.notifier).startHolding();
                  } else if (state.phase == TimerPhase.solving) {
                    ref.read(timerProvider.notifier).stopTimer();
                  }
                },
                onPointerUp: (_) {
                  if (state.phase == TimerPhase.holding) {
                    ref.read(timerProvider.notifier).startTimer();
                  }
                },
                onPointerCancel: (_) {
                  if (state.phase == TimerPhase.holding) {
                    ref.read(timerProvider.notifier).cancelHold();
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: _getBackgroundColor(state.phase),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(state.elapsedMs),
                          style: AppTextStyles.timerLarge.copyWith(
                            color: _getTimerTextColor(state.phase),
                            fontSize: 64,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _getInstructionText(state.phase),
                          style: AppTextStyles.bodySecondary.copyWith(
                            color: _getInstructionColor(state.phase),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Stats bar
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(color: AppColors.border, width: 0.5),
                  bottom: BorderSide(color: AppColors.border, width: 0.5),
                ),
              ),
              child: TimerStatsBar(
                session: state.session,
                allTimeStats: state.allTimeStats,
              ),
            ),

            // Solve list
            Expanded(
              flex: 2,
              child: SolveList(
                solves: state.session?.solves ?? [],
                onDelete: (id) => ref.read(timerProvider.notifier).deleteSolve(id),
                onTogglePenalty: (id, penalty) =>
                    ref.read(timerProvider.notifier).togglePenalty(id, penalty),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getBackgroundColor(TimerPhase phase) {
    switch (phase) {
      case TimerPhase.holding:
        return AppColors.success.withValues(alpha: 0.1);
      case TimerPhase.solving:
        return AppColors.background;
      default:
        return AppColors.background;
    }
  }

  Color _getTimerTextColor(TimerPhase phase) {
    switch (phase) {
      case TimerPhase.idle:
        return AppColors.textTertiary;
      case TimerPhase.holding:
        return AppColors.success;
      case TimerPhase.solving:
        return AppColors.textPrimary;
      case TimerPhase.stopped:
        return AppColors.primary;
      case TimerPhase.scrambling:
        return AppColors.textTertiary;
    }
  }

  Color _getInstructionColor(TimerPhase phase) {
    switch (phase) {
      case TimerPhase.holding:
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  String _getInstructionText(TimerPhase phase) {
    switch (phase) {
      case TimerPhase.idle:
        return 'Hold to start';
      case TimerPhase.scrambling:
        return 'Scrambling...';
      case TimerPhase.holding:
        return 'Release to start';
      case TimerPhase.solving:
        return 'Tap to stop';
      case TimerPhase.stopped:
        return 'Saving...';
    }
  }
}
