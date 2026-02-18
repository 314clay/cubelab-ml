import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cubelab/data/models/cube_scan_result.dart';
import 'package:cubelab/core/theme/app_colors.dart';
import 'package:cubelab/core/theme/app_text_styles.dart';
import 'package:cubelab/core/theme/app_spacing.dart';
import 'package:cubelab/core/utils/navigation_utils.dart';
import 'package:cubelab/features/cube_scan/providers/cube_scan_providers.dart';
import 'package:cubelab/features/cube_scan/widgets/camera_preview_widget.dart';
import 'package:cubelab/features/cube_scan/widgets/phase_badge_widget.dart';
import 'package:cubelab/features/cube_scan/widgets/solve_path_card.dart';
import 'package:cubelab/features/cube_scan/widgets/srs_action_widget.dart';
import 'package:cubelab/features/cube_scan/widgets/sticker_overlay_painter.dart';

/// Main Cube Scan page. Single screen driven by CubeScanPhase state machine.
class CubeScanPage extends ConsumerStatefulWidget {
  const CubeScanPage({super.key});

  @override
  ConsumerState<CubeScanPage> createState() => _CubeScanPageState();
}

class _CubeScanPageState extends ConsumerState<CubeScanPage> {
  final _cameraKey = GlobalKey<CameraPreviewWidgetState>();
  int _expandedPathIndex = 0;

  @override
  void dispose() {
    // Reset state when leaving the page
    Future.microtask(() {
      if (mounted) return;
      ref.read(cubeScanProvider.notifier).reset();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cubeScanProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: switch (state.phase) {
        CubeScanPhase.camera => _buildCameraPhase(),
        CubeScanPhase.processing => _buildProcessingPhase(),
        CubeScanPhase.results => _buildResultsPhase(state),
        CubeScanPhase.error => _buildErrorPhase(state),
        CubeScanPhase.done => _buildDonePhase(state),
      },
    );
  }

  // ============ Camera Phase ============

  Widget _buildCameraPhase() {
    return Stack(
      children: [
        // Camera preview (real camera on mobile, dark bg on web)
        if (kIsWeb)
          Container(color: const Color(0xFF0A0A0A))
        else
          CameraPreviewWidget(
            key: _cameraKey,
            onCapture: (bytes) {
              ref.read(cubeScanProvider.notifier).captureAndAnalyze(bytes);
            },
          ),

        // Guide overlay
        Positioned(
          bottom: 140,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: AppSpacing.buttonRadius,
              ),
              child: const Text(
                'Hold cube showing top, front, and right faces',
                style: AppTextStyles.bodySecondary,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),

        // Top bar
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                const Text('Cube Scan', style: AppTextStyles.h3),
                const Spacer(),
                const SizedBox(width: 48), // Balance the back button
              ],
            ),
          ),
        ),

        // Shutter button
        Positioned(
          bottom: 48,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: _capturePhoto,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 4),
                ),
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Label under shutter
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              kIsWeb ? 'Simulate Scan' : 'Capture',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ),
      ],
    );
  }

  void _capturePhoto() {
    HapticFeedback.mediumImpact();
    if (kIsWeb) {
      // Stub: send dummy bytes on web where camera is not available
      ref.read(cubeScanProvider.notifier).captureAndAnalyze(Uint8List(0));
    } else {
      _cameraKey.currentState?.capture();
    }
  }

  // ============ Processing Phase ============

  Widget _buildProcessingPhase() {
    return Stack(
      children: [
        Container(color: const Color(0xFF0A0A0A)),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _ProcessingText(),
            ],
          ),
        ),

        // Top bar
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                  onPressed: () {
                    ref.read(cubeScanProvider.notifier).retake();
                  },
                ),
                const Spacer(),
                const Text('Analyzing...', style: AppTextStyles.h3),
                const Spacer(),
                const SizedBox(width: 48),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============ Results Phase ============

  Widget _buildResultsPhase(CubeScanState state) {
    final result = state.result;
    if (result == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Cube Scan', style: AppTextStyles.h3),
        actions: [
          TextButton.icon(
            onPressed: () => ref.read(cubeScanProvider.notifier).retake(),
            icon: const Icon(Icons.refresh, size: 18, color: AppColors.textSecondary),
            label: Text(
              'Retake',
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.pagePaddingInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sticker overlay visualization
            _buildStickerOverlay(result),
            const SizedBox(height: AppSpacing.lg),

            // Phase badge
            PhaseBadgeWidget(phase: result.phase),
            const SizedBox(height: AppSpacing.lg),

            // Case identification
            _buildCaseIdentification(result),
            const SizedBox(height: AppSpacing.lg),

            // Solved state: no solution to show, just a success message
            if (result.phase == 'solved') ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppSpacing.cardRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success, size: 48),
                    const SizedBox(height: AppSpacing.md),
                    Text('Cube is solved!', style: AppTextStyles.h3),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'All stickers are in the correct position.',
                      style: AppTextStyles.bodySecondary,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ]
            // Normal case: show solution button or revealed content
            else if (!state.solutionRevealed)
              ElevatedButton(
                onPressed: () =>
                    ref.read(cubeScanProvider.notifier).revealSolution(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppSpacing.buttonRadius,
                  ),
                ),
                child: const Text('Show Solution'),
              )
            else ...[
              // Solve paths
              Text(
                'SOLVE PATHS',
                style: AppTextStyles.overline,
              ),
              const SizedBox(height: AppSpacing.md),
              for (int i = 0; i < result.solvePaths.length; i++) ...[
                SolvePathCard(
                  path: result.solvePaths[i],
                  rank: i + 1,
                  isExpanded: i == _expandedPathIndex,
                  onTap: () => setState(() {
                    _expandedPathIndex = _expandedPathIndex == i ? -1 : i;
                  }),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              const SizedBox(height: AppSpacing.lg),

              // SRS action (only show when there's a case to act on)
              if (result.caseName != null)
                SrsActionWidget(
                  caseName: result.caseName,
                  isKnownAlgorithm: state.isKnownAlgorithm,
                  onAddToQueue: () {
                    ref.read(cubeScanProvider.notifier).addToQueue();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${result.caseName!} added to practice queue',
                        ),
                        backgroundColor: AppColors.primary,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  onSkip: () {
                    ref.read(cubeScanProvider.notifier).completeSrsAction();
                  },
                  onRate: (rating) {
                    ref.read(cubeScanProvider.notifier).rateReview(rating);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${result.caseName!} reviewed',
                        ),
                        backgroundColor: AppColors.primary,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
            ],
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildCaseIdentification(CubeScanResult result) {
    final confidence = result.confidence;
    final Color confidenceColor;
    if (confidence >= 0.95) {
      confidenceColor = AppColors.success;
    } else if (confidence >= 0.80) {
      confidenceColor = const Color(0xFFFFC107);
    } else {
      confidenceColor = AppColors.error;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            result.caseName ?? 'Unknown Case',
            style: AppTextStyles.h2,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: confidenceColor.withValues(alpha: 0.15),
            borderRadius: AppSpacing.buttonRadius,
          ),
          child: Text(
            '${(confidence * 100).toStringAsFixed(1)}%',
            style: AppTextStyles.caption.copyWith(
              color: confidenceColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStickerOverlay(CubeScanResult result) {
    final visible27 = result.visible27;
    if (visible27.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: CustomPaint(
        size: const Size(double.infinity, 180),
        painter: StickerOverlayPainter(
          visible27: visible27,
          phase: result.phase,
        ),
      ),
    );
  }

  // ============ Error Phase ============

  Widget _buildErrorPhase(CubeScanState state) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Scan Failed', style: AppTextStyles.h3),
      ),
      body: Center(
        child: Padding(
          padding: AppSpacing.pagePaddingInsets,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 64),
              const SizedBox(height: AppSpacing.lg),
              const Text('Couldn\'t analyze this photo', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.md),
              Text(
                state.errorMessage ??
                    'Make sure 3 faces are visible (top, front, right) with good lighting.',
                style: AppTextStyles.bodySecondary,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                onPressed: () => ref.read(cubeScanProvider.notifier).retake(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                    horizontal: AppSpacing.xl,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppSpacing.buttonRadius,
                  ),
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ Done Phase ============

  Widget _buildDonePhase(CubeScanState state) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Cube Scan', style: AppTextStyles.h3),
      ),
      body: Center(
        child: Padding(
          padding: AppSpacing.pagePaddingInsets,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: AppColors.success, size: 64),
              const SizedBox(height: AppSpacing.lg),
              const Text('Done!', style: AppTextStyles.h2),
              const SizedBox(height: AppSpacing.sm),
              Text(
                state.result?.caseName != null
                    ? '${state.result!.caseName} has been noted.'
                    : 'Scan complete.',
                style: AppTextStyles.bodySecondary,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                onPressed: () => ref.read(cubeScanProvider.notifier).retake(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                    horizontal: AppSpacing.xl,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppSpacing.buttonRadius,
                  ),
                ),
                child: const Text('Scan Again'),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: () => NavigationUtils.goHome(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                    horizontal: AppSpacing.xl,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppSpacing.buttonRadius,
                  ),
                ),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============ Processing Text Animation ============

class _ProcessingText extends StatefulWidget {
  @override
  State<_ProcessingText> createState() => _ProcessingTextState();
}

class _ProcessingTextState extends State<_ProcessingText> {
  static const _messages = [
    'Detecting cube...',
    'Classifying stickers...',
    'Finding solutions...',
  ];

  int _index = 0;

  @override
  void initState() {
    super.initState();
    _cycle();
  }

  void _cycle() async {
    while (mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      setState(() {
        _index = (_index + 1) % _messages.length;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(_messages[_index], style: AppTextStyles.bodySecondary);
  }
}
