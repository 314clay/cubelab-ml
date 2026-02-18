import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cubelab/core/theme/app_colors.dart';
import 'package:cubelab/core/utils/error_utils.dart';
import 'package:cubelab/core/theme/app_text_styles.dart';
import 'package:cubelab/core/theme/app_spacing.dart';
import 'package:cubelab/data/models/algorithm.dart';
import 'package:cubelab/features/algorithm/providers/algorithm_providers.dart';
import 'package:cubelab/shared/providers/repository_providers.dart';

/// Browse algorithms by set with enable/disable toggles
class AlgorithmCatalogPage extends ConsumerWidget {
  const AlgorithmCatalogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedSet = ref.watch(selectedAlgorithmSetProvider);
    final catalogAsync = ref.watch(algorithmCatalogProvider);
    final userAlgsAsync = ref.watch(userAlgorithmsProvider);

    return Column(
      children: [
        // Filter chips
        _buildFilterChips(ref, selectedSet),

        // Algorithm list
        Expanded(
          child: catalogAsync.when(
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
                      'Failed to load algorithms',
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
            data: (algorithms) {
              if (algorithms.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.search_off,
                        size: 48,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'No algorithms found',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Build user algorithm lookup
              final userAlgMap = <String, bool>{};
              final learnedMap = <String, bool>{};
              userAlgsAsync.whenData((userAlgs) {
                for (final ua in userAlgs) {
                  userAlgMap[ua.algorithmId] = ua.enabled;
                  learnedMap[ua.algorithmId] = ua.isLearned;
                }
              });

              // Group by subset
              final grouped = <String, List<Algorithm>>{};
              for (final alg in algorithms) {
                final key = alg.subset ?? 'Other';
                grouped.putIfAbsent(key, () => []).add(alg);
              }

              final subsets = grouped.keys.toList()..sort();

              return ListView.builder(
                padding: const EdgeInsets.only(
                  left: AppSpacing.pagePadding,
                  right: AppSpacing.pagePadding,
                  bottom: AppSpacing.xl,
                ),
                itemCount: subsets.length,
                itemBuilder: (context, index) {
                  final subset = subsets[index];
                  final algs = grouped[subset]!;
                  return _buildSubsetGroup(
                    context,
                    ref,
                    subset,
                    algs,
                    userAlgMap,
                    learnedMap,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips(WidgetRef ref, AlgorithmSet? selectedSet) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePadding,
          vertical: AppSpacing.sm,
        ),
        children: [
          _buildChip(ref, 'All', null, selectedSet),
          const SizedBox(width: AppSpacing.sm),
          for (final set in AlgorithmSet.values) ...[
            _buildChip(ref, set.name.toUpperCase(), set, selectedSet),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(
    WidgetRef ref,
    String label,
    AlgorithmSet? set,
    AlgorithmSet? selectedSet,
  ) {
    final isSelected = selectedSet == set;
    return FilterChip(
      label: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: isSelected ? AppColors.background : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (_) {
        ref.read(selectedAlgorithmSetProvider.notifier).state = set;
      },
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primary,
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.border,
      ),
      showCheckmark: false,
    );
  }

  Widget _buildSubsetGroup(
    BuildContext context,
    WidgetRef ref,
    String subset,
    List<Algorithm> algorithms,
    Map<String, bool> userAlgMap,
    Map<String, bool> learnedMap,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),
        Text(
          subset,
          style: AppTextStyles.overline,
        ),
        const SizedBox(height: AppSpacing.xs),
        ...algorithms.map((alg) => _buildAlgorithmTile(
              context,
              ref,
              alg,
              userAlgMap[alg.id] ?? false,
              learnedMap[alg.id] ?? false,
            )),
      ],
    );
  }

  Widget _buildAlgorithmTile(
    BuildContext context,
    WidgetRef ref,
    Algorithm alg,
    bool enabled,
    bool isLearned,
  ) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(
        left: AppSpacing.lg,
        bottom: AppSpacing.md,
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppSpacing.buttonRadius,
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(
          Icons.grid_view_rounded,
          color: isLearned ? AppColors.primary : AppColors.textTertiary,
          size: 20,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              alg.name,
              style: AppTextStyles.body,
            ),
          ),
          if (isLearned)
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.sm),
              child: Icon(
                Icons.check_circle,
                size: 16,
                color: AppColors.success,
              ),
            ),
        ],
      ),
      trailing: Switch(
        value: enabled,
        onChanged: (value) {
          ref
              .read(algorithmRepositoryProvider)
              .setAlgorithmEnabled(alg.id, value);
          ref.invalidate(userAlgorithmsProvider);
        },
        activeThumbColor: AppColors.primary,
        inactiveThumbColor: AppColors.textTertiary,
        inactiveTrackColor: AppColors.surface,
      ),
      iconColor: AppColors.textSecondary,
      collapsedIconColor: AppColors.textSecondary,
      children: [
        if (alg.defaultAlgs.isNotEmpty) ...[
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Algorithms:', style: AppTextStyles.caption),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final algStr in alg.defaultAlgs)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  algStr,
                  style: AppTextStyles.scramble.copyWith(fontSize: 13),
                ),
              ),
            ),
        ],
        if (alg.scrambleSetup != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Setup: ${alg.scrambleSetup}',
              style: AppTextStyles.caption,
            ),
          ),
        ],
      ],
    );
  }
}
