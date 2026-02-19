import 'package:flutter/material.dart';
import 'package:cubelab/core/theme/app_colors.dart';
import 'package:cubelab/core/theme/app_text_styles.dart';
import 'package:cubelab/core/theme/app_spacing.dart';

/// Displays the detected solving phase with a colored accent border.
class PhaseBadgeWidget extends StatelessWidget {
  final String phase;

  const PhaseBadgeWidget({super.key, required this.phase});

  @override
  Widget build(BuildContext context) {
    final phaseInfo = _getPhaseInfo(phase);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.cardRadius,
        border: Border(
          left: BorderSide(color: phaseInfo.color, width: 4),
        ),
      ),
      child: Row(
        children: [
          Icon(phaseInfo.icon, color: phaseInfo.color, size: 24),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You\'re in: ${phaseInfo.label}',
                  style: AppTextStyles.h3,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(phaseInfo.description, style: AppTextStyles.bodySecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static _PhaseInfo _getPhaseInfo(String phase) {
    switch (phase) {
      case 'oll':
        return const _PhaseInfo(
          label: 'OLL',
          description: 'Orient all top-face stickers',
          color: Color(0xFFFF9800),
          icon: Icons.grid_view,
        );
      case 'pll':
        return const _PhaseInfo(
          label: 'PLL',
          description: 'Permute last layer pieces',
          color: Color(0xFF2196F3),
          icon: Icons.swap_horiz,
        );
      case 'oll_edges_oriented':
        return const _PhaseInfo(
          label: 'COLL / ZBLL',
          description: 'Edges oriented, solve corners',
          color: Color(0xFF9C27B0),
          icon: Icons.category,
        );
      case 'f2l_last_pair':
        return const _PhaseInfo(
          label: 'F2L (Last Pair)',
          description: 'Insert final first-two-layers pair',
          color: Color(0xFF9C27B0),
          icon: Icons.layers,
        );
      case 'solved':
        return const _PhaseInfo(
          label: 'Solved',
          description: 'Cube is already solved!',
          color: AppColors.success,
          icon: Icons.check_circle,
        );
      default:
        return const _PhaseInfo(
          label: 'Unknown',
          description: 'Could not determine solving phase',
          color: Color(0xFF757575),
          icon: Icons.help_outline,
        );
    }
  }
}

class _PhaseInfo {
  final String label;
  final String description;
  final Color color;
  final IconData icon;

  const _PhaseInfo({
    required this.label,
    required this.description,
    required this.color,
    required this.icon,
  });
}
