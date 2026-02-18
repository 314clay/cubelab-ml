import 'package:flutter/material.dart';
import 'package:cubelab/core/theme/app_colors.dart';
import 'package:cubelab/core/theme/app_text_styles.dart';
import 'package:cubelab/core/theme/app_spacing.dart';
import 'package:cubelab/data/models/pro_solve.dart';

/// GOAT Reconstruction Page - shows detailed pro solve with reconstruction
class GoatReconstructionPage extends StatelessWidget {
  final ProSolve proSolve;

  const GoatReconstructionPage({
    super.key,
    required this.proSolve,
  });

  String _formatTime(int ms) {
    final seconds = ms / 1000;
    return '${seconds.toStringAsFixed(2)}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(proSolve.solver, style: AppTextStyles.h3),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.pagePaddingInsets,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Solver info card
              _buildSolverCard(),
              const SizedBox(height: AppSpacing.lg),

              // Scramble section
              _buildScrambleSection(),
              const SizedBox(height: AppSpacing.lg),

              // Reconstruction section
              if (proSolve.reconstruction != null) ...[
                _buildReconstructionSection(),
                const SizedBox(height: AppSpacing.lg),
              ],

              // Notes section
              if (proSolve.notes != null) ...[
                _buildNotesSection(),
                const SizedBox(height: AppSpacing.lg),
              ],

              // Video link
              if (proSolve.videoUrl != null) _buildVideoButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSolverCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Solver icon
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          // Solver details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(proSolve.solver, style: AppTextStyles.h3),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _formatTime(proSolve.timeMs),
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrambleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SCRAMBLE',
          style: AppTextStyles.overline,
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppSpacing.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            proSolve.scramble,
            style: AppTextStyles.scramble,
          ),
        ),
      ],
    );
  }

  Widget _buildReconstructionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'RECONSTRUCTION',
          style: AppTextStyles.overline,
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppSpacing.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            proSolve.reconstruction!,
            style: AppTextStyles.scramble,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NOTES',
          style: AppTextStyles.overline,
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppSpacing.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            proSolve.notes!,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoButton() {
    return OutlinedButton(
      onPressed: () {
        // Video URL available at proSolve.videoUrl
        // url_launcher not yet added as dependency
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        shape: const RoundedRectangleBorder(
          borderRadius: AppSpacing.buttonRadius,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.play_circle_outline, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Watch Video',
            style: AppTextStyles.buttonText.copyWith(
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
