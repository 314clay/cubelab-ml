import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cubelab/data/models/algorithm.dart';
import 'package:cubelab/data/models/algorithm_review.dart';
import 'package:cubelab/data/models/cube_scan_encounter.dart';
import 'package:cubelab/data/models/cube_scan_result.dart';
import 'package:cubelab/data/models/srs_state.dart';
import 'package:cubelab/data/repositories/algorithm_repository.dart';
import 'package:cubelab/data/repositories/cube_scan_repository.dart';
import 'package:cubelab/data/services/cube_analysis_service.dart';
import 'package:cubelab/data/services/stub_cube_analysis_service.dart';
import 'package:cubelab/shared/providers/repository_providers.dart';

// ============ Phase Enum ============

enum CubeScanPhase { camera, processing, results, error, done }

// ============ State ============

class CubeScanState {
  final CubeScanPhase phase;
  final Uint8List? capturedImage;
  final CubeScanResult? result;
  final String? matchedAlgorithmId;
  final bool isKnownAlgorithm;
  final bool solutionRevealed;
  final String? errorMessage;

  const CubeScanState({
    this.phase = CubeScanPhase.camera,
    this.capturedImage,
    this.result,
    this.matchedAlgorithmId,
    this.isKnownAlgorithm = false,
    this.solutionRevealed = false,
    this.errorMessage,
  });

  CubeScanState copyWith({
    CubeScanPhase? phase,
    Uint8List? capturedImage,
    CubeScanResult? result,
    String? matchedAlgorithmId,
    bool? isKnownAlgorithm,
    bool? solutionRevealed,
    String? errorMessage,
  }) {
    return CubeScanState(
      phase: phase ?? this.phase,
      capturedImage: capturedImage ?? this.capturedImage,
      result: result ?? this.result,
      matchedAlgorithmId: matchedAlgorithmId ?? this.matchedAlgorithmId,
      isKnownAlgorithm: isKnownAlgorithm ?? this.isKnownAlgorithm,
      solutionRevealed: solutionRevealed ?? this.solutionRevealed,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// ============ Notifier ============

class CubeScanNotifier extends StateNotifier<CubeScanState> {
  final CubeAnalysisService _analysisService;
  final AlgorithmRepository _algorithmRepository;
  final CubeScanRepository _scanRepository;

  CubeScanNotifier(
    this._analysisService,
    this._algorithmRepository,
    this._scanRepository,
  ) : super(const CubeScanState());

  /// Capture a photo and run analysis via the service.
  Future<void> captureAndAnalyze(Uint8List imageBytes) async {
    state = state.copyWith(
      phase: CubeScanPhase.processing,
      capturedImage: imageBytes,
    );

    try {
      final result = await _analysisService.analyze(imageBytes);

      // Look up the matched algorithm by caseSet + caseName
      String? matchedId;
      bool isKnown = false;

      if (result.caseName != null && result.caseSet != null) {
        matchedId = await _findAlgorithmId(result.caseSet!, result.caseName!);
        if (matchedId != null) {
          final userAlg =
              await _algorithmRepository.getUserAlgorithm(matchedId);
          isKnown = userAlg?.enabled ?? false;
        }
      }

      state = CubeScanState(
        phase: CubeScanPhase.results,
        capturedImage: imageBytes,
        result: result,
        matchedAlgorithmId: matchedId,
        isKnownAlgorithm: isKnown,
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

  /// Find the algorithm ID by matching caseSet and caseName.
  Future<String?> _findAlgorithmId(String caseSet, String caseName) async {
    final set = AlgorithmSetExtension.fromString(caseSet);
    final algorithms = await _algorithmRepository.getAlgorithmsBySet(set);
    for (final alg in algorithms) {
      if (alg.name == caseName) {
        return alg.id;
      }
    }
    return null;
  }

  /// Add the detected case to the SRS practice queue.
  Future<void> addToQueue() async {
    final algorithmId = state.matchedAlgorithmId;
    if (algorithmId == null) {
      state = state.copyWith(phase: CubeScanPhase.done);
      return;
    }

    try {
      await _algorithmRepository.setAlgorithmEnabled(algorithmId, true);
    } catch (_) {
      // Continue even if enabling fails
    }

    await _saveEncounter(addedToQueue: true);
    state = state.copyWith(phase: CubeScanPhase.done);
  }

  /// Rate a known algorithm via SRS (Again/Hard/Good/Easy).
  Future<void> rateReview(SRSRating rating) async {
    final algorithmId = state.matchedAlgorithmId;
    if (algorithmId == null) {
      state = state.copyWith(phase: CubeScanPhase.done);
      return;
    }

    final review = AlgorithmReview(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: '',
      userAlgorithmId: algorithmId,
      rating: rating,
      stateBefore: SRSState.initial(),
      stateAfter: SRSState.initial(),
      createdAt: DateTime.now(),
    );

    try {
      await _algorithmRepository.recordReview(review);
    } catch (_) {
      // Continue even if recording fails
    }

    await _saveEncounter(srsRating: rating.name);
    state = state.copyWith(phase: CubeScanPhase.done);
  }

  /// Reveal the solve paths and SRS action.
  void revealSolution() {
    state = state.copyWith(solutionRevealed: true);
  }

  /// Transition to done after SRS action (skip).
  Future<void> completeSrsAction() async {
    await _saveEncounter();
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

  /// Save a CubeScanEncounter to the repository.
  Future<void> _saveEncounter({
    bool addedToQueue = false,
    String? srsRating,
  }) async {
    final result = state.result;
    if (result == null) return;

    final encounter = CubeScanEncounter(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: '',
      algorithmId: state.matchedAlgorithmId,
      phase: result.phase,
      caseName: result.caseName,
      confidence: result.confidence,
      srsRating: srsRating,
      addedToQueue: addedToQueue,
      scannedAt: DateTime.now(),
    );

    try {
      await _scanRepository.saveEncounter(encounter);
    } catch (_) {
      // Non-critical: don't block UI if history save fails
    }
  }
}

// ============ Providers ============

/// Analysis service provider.
/// Currently uses the stub. To switch to a remote server:
///   ref.read(cubeAnalysisServiceProvider.notifier).state =
///       RemoteCubeAnalysisService(baseUrl: 'http://your-server:8000');
final cubeAnalysisServiceProvider =
    StateProvider<CubeAnalysisService>((ref) {
  return StubCubeAnalysisService();
});

/// Main state notifier for the Cube Scan flow
final cubeScanProvider =
    StateNotifierProvider<CubeScanNotifier, CubeScanState>((ref) {
  final service = ref.watch(cubeAnalysisServiceProvider);
  final algorithmRepo = ref.watch(algorithmRepositoryProvider);
  final scanRepo = ref.watch(cubeScanRepositoryProvider);
  return CubeScanNotifier(service, algorithmRepo, scanRepo);
});
