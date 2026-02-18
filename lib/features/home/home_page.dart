import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cubelab/core/theme/app_colors.dart';
import 'package:cubelab/core/theme/app_text_styles.dart';
import 'package:cubelab/core/theme/app_spacing.dart';
import 'package:cubelab/core/theme/widgets/app_card.dart';
import 'package:cubelab/core/utils/navigation_utils.dart';
import 'package:cubelab/features/home/widgets/daily_scramble_card.dart';

/// CubeLab home page with navigation to all features.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('CubeLab', style: AppTextStyles.h2),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: AppColors.textPrimary),
            onPressed: () => NavigationUtils.goToProfile(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.pagePaddingInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Daily Scramble Card
            const DailyScrambleCard(),
            const SizedBox(height: AppSpacing.lg),

            // Feature Navigation Cards
            _FeatureCard(
              icon: Icons.grid_on,
              title: 'Cross Trainer',
              subtitle: 'Practice planning and executing crosses',
              onTap: () => NavigationUtils.goToCrossTrainer(context),
            ),
            const SizedBox(height: AppSpacing.md),

            _FeatureCard(
              icon: Icons.auto_awesome,
              title: 'Algorithms',
              subtitle: 'Learn and drill OLL, PLL, ZBLL algorithms',
              onTap: () => NavigationUtils.goToAlgorithm(context),
            ),
            const SizedBox(height: AppSpacing.md),

            _FeatureCard(
              icon: Icons.timer,
              title: 'Timer',
              subtitle: 'Speedcubing timer with session tracking',
              onTap: () => NavigationUtils.goToTimer(context),
            ),
            const SizedBox(height: AppSpacing.md),

            _FeatureCard(
              icon: Icons.emoji_events_outlined,
              title: 'Daily Scramble',
              subtitle: 'Compete on today\'s scramble challenge',
              onTap: () => NavigationUtils.goToDailyScramble(context),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: AppSpacing.buttonRadius,
            ),
            child: Icon(icon, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.h3),
                const SizedBox(height: AppSpacing.xs),
                Text(subtitle, style: AppTextStyles.bodySecondary),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}
