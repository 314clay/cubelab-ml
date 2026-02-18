import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cubelab/core/theme/app_colors.dart';
import 'package:cubelab/core/theme/app_text_styles.dart';
import 'package:cubelab/core/theme/app_spacing.dart';
import 'package:cubelab/data/models/daily_challenge.dart';
import 'package:cubelab/features/daily_scramble/pages/daily_scramble_results_page.dart';
import 'package:cubelab/shared/providers/repository_providers.dart';

/// Submit page after completing a daily scramble solve.
class DailyScrambleSubmitPage extends ConsumerStatefulWidget {
  final DailyChallenge challenge;
  final int solveTimeMs;

  const DailyScrambleSubmitPage({
    super.key,
    required this.challenge,
    required this.solveTimeMs,
  });

  @override
  ConsumerState<DailyScrambleSubmitPage> createState() =>
      _DailyScrambleSubmitPageState();
}

class _DailyScrambleSubmitPageState
    extends ConsumerState<DailyScrambleSubmitPage> {
  final _notesController = TextEditingController();
  int? _pairsPlanned;
  bool _wasXcross = false;
  bool _wasZbll = false;
  bool _isSubmitting = false;

  String _formatTime(int ms) {
    final seconds = ms / 1000;
    return '${seconds.toStringAsFixed(2)}s';
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final solve = DailyScrambleSolve(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: '', // Will be set by repository
        date: widget.challenge.date,
        scramble: widget.challenge.scramble,
        timeMs: widget.solveTimeMs,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        pairsPlanned: _pairsPlanned,
        wasXcross: _wasXcross ? true : null,
        wasZbll: _wasZbll ? true : null,
        createdAt: DateTime.now(),
      );

      await ref
          .read(dailyChallengeRepositoryProvider)
          .saveDailyScrambleSolve(solve);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DailyScrambleResultsPage(
              userSolveTimeMs: widget.solveTimeMs,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
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
        title: const Text('Submit Solve', style: AppTextStyles.h3),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.pagePaddingInsets,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Solve time display
              Center(
                child: Text(
                  _formatTime(widget.solveTimeMs),
                  style: AppTextStyles.timerLarge.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Notes field
              const Text('Notes', style: AppTextStyles.body),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _notesController,
                maxLines: 3,
                style: AppTextStyles.body,
                decoration: const InputDecoration(
                  hintText: 'How did the solve go?',
                  hintStyle: AppTextStyles.bodySecondary,
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: AppSpacing.cardRadius,
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppSpacing.cardRadius,
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppSpacing.cardRadius,
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Pairs Planned
              const Text('Pairs Planned', style: AppTextStyles.body),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: List.generate(4, (index) {
                  final value = index + 1;
                  final isSelected = _pairsPlanned == value;
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text('$value'),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _pairsPlanned = selected ? value : null;
                        });
                      },
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      labelStyle: AppTextStyles.body.copyWith(
                        color: isSelected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : AppColors.border,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Was X-Cross
              _buildSwitchRow(
                label: 'Was X-Cross',
                value: _wasXcross,
                onChanged: (val) => setState(() => _wasXcross = val),
              ),
              const SizedBox(height: AppSpacing.md),

              // Was ZBLL
              _buildSwitchRow(
                label: 'Was ZBLL',
                value: _wasZbll,
                onChanged: (val) => setState(() => _wasZbll = val),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Submit button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppSpacing.buttonRadius,
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.textPrimary,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Submit', style: AppTextStyles.buttonText),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.body),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
