import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cubelab/core/theme/app_colors.dart';
import 'package:cubelab/core/theme/app_text_styles.dart';
import 'package:cubelab/core/theme/app_spacing.dart';
import 'package:cubelab/core/theme/widgets/app_card.dart';
import 'package:cubelab/core/utils/navigation_utils.dart';
import 'package:cubelab/features/home/providers/home_provider.dart';

/// Card showing today's daily scramble challenge
class DailyScrambleCard extends ConsumerWidget {
  const DailyScrambleCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengeAsync = ref.watch(todaysChallengeProvider);
    final completedAsync = ref.watch(dailyScrambleCompletedProvider);

    return AppCard(
      onTap: () => NavigationUtils.goToDailyScramble(context, initialPage: 0),
      child: challengeAsync.when(
        loading: () => const _CardLoading(),
        error: (e, _) => _CardError(message: e.toString()),
        data: (challenge) {
          final completed = completedAsync.valueOrNull ?? false;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text('🎯'),
                  SizedBox(width: AppSpacing.sm),
                  Text(
                    "TODAY'S SCRAMBLE",
                    style: AppTextStyles.overline,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                challenge.scramble,
                style: AppTextStyles.scramble,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.md),
              if (completed)
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 16,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Completed',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  'Try it →',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.primary,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CardLoading extends StatelessWidget {
  const _CardLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 80,
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}

class _CardError extends StatelessWidget {
  final String message;

  const _CardError({required this.message});

  String get _userFriendlyMessage {
    final lower = message.toLowerCase();
    if (lower.contains('supabase') ||
        lower.contains('initialize') ||
        lower.contains('socket') ||
        lower.contains('connection') ||
        lower.contains('.pub-cache')) {
      return 'Unable to load challenge. Check your connection.';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            _userFriendlyMessage,
            style: AppTextStyles.caption.copyWith(color: AppColors.error),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
