import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cubelab/data/models/cube_scan_result.dart';
import 'package:cubelab/data/services/cube_analysis_service.dart';
import 'package:cubelab/data/services/stub_cube_analysis_service.dart';
import 'package:cubelab/data/repositories/cube_scan_repository.dart';
import 'package:cubelab/data/stubs/stub_cube_scan_repository.dart';

// ============ Phase Enum ============

enum CubeScanPhase { camera, processing, results, error, done }

// ============ State ============

class CubeScanState {
  final CubeScanPhase phase;
  final Uint8List? capturedImage;
  final CubeScanResult? result;
  final String? matchedAlgorithmId;
  final bool solutionRevealed;
  final String? errorMessage;

  const CubeScanState({
    this.phase = CubeScanPhase.camera,
    this.capturedImage,
    this.result,
    this.matchedAlgorithmId,
    this.solutionRevealed = false,
    this.errorMessage,
  });

  CubeScanState copyWith({
    CubeScanPhase? phase,
    Uint8List? capturedImage,
    CubeScanResult? result,
    String? matchedAlgorithmId,
    bool? solutionRevealed,
    String? errorMessage,
  }) {
    return CubeScanState(
      phase: phase ?? this.phase,
      capturedImage: capturedImage ?? this.capturedImage,
      result: result ?? this.result,
      matchedAlgorithmId: matchedAlgorithmId ?? this.matchedAlgorithmId,
      solutionRevealed: solutionRevealed ?? this.solutionRevealed,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// ============ Notifier ============

class CubeScanNotifier extends StateNotifier<CubeScanState> {
  final CubeAnalysisService _analysisService;

  CubeScanNotifier(this._analysisService) : super(const CubeScanState());

  /// Capture a photo and run analysis via the service.
  Future<void> captureAndAnalyze(Uint8List imageBytes) async {
    state = state.copyWith(
      phase: CubeScanPhase.processing,
      capturedImage: imageBytes,
    );

    try {
      final result = await _analysisService.analyze(imageBytes);
      state = CubeScanState(
        phase: CubeScanPhase.results,
        capturedImage: imageBytes,
        result: result,
        solutionRevealed: false,
      );
    } catch (e) {
      state = CubeScanState(
        phase: CubeScanPhase.error,
        capturedImage: imageBytes,
        errorMessage: e.toString(),
      );
    }
  }

  /// Reveal the solve paths and SRS action.
  void revealSolution() {
    state = state.copyWith(solutionRevealed: true);
  }

  /// Transition to done after SRS action.
  void completeSrsAction() {
    state = state.copyWith(phase: CubeScanPhase.done);
  }

  /// Go back to camera to retake.
  void retake() {
    state = const CubeScanState();
  }

  /// Full reset.
  void reset() {
    state = const CubeScanState();
  }
}

// ============ Providers ============

/// Analysis service (stub for now, swap for real ML later)
final cubeAnalysisServiceProvider = Provider<CubeAnalysisService>((ref) {
  return StubCubeAnalysisService();
});

/// Cube scan repository (stub for now)
final cubeScanRepositoryProvider = Provider<CubeScanRepository>((ref) {
  return StubCubeScanRepository();
});

/// Main state notifier for the Cube Scan flow
final cubeScanProvider =
    StateNotifierProvider<CubeScanNotifier, CubeScanState>((ref) {
  final service = ref.watch(cubeAnalysisServiceProvider);
  return CubeScanNotifier(service);
});
