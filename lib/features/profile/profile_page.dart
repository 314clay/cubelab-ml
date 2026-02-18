import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cubelab/core/theme/app_colors.dart';
import 'package:cubelab/core/theme/app_text_styles.dart';
import 'package:cubelab/core/theme/app_spacing.dart';
import 'package:cubelab/core/theme/widgets/app_card.dart';
import 'package:cubelab/core/utils/navigation_utils.dart';
import 'package:cubelab/data/models/user.dart';
import 'package:cubelab/shared/providers/repository_providers.dart';
import 'package:cubelab/features/profile/providers/profile_providers.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  String _formatTime(int? ms) {
    if (ms == null) return '-';
    final seconds = ms / 1000;
    return '${seconds.toStringAsFixed(2)}s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final profileStatsAsync = ref.watch(profileStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Profile', style: AppTextStyles.h3),
      ),
      body: userAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, _) => Center(
          child: Text(
            'Failed to load profile',
            style: AppTextStyles.body.copyWith(color: AppColors.error),
          ),
        ),
        data: (user) => SingleChildScrollView(
          padding: AppSpacing.pagePaddingInsets,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Info Section
              _buildUserInfoSection(context, ref, user),
              const SizedBox(height: AppSpacing.xl),

              // Stats Summary Section
              _buildStatsSummarySection(ref, profileStatsAsync),
              const SizedBox(height: AppSpacing.xl),

              // Settings Section
              _buildSettingsSection(context, ref),
              const SizedBox(height: AppSpacing.xl),

              // Account Section
              _buildAccountSection(context, ref, user),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoSection(
      BuildContext context, WidgetRef ref, AppUser? user) {
    final username = user?.username ?? 'Guest';
    final firstLetter = username.isNotEmpty ? username[0].toUpperCase() : '?';

    return Center(
      child: Column(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                firstLetter,
                style: AppTextStyles.h2.copyWith(fontSize: 32),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Username
          Text(username, style: AppTextStyles.h2),

          // Email
          if (user?.email != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(user!.email!, style: AppTextStyles.bodySecondary),
          ],

          // Sign in prompt for anonymous users
          if (user == null || user.isAnonymous) ...[
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () async {
                await ref.read(userRepositoryProvider).signInWithGoogle();
                ref.invalidate(currentUserProvider);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppSpacing.buttonRadius,
                ),
              ),
              child: const Text('Sign in with Google', style: AppTextStyles.buttonText),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsSummarySection(
      WidgetRef ref, AsyncValue<Map<String, dynamic>> profileStatsAsync) {
    return AppCard(
      child: profileStatsAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
        error: (_, __) => Text(
          'Failed to load stats',
          style: AppTextStyles.body.copyWith(color: AppColors.error),
        ),
        data: (stats) {
          final pbMs = stats['pbSingleMs'] as int?;
          final algorithmsLearned = stats['algorithmsLearned'] as int? ?? 0;
          final totalSolves = stats['totalSolves'] as int? ?? 0;

          return Row(
            children: [
              Expanded(
                child: _buildStatItem('Timer PB', _formatTime(pbMs)),
              ),
              Expanded(
                child: _buildStatItem(
                    'Algorithms', algorithmsLearned.toString()),
              ),
              Expanded(
                child:
                    _buildStatItem('Total Solves', totalSolves.toString()),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.h2.copyWith(color: AppColors.primary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }

  Widget _buildSettingsSection(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(userSettingsProvider);
    if (settings == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Settings', style: AppTextStyles.h3),
        const SizedBox(height: AppSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppSpacing.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Haptic Feedback', style: AppTextStyles.body),
                value: settings.hapticFeedback,
                activeThumbColor: AppColors.primary,
                onChanged: (value) {
                  final updated = settings.copyWith(hapticFeedback: value);
                  ref.read(userSettingsProvider.notifier).state = updated;
                  ref.read(userRepositoryProvider).updateSettings(updated);
                },
              ),
              const Divider(color: AppColors.border, height: 1),
              SwitchListTile(
                title: const Text('Hold to Start', style: AppTextStyles.body),
                value: settings.holdToStart,
                activeThumbColor: AppColors.primary,
                onChanged: (value) {
                  final updated = settings.copyWith(holdToStart: value);
                  ref.read(userSettingsProvider.notifier).state = updated;
                  ref.read(userRepositoryProvider).updateSettings(updated);
                },
              ),
              const Divider(color: AppColors.border, height: 1),
              ListTile(
                title: const Text('Inspection Time', style: AppTextStyles.body),
                trailing: Text(
                  '${settings.inspectionTimeSeconds}s',
                  style: AppTextStyles.body.copyWith(color: AppColors.primary),
                ),
                subtitle: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: AppColors.primary,
                    thumbColor: AppColors.primary,
                    inactiveTrackColor: AppColors.border,
                    overlayColor: AppColors.primary.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: settings.inspectionTimeSeconds.toDouble(),
                    min: 5,
                    max: 30,
                    divisions: 25,
                    label: '${settings.inspectionTimeSeconds}s',
                    onChanged: (value) {
                      final updated = settings.copyWith(
                          inspectionTimeSeconds: value.round());
                      ref.read(userSettingsProvider.notifier).state = updated;
                    },
                    onChangeEnd: (value) {
                      final updated = settings.copyWith(
                          inspectionTimeSeconds: value.round());
                      ref.read(userRepositoryProvider).updateSettings(updated);
                    },
                  ),
                ),
              ),
              const Divider(color: AppColors.border, height: 1),
              SwitchListTile(
                title:
                    const Text('Show Scramble Preview', style: AppTextStyles.body),
                value: settings.showScramblePreview,
                activeThumbColor: AppColors.primary,
                onChanged: (value) {
                  final updated =
                      settings.copyWith(showScramblePreview: value);
                  ref.read(userSettingsProvider.notifier).state = updated;
                  ref.read(userRepositoryProvider).updateSettings(updated);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSection(
      BuildContext context, WidgetRef ref, AppUser? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (user != null && user.isAnonymous) ...[
          ElevatedButton(
            onPressed: () async {
              await ref.read(userRepositoryProvider).linkAnonymousToGoogle();
              ref.invalidate(currentUserProvider);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textPrimary,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              shape: const RoundedRectangleBorder(
                borderRadius: AppSpacing.buttonRadius,
              ),
            ),
            child: const Text('Link Google Account', style: AppTextStyles.buttonText),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        OutlinedButton(
          onPressed: () async {
            await ref.read(userRepositoryProvider).signOut();
            if (context.mounted) {
              NavigationUtils.goHome(context);
            }
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            shape: const RoundedRectangleBorder(
              borderRadius: AppSpacing.buttonRadius,
            ),
          ),
          child: Text(
            'Sign Out',
            style: AppTextStyles.buttonText.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
