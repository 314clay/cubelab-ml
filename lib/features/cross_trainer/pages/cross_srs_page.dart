import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cubelab/core/theme/app_colors.dart';
import 'package:cubelab/core/utils/error_utils.dart';
import 'package:cubelab/core/theme/app_text_styles.dart';
import 'package:cubelab/core/theme/app_spacing.dart';
import 'package:cubelab/data/models/cross_srs_item.dart';
import 'package:cubelab/data/models/srs_state.dart';
import 'package:cubelab/features/cross_trainer/providers/cross_trainer_providers.dart';
import 'package:cubelab/shared/providers/repository_providers.dart';

/// SRS review page for cross training scrambles.
///
/// Shows the next due SRS item with timer for practice,
/// and pass/fail buttons to rate the review.
class CrossSRSPage extends ConsumerStatefulWidget {
  const CrossSRSPage({super.key});

  @override
  ConsumerState<CrossSRSPage> createState() => _CrossSRSPageState();
}

class _CrossSRSPageState extends ConsumerState<CrossSRSPage> {
  bool _isReviewing = false;
  int _inspectionMs = 0;
  int _executionMs = 0;
  _SRSTimerPhase _timerPhase = _SRSTimerPhase.idle;
  Stopwatch? _stopwatch;

  String _formatTime(int ms) {
    final seconds = ms / 1000;
    return '${seconds.toStringAsFixed(2)}s';
  }

  void _startInspection() {
    setState(() {
      _timerPhase = _SRSTimerPhase.inspecting;
      _inspectionMs = 0;
      _stopwatch = Stopwatch()..start();
      _isReviewing = true;
    });
    _tick();
  }

  void _tick() {
    if (!mounted) return;
    if (_stopwatch?.isRunning ?? false) {
      setState(() {
        if (_timerPhase == _SRSTimerPhase.inspecting) {
          _inspectionMs = _stopwatch!.elapsedMilliseconds;
        } else if (_timerPhase == _SRSTimerPhase.executing) {
          _executionMs = _stopwatch!.elapsedMilliseconds;
        }
      });
      Future.delayed(const Duration(milliseconds: 10), _tick);
    }
  }

  void _startExecution() {
    _stopwatch?.stop();
    setState(() {
      _inspectionMs = _stopwatch?.elapsedMilliseconds ?? 0;
      _timerPhase = _SRSTimerPhase.executing;
      _executionMs = 0;
      _stopwatch = Stopwatch()..start();
    });
    _tick();
  }

  void _stopExecution() {
    _stopwatch?.stop();
    setState(() {
      _executionMs = _stopwatch?.elapsedMilliseconds ?? 0;
      _timerPhase = _SRSTimerPhase.done;
    });
  }

  Future<void> _rateSolve(CrossSRSItem item, SRSRating rating) async {
    final repo = ref.read(crossTrainerRepositoryProvider);
    final updatedItem = item.copyWith(
      totalReviews: item.totalReviews + 1,
      lastReviewedAt: DateTime.now(),
    );
    await repo.updateSRSItem(updatedItem);

    setState(() {
      _isReviewing = false;
      _timerPhase = _SRSTimerPhase.idle;
      _inspectionMs = 0;
      _executionMs = 0;
    });

    // Refresh the next item
    ref.invalidate(nextSRSItemProvider);
    ref.invalidate(crossSRSProvider);
  }

  @override
  void dispose() {
    _stopwatch?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nextItem = ref.watch(nextSRSItemProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.pagePaddingInsets,
          child: nextItem.when(
            data: (item) => item == null
                ? _buildEmptyState()
                : _buildReviewCard(item),
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
                    'Failed to load SRS items',
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
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              size: 64,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'All caught up!',
            style: AppTextStyles.h2,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'No SRS items are due for review.\nKeep practicing to add new items.',
            style: AppTextStyles.bodySecondary,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(CrossSRSItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Item info
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
              Row(
                children: [
                  const Text('SCRAMBLE', style: AppTextStyles.overline),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: AppSpacing.buttonRadius,
                    ),
                    child: Text(
                      '${item.pairsAttempting} pair${item.pairsAttempting > 1 ? 's' : ''}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                item.scramble,
                style: AppTextStyles.scramble,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Reviews: ${item.totalReviews}',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),

        const Spacer(),

        // Timer
        GestureDetector(
          onTap: () {
            switch (_timerPhase) {
              case _SRSTimerPhase.idle:
                _startInspection();
              case _SRSTimerPhase.inspecting:
                _startExecution();
              case _SRSTimerPhase.executing:
                _stopExecution();
              case _SRSTimerPhase.done:
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
              color: _timerPhase == _SRSTimerPhase.inspecting
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : _timerPhase == _SRSTimerPhase.executing
                      ? AppColors.error.withValues(alpha: 0.1)
                      : AppColors.surface,
              borderRadius: AppSpacing.cardRadius,
              border: Border.all(
                color: _timerPhase == _SRSTimerPhase.inspecting
                    ? AppColors.primary
                    : _timerPhase == _SRSTimerPhase.executing
                        ? AppColors.error
                        : AppColors.border,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_timerPhase != _SRSTimerPhase.idle)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(
                      _timerPhase == _SRSTimerPhase.inspecting
                          ? 'INSPECTION'
                          : _timerPhase == _SRSTimerPhase.executing
                              ? 'EXECUTION'
                              : 'DONE',
                      style: AppTextStyles.overline,
                    ),
                  ),
                Text(
                  _timerPhase == _SRSTimerPhase.idle
                      ? '0.00s'
                      : _timerPhase == _SRSTimerPhase.inspecting
                          ? _formatTime(_inspectionMs)
                          : _formatTime(_executionMs),
                  style: AppTextStyles.timerLarge.copyWith(
                    color: _timerPhase == _SRSTimerPhase.idle
                        ? AppColors.textTertiary
                        : _timerPhase == _SRSTimerPhase.inspecting
                            ? AppColors.primary
                            : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _timerPhase == _SRSTimerPhase.idle
                      ? 'Tap to start inspection'
                      : _timerPhase == _SRSTimerPhase.inspecting
                          ? 'Tap when ready to execute'
                          : _timerPhase == _SRSTimerPhase.executing
                              ? 'Tap to stop'
                              : 'Rate your solve below',
                  style: AppTextStyles.bodySecondary,
                ),
                if (_timerPhase == _SRSTimerPhase.executing ||
                    _timerPhase == _SRSTimerPhase.done)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      'Inspection: ${_formatTime(_inspectionMs)}',
                      style: AppTextStyles.caption,
                    ),
                  ),
              ],
            ),
          ),
        ),

        const Spacer(),

        // Rating buttons
        if (_timerPhase == _SRSTimerPhase.done)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _rateSolve(item, SRSRating.again),
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
                  onPressed: () => _rateSolve(item, SRSRating.good),
                  icon: const Icon(Icons.check, size: 20),
                  label: const Text('Pass', style: AppTextStyles.buttonText),
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
          )
        else if (!_isReviewing)
          ElevatedButton(
            onPressed: _startInspection,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textPrimary,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              shape: const RoundedRectangleBorder(
                borderRadius: AppSpacing.buttonRadius,
              ),
            ),
            child: const Text('Start Review', style: AppTextStyles.buttonText),
          )
        else
          const SizedBox.shrink(),
      ],
    );
  }
}

enum _SRSTimerPhase { idle, inspecting, executing, done }
