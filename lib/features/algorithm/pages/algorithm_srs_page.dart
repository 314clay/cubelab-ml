import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cubelab/core/theme/app_colors.dart';
import 'package:cubelab/core/utils/error_utils.dart';
import 'package:cubelab/core/theme/app_text_styles.dart';
import 'package:cubelab/core/theme/app_spacing.dart';
import 'package:cubelab/data/models/srs_state.dart';
import 'package:cubelab/data/models/user_algorithm.dart';
import 'package:cubelab/data/models/algorithm_review.dart';
import 'package:cubelab/features/algorithm/providers/algorithm_providers.dart';
import 'package:cubelab/shared/providers/repository_providers.dart';

/// SRS review queue page
class AlgorithmSRSPage extends ConsumerStatefulWidget {
  const AlgorithmSRSPage({super.key});

  @override
  ConsumerState<AlgorithmSRSPage> createState() => _AlgorithmSRSPageState();
}

class _AlgorithmSRSPageState extends ConsumerState<AlgorithmSRSPage> {
  int _currentIndex = 0;
  bool _showingSolution = false;
  final Stopwatch _stopwatch = Stopwatch();
  int _elapsedMs = 0;

  String _formatTime(int ms) {
    final seconds = ms / 1000;
    return '${seconds.toStringAsFixed(2)}s';
  }

  void _startReview() {
    _showingSolution = false;
    _stopwatch.reset();
    _stopwatch.start();
    _updateTimer();
  }

  void _updateTimer() {
    if (!_stopwatch.isRunning) return;
    setState(() {
      _elapsedMs = _stopwatch.elapsedMilliseconds;
    });
    Future.delayed(const Duration(milliseconds: 10), () {
      if (mounted && _stopwatch.isRunning) _updateTimer();
    });
  }

  void _showSolution() {
    _stopwatch.stop();
    setState(() {
      _elapsedMs = _stopwatch.elapsedMilliseconds;
      _showingSolution = true;
    });
  }

  Future<void> _rate(SRSRating rating, UserAlgorithm userAlg) async {
    final review = AlgorithmReview(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userAlg.userId,
      userAlgorithmId: userAlg.algorithmId,
      rating: rating,
      timeMs: _elapsedMs,
      stateBefore: userAlg.srsState ?? SRSState.initial(),
      stateAfter: SRSState.initial(),
      createdAt: DateTime.now(),
    );

    try {
      await ref.read(algorithmRepositoryProvider).recordReview(review);
    } catch (_) {
      // Continue even if recording fails
    }

    setState(() {
      _currentIndex++;
      _showingSolution = false;
    });
    _startReview();
  }

  @override
  void initState() {
    super.initState();
    _startReview();
  }

  @override
  void dispose() {
    _stopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dueAsync = ref.watch(dueAlgorithmsProvider);

    return dueAsync.when(
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
                'Failed to load reviews',
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
      data: (dueAlgorithms) {
        if (dueAlgorithms.isEmpty || _currentIndex >= dueAlgorithms.length) {
          return _buildEmptyState();
        }
        return _buildReviewCard(dueAlgorithms);
      },
    );
  }

  Widget _buildEmptyState() {
    _stopwatch.stop();
    return SafeArea(
      child: Padding(
        padding: AppSpacing.pagePaddingInsets,
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
              'All Caught Up!',
              style: AppTextStyles.h2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'No algorithms due for review',
              style: AppTextStyles.bodySecondary,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(List<UserAlgorithm> dueAlgorithms) {
    final total = dueAlgorithms.length;
    final current = dueAlgorithms[_currentIndex];

    return SafeArea(
      child: Padding(
        padding: AppSpacing.pagePaddingInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Progress indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Due: $total',
                  style: AppTextStyles.caption,
                ),
                Text(
                  'Reviewed $_currentIndex of $total',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(
              value: total > 0 ? _currentIndex / total : 0,
              backgroundColor: AppColors.surface,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),

            const Spacer(),

            // Review card
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppSpacing.cardRadius,
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  // Algorithm case placeholder
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
                  Text(
                    current.algorithmId,
                    style: AppTextStyles.h2,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Timer
                  Text(
                    _formatTime(_elapsedMs),
                    style: AppTextStyles.timerLarge.copyWith(
                      fontSize: 32,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            if (!_showingSolution) ...[
              ElevatedButton(
                onPressed: _showSolution,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppSpacing.buttonRadius,
                  ),
                ),
                child: const Text('Show Answer', style: AppTextStyles.buttonText),
              ),
            ] else ...[
              // Rating buttons
              const Text(
                'Rate your recall',
                style: AppTextStyles.bodySecondary,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  _buildRatingButton(
                      'Again', SRSRating.again, AppColors.error, current),
                  const SizedBox(width: AppSpacing.sm),
                  _buildRatingButton(
                      'Hard', SRSRating.hard, const Color(0xFFFF9800), current),
                  const SizedBox(width: AppSpacing.sm),
                  _buildRatingButton(
                      'Good', SRSRating.good, AppColors.primary, current),
                  const SizedBox(width: AppSpacing.sm),
                  _buildRatingButton(
                      'Easy', SRSRating.easy, const Color(0xFF2196F3), current),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRatingButton(
    String label,
    SRSRating rating,
    Color color,
    UserAlgorithm userAlg,
  ) {
    return Expanded(
      child: ElevatedButton(
        onPressed: () => _rate(rating, userAlg),
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
}
