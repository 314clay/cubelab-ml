import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:cubelab/data/models/algorithm.dart';
import 'package:cubelab/data/models/algorithm_review.dart';
import 'package:cubelab/data/models/algorithm_solve.dart';
import 'package:cubelab/data/models/cube_scan_encounter.dart';
import 'package:cubelab/data/models/cube_scan_result.dart';
import 'package:cubelab/data/models/daily_algorithm_challenge.dart';
import 'package:cubelab/data/models/daily_challenge_attempt.dart';
import 'package:cubelab/data/models/srs_state.dart';
import 'package:cubelab/data/models/stats.dart';
import 'package:cubelab/data/models/training_session.dart';
import 'package:cubelab/data/models/training_solve.dart';
import 'package:cubelab/data/models/training_stats.dart';
import 'package:cubelab/data/models/user_algorithm.dart';
import 'package:cubelab/data/models/zbll_subset.dart';
import 'package:cubelab/data/repositories/algorithm_repository.dart';
import 'package:cubelab/data/services/cube_analysis_service.dart';
import 'package:cubelab/data/services/stub_cube_analysis_service.dart';
import 'package:cubelab/data/stubs/stub_cube_scan_repository.dart';
import 'package:cubelab/features/cube_scan/providers/cube_scan_providers.dart';

// ============ Mock Implementations ============

class MockCubeAnalysisService implements CubeAnalysisService {
  CubeScanResult? resultToReturn;
  Exception? errorToThrow;
  int analyzeCallCount = 0;

  @override
  Future<CubeScanResult> analyze(Uint8List imageBytes) async {
    analyzeCallCount++;
    if (errorToThrow != null) throw errorToThrow!;
    return resultToReturn!;
  }

  @override
  Future<bool> isAvailable() async => true;
}

class MockAlgorithmRepository implements AlgorithmRepository {
  final List<Algorithm> algorithms;
  final Map<String, UserAlgorithm> userAlgorithms;
  final List<AlgorithmReview> recordedReviews = [];
  final List<String> enabledAlgorithms = [];

  MockAlgorithmRepository({
    this.algorithms = const [],
    this.userAlgorithms = const {},
  });

  @override
  Future<List<Algorithm>> getAlgorithmsBySet(AlgorithmSet set) async {
    return algorithms.where((a) => a.set == set).toList();
  }

  @override
  Future<UserAlgorithm?> getUserAlgorithm(String algorithmId) async {
    return userAlgorithms[algorithmId];
  }

  @override
  Future<void> setAlgorithmEnabled(String algorithmId, bool enabled) async {
    if (enabled) enabledAlgorithms.add(algorithmId);
  }

  @override
  Future<void> recordReview(AlgorithmReview review) async {
    recordedReviews.add(review);
  }

  // Unused stubs
  @override
  Future<List<Algorithm>> getAllAlgorithms() async => [];
  @override
  Future<List<Algorithm>> getAlgorithmsBySubset(AlgorithmSet set, String subset) async => [];
  @override
  Future<Algorithm?> getAlgorithm(String id) async => null;
  @override
  Future<List<String>> getZBLLSubsets() async => [];
  @override
  Future<ZBLLStructure> getZBLLStructure() async => const ZBLLStructure(subsets: [], totalCases: 0);
  @override
  Future<List<UserAlgorithm>> getUserAlgorithms() async => [];
  @override
  Future<void> setCustomAlgorithm(String algorithmId, String? customAlg) async {}
  @override
  Future<void> enableAllInSet(AlgorithmSet set) async {}
  @override
  Future<void> disableAllInSet(AlgorithmSet set) async {}
  @override
  Future<void> enableAllInSubset(AlgorithmSet set, String subset) async {}
  @override
  Future<void> disableAllInSubset(AlgorithmSet set, String subset) async {}
  @override
  Future<void> saveSolve(AlgorithmSolve solve) async {}
  @override
  Future<List<AlgorithmSolve>> getRecentSolves({int limit = 20}) async => [];
  @override
  Future<List<AlgorithmSolve>> getSolvesForAlgorithm(String algorithmId, {int limit = 20}) async => [];
  @override
  Future<AlgorithmStats> getStats({DateRange? range}) async => const AlgorithmStats(totalLearned: 0, totalDrills: 0, avgTimeMs: 0, dueToday: 0, bySet: {}, weakestCases: []);
  @override
  Future<int> getLearnedCount(AlgorithmSet set) async => 0;
  @override
  Future<int> getEnabledCount(AlgorithmSet set) async => 0;
  @override
  Future<int> getDueCount() async => 0;
  @override
  Future<List<DrillSession>> getDrillHistory({int limit = 10}) async => [];
  @override
  Future<List<TrendDataPoint>> getPerformanceTrend({int limit = 30}) async => [];
  @override
  Future<List<UserAlgorithm>> getDueAlgorithms() async => [];
  @override
  Future<UserAlgorithm?> getNextDueAlgorithm() async => null;
  @override
  Future<List<AlgorithmReview>> getReviewHistory(String algorithmId, {int limit = 20}) async => [];
  @override
  Future<TrainingStats> getTrainingStats() async => const TrainingStats();
  @override
  Future<List<TrainingSession>> getRecentSessions({int limit = 5}) async => [];
  @override
  Future<TrainingSession?> getCurrentSession() async => null;
  @override
  Future<void> saveSession(TrainingSession session) async {}
  @override
  Future<void> saveTrainingSolve(TrainingSolve solve, String sessionId) async {}
  @override
  Future<List<Algorithm>> getDueTrainingCases() async => [];
  @override
  Future<List<Algorithm>> getRandomTrainingCases({int count = 20}) async => [];
  @override
  Future<List<String>> getMultipleChoiceOptions(String algorithmId) async => [];
  @override
  Future<SRSRating> autoRatePerformance(String algorithmId, int totalTimeMs) async => SRSRating.good;
  @override
  Future<DailyAlgorithmChallenge> getDailyAlgorithmChallenge(DateTime date) async => throw UnimplementedError();
  @override
  Future<void> saveDailyChallengeAttempt(DailyChallengeAttempt attempt) async {}
  @override
  Future<List<DailyAlgorithmChallenge>> getRecentDailyChallenges({int limit = 7}) async => [];
}

// ============ Test Data ============

const _testOllResult = CubeScanResult(
  visible27: [
    'R', 'W', 'W', 'W', 'W', 'O', 'W', 'W', 'B',
    'W', 'R', 'R', 'R', 'R', 'R', 'R', 'R', 'R',
    'W', 'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B',
  ],
  state54: {
    'U': ['R', 'W', 'W', 'W', 'W', 'O', 'W', 'W', 'B'],
    'F': ['W', 'R', 'R', 'R', 'R', 'R', 'R', 'R', 'R'],
    'R': ['W', 'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B'],
    'D': ['Y', 'Y', 'Y', 'Y', 'Y', 'Y', 'Y', 'Y', 'Y'],
    'B': ['O', 'O', 'O', 'O', 'O', 'O', 'O', 'O', 'O'],
    'L': ['G', 'G', 'G', 'G', 'G', 'G', 'G', 'G', 'G'],
  },
  phase: 'oll',
  caseName: 'OLL 27',
  caseSet: 'OLL',
  confidence: 0.97,
  solvePaths: [
    SolvePath(
      description: 'OLL 27 → T-Perm',
      totalMoves: 19,
      steps: [
        SolveStep(
          algorithmSet: 'OLL',
          caseName: 'OLL 27',
          algorithm: "R U R' U R U2 R'",
          moveCount: 7,
        ),
      ],
    ),
  ],
);

const _testSolvedResult = CubeScanResult(
  visible27: [
    'W', 'W', 'W', 'W', 'W', 'W', 'W', 'W', 'W',
    'R', 'R', 'R', 'R', 'R', 'R', 'R', 'R', 'R',
    'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B',
  ],
  state54: {
    'U': ['W', 'W', 'W', 'W', 'W', 'W', 'W', 'W', 'W'],
    'F': ['R', 'R', 'R', 'R', 'R', 'R', 'R', 'R', 'R'],
    'R': ['B', 'B', 'B', 'B', 'B', 'B', 'B', 'B', 'B'],
    'D': ['Y', 'Y', 'Y', 'Y', 'Y', 'Y', 'Y', 'Y', 'Y'],
    'B': ['O', 'O', 'O', 'O', 'O', 'O', 'O', 'O', 'O'],
    'L': ['G', 'G', 'G', 'G', 'G', 'G', 'G', 'G', 'G'],
  },
  phase: 'solved',
  caseName: null,
  caseSet: null,
  confidence: 1.0,
  solvePaths: [],
);

void main() {
  // ============ CubeScanResult Model Tests ============

  group('CubeScanResult', () {
    test('fromJson/toJson roundtrip preserves all fields', () {
      final json = _testOllResult.toJson();
      final parsed = CubeScanResult.fromJson(json);

      expect(parsed.visible27, equals(_testOllResult.visible27));
      expect(parsed.state54, equals(_testOllResult.state54));
      expect(parsed.phase, equals('oll'));
      expect(parsed.caseName, equals('OLL 27'));
      expect(parsed.caseSet, equals('OLL'));
      expect(parsed.confidence, equals(0.97));
      expect(parsed.solvePaths.length, equals(1));
      expect(parsed.solvePaths[0].description, equals('OLL 27 → T-Perm'));
      expect(parsed.solvePaths[0].totalMoves, equals(19));
      expect(parsed.solvePaths[0].steps.length, equals(1));
    });

    test('fromJson handles null caseName and caseSet', () {
      final json = _testSolvedResult.toJson();
      final parsed = CubeScanResult.fromJson(json);

      expect(parsed.caseName, isNull);
      expect(parsed.caseSet, isNull);
      expect(parsed.phase, equals('solved'));
      expect(parsed.confidence, equals(1.0));
      expect(parsed.solvePaths, isEmpty);
    });
  });

  group('SolveStep', () {
    test('fromJson/toJson roundtrip', () {
      const step = SolveStep(
        algorithmSet: 'OLL',
        caseName: 'OLL 27',
        algorithm: "R U R' U R U2 R'",
        moveCount: 7,
      );
      final json = step.toJson();
      final parsed = SolveStep.fromJson(json);

      expect(parsed.algorithmSet, equals('OLL'));
      expect(parsed.caseName, equals('OLL 27'));
      expect(parsed.algorithm, equals("R U R' U R U2 R'"));
      expect(parsed.moveCount, equals(7));
    });
  });

  // ============ CubeScanEncounter Model Tests ============

  group('CubeScanEncounter', () {
    final encounter = CubeScanEncounter(
      id: 'enc-1',
      userId: 'user-1',
      algorithmId: 'alg-oll-27',
      phase: 'oll',
      caseName: 'OLL 27',
      confidence: 0.97,
      srsRating: 'good',
      addedToQueue: true,
      scannedAt: DateTime.utc(2025, 6, 15, 10, 30),
    );

    test('fromJson/toJson roundtrip', () {
      final json = encounter.toJson();
      final parsed = CubeScanEncounter.fromJson(json);

      expect(parsed.id, equals('enc-1'));
      expect(parsed.userId, equals('user-1'));
      expect(parsed.algorithmId, equals('alg-oll-27'));
      expect(parsed.phase, equals('oll'));
      expect(parsed.caseName, equals('OLL 27'));
      expect(parsed.confidence, equals(0.97));
      expect(parsed.srsRating, equals('good'));
      expect(parsed.addedToQueue, isTrue);
      expect(parsed.scannedAt, equals(DateTime.utc(2025, 6, 15, 10, 30)));
    });

    test('fromSupabase/toSupabase roundtrip', () {
      final supabase = encounter.toSupabase();
      final parsed = CubeScanEncounter.fromSupabase(supabase);

      expect(parsed.id, equals('enc-1'));
      expect(parsed.userId, equals('user-1'));
      expect(parsed.algorithmId, equals('alg-oll-27'));
      expect(parsed.phase, equals('oll'));
      expect(parsed.caseName, equals('OLL 27'));
      expect(parsed.confidence, equals(0.97));
      expect(parsed.srsRating, equals('good'));
      expect(parsed.addedToQueue, isTrue);
    });

    test('copyWith overrides fields', () {
      final updated = encounter.copyWith(
        srsRating: 'again',
        addedToQueue: false,
      );

      expect(updated.id, equals('enc-1'));
      expect(updated.srsRating, equals('again'));
      expect(updated.addedToQueue, isFalse);
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'id': 'enc-2',
        'userId': 'user-1',
        'phase': 'solved',
        'confidence': 1.0,
        'scannedAt': DateTime.utc(2025, 6, 15).toIso8601String(),
      };
      final parsed = CubeScanEncounter.fromJson(json);

      expect(parsed.algorithmId, isNull);
      expect(parsed.caseName, isNull);
      expect(parsed.srsRating, isNull);
      expect(parsed.addedToQueue, isFalse);
    });
  });

  // ============ StubCubeAnalysisService Tests ============

  group('StubCubeAnalysisService', () {
    test('isAvailable returns true', () async {
      final service = StubCubeAnalysisService();
      expect(await service.isAvailable(), isTrue);
    });

    test('analyze returns a valid CubeScanResult', () async {
      final service = StubCubeAnalysisService();
      final result = await service.analyze(Uint8List(0));

      expect(result.visible27.length, equals(27));
      expect(result.state54.keys.length, equals(6));
      expect(result.confidence, greaterThan(0));
      expect(result.confidence, lessThanOrEqualTo(1.0));
      expect(
        ['oll', 'pll', 'solved'],
        contains(result.phase),
      );
    });

    test('analyze returns varied results', () async {
      final service = StubCubeAnalysisService();
      final phases = <String>{};

      // Run enough times to get variety (each call has 2s delay, so keep small)
      for (int i = 0; i < 5; i++) {
        final result = await service.analyze(Uint8List(0));
        phases.add(result.phase);
      }

      // Should return valid phases
      for (final phase in phases) {
        expect(['oll', 'pll', 'solved'], contains(phase));
      }
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  // ============ StubCubeScanRepository Tests ============

  group('StubCubeScanRepository', () {
    test('saves and retrieves encounters', () async {
      final repo = StubCubeScanRepository();

      final encounter = CubeScanEncounter(
        id: 'enc-1',
        userId: 'user-1',
        phase: 'oll',
        caseName: 'OLL 27',
        confidence: 0.97,
        scannedAt: DateTime.now(),
      );

      await repo.saveEncounter(encounter);
      final results = await repo.getRecentEncounters('user-1');

      expect(results.length, equals(1));
      expect(results[0].caseName, equals('OLL 27'));
    });

    test('filters by userId', () async {
      final repo = StubCubeScanRepository();

      await repo.saveEncounter(CubeScanEncounter(
        id: 'enc-1',
        userId: 'user-1',
        phase: 'oll',
        confidence: 0.97,
        scannedAt: DateTime.now(),
      ));
      await repo.saveEncounter(CubeScanEncounter(
        id: 'enc-2',
        userId: 'user-2',
        phase: 'pll',
        confidence: 0.95,
        scannedAt: DateTime.now(),
      ));

      final user1Results = await repo.getRecentEncounters('user-1');
      expect(user1Results.length, equals(1));
      expect(user1Results[0].phase, equals('oll'));
    });
  });

  // ============ CubeScanNotifier State Machine Tests ============

  group('CubeScanNotifier', () {
    late MockCubeAnalysisService analysisService;
    late MockAlgorithmRepository algorithmRepo;
    late StubCubeScanRepository scanRepo;
    late CubeScanNotifier notifier;

    setUp(() {
      analysisService = MockCubeAnalysisService();
      algorithmRepo = MockAlgorithmRepository();
      scanRepo = StubCubeScanRepository();
      notifier = CubeScanNotifier(analysisService, algorithmRepo, scanRepo);
    });

    test('initial state is camera phase', () {
      expect(notifier.state.phase, equals(CubeScanPhase.camera));
      expect(notifier.state.result, isNull);
      expect(notifier.state.isKnownAlgorithm, isFalse);
      expect(notifier.state.solutionRevealed, isFalse);
    });

    test('captureAndAnalyze transitions to results on success', () async {
      analysisService.resultToReturn = _testOllResult;

      await notifier.captureAndAnalyze(Uint8List(0));

      expect(notifier.state.phase, equals(CubeScanPhase.results));
      expect(notifier.state.result, isNotNull);
      expect(notifier.state.result!.caseName, equals('OLL 27'));
      expect(notifier.state.result!.phase, equals('oll'));
    });

    test('captureAndAnalyze transitions to error on failure', () async {
      analysisService.errorToThrow = Exception('Network error');

      await notifier.captureAndAnalyze(Uint8List(0));

      expect(notifier.state.phase, equals(CubeScanPhase.error));
      expect(notifier.state.errorMessage, contains('Network error'));
    });

    test('captureAndAnalyze detects known algorithm', () async {
      analysisService.resultToReturn = _testOllResult;
      algorithmRepo = MockAlgorithmRepository(
        algorithms: [
          const Algorithm(
            id: 'alg-oll-27',
            set: AlgorithmSet.oll,
            name: 'OLL 27',
            defaultAlgs: ["R U R' U R U2 R'"],
          ),
        ],
        userAlgorithms: {
          'alg-oll-27': const UserAlgorithm(
            userId: 'user-1',
            algorithmId: 'alg-oll-27',
            enabled: true,
          ),
        },
      );
      notifier = CubeScanNotifier(analysisService, algorithmRepo, scanRepo);

      await notifier.captureAndAnalyze(Uint8List(0));

      expect(notifier.state.isKnownAlgorithm, isTrue);
      expect(notifier.state.matchedAlgorithmId, equals('alg-oll-27'));
    });

    test('captureAndAnalyze marks unknown algorithm', () async {
      analysisService.resultToReturn = _testOllResult;
      algorithmRepo = MockAlgorithmRepository(
        algorithms: [
          const Algorithm(
            id: 'alg-oll-27',
            set: AlgorithmSet.oll,
            name: 'OLL 27',
            defaultAlgs: ["R U R' U R U2 R'"],
          ),
        ],
        userAlgorithms: {
          'alg-oll-27': const UserAlgorithm(
            userId: 'user-1',
            algorithmId: 'alg-oll-27',
            enabled: false,
          ),
        },
      );
      notifier = CubeScanNotifier(analysisService, algorithmRepo, scanRepo);

      await notifier.captureAndAnalyze(Uint8List(0));

      expect(notifier.state.isKnownAlgorithm, isFalse);
      expect(notifier.state.matchedAlgorithmId, equals('alg-oll-27'));
    });

    test('solved state has no algorithm to look up', () async {
      analysisService.resultToReturn = _testSolvedResult;

      await notifier.captureAndAnalyze(Uint8List(0));

      expect(notifier.state.phase, equals(CubeScanPhase.results));
      expect(notifier.state.matchedAlgorithmId, isNull);
      expect(notifier.state.isKnownAlgorithm, isFalse);
    });

    test('revealSolution sets solutionRevealed', () async {
      analysisService.resultToReturn = _testOllResult;
      await notifier.captureAndAnalyze(Uint8List(0));

      expect(notifier.state.solutionRevealed, isFalse);
      notifier.revealSolution();
      expect(notifier.state.solutionRevealed, isTrue);
    });

    test('addToQueue enables algorithm and transitions to done', () async {
      analysisService.resultToReturn = _testOllResult;
      algorithmRepo = MockAlgorithmRepository(
        algorithms: [
          const Algorithm(
            id: 'alg-oll-27',
            set: AlgorithmSet.oll,
            name: 'OLL 27',
            defaultAlgs: ["R U R' U R U2 R'"],
          ),
        ],
      );
      notifier = CubeScanNotifier(analysisService, algorithmRepo, scanRepo);

      await notifier.captureAndAnalyze(Uint8List(0));
      await notifier.addToQueue();

      expect(notifier.state.phase, equals(CubeScanPhase.done));
      expect(algorithmRepo.enabledAlgorithms, contains('alg-oll-27'));
    });

    test('addToQueue saves encounter with addedToQueue=true', () async {
      analysisService.resultToReturn = _testOllResult;
      algorithmRepo = MockAlgorithmRepository(
        algorithms: [
          const Algorithm(
            id: 'alg-oll-27',
            set: AlgorithmSet.oll,
            name: 'OLL 27',
            defaultAlgs: ["R U R' U R U2 R'"],
          ),
        ],
      );
      notifier = CubeScanNotifier(analysisService, algorithmRepo, scanRepo);

      await notifier.captureAndAnalyze(Uint8List(0));
      await notifier.addToQueue();

      final encounters = await scanRepo.getRecentEncounters('');
      expect(encounters.length, equals(1));
      expect(encounters[0].addedToQueue, isTrue);
    });

    test('rateReview records review and transitions to done', () async {
      analysisService.resultToReturn = _testOllResult;
      algorithmRepo = MockAlgorithmRepository(
        algorithms: [
          const Algorithm(
            id: 'alg-oll-27',
            set: AlgorithmSet.oll,
            name: 'OLL 27',
            defaultAlgs: ["R U R' U R U2 R'"],
          ),
        ],
        userAlgorithms: {
          'alg-oll-27': const UserAlgorithm(
            userId: 'user-1',
            algorithmId: 'alg-oll-27',
            enabled: true,
          ),
        },
      );
      notifier = CubeScanNotifier(analysisService, algorithmRepo, scanRepo);

      await notifier.captureAndAnalyze(Uint8List(0));
      await notifier.rateReview(SRSRating.good);

      expect(notifier.state.phase, equals(CubeScanPhase.done));
      expect(algorithmRepo.recordedReviews.length, equals(1));
      expect(algorithmRepo.recordedReviews[0].rating, equals(SRSRating.good));
    });

    test('completeSrsAction (skip) transitions to done', () async {
      analysisService.resultToReturn = _testOllResult;
      await notifier.captureAndAnalyze(Uint8List(0));
      await notifier.completeSrsAction();

      expect(notifier.state.phase, equals(CubeScanPhase.done));
    });

    test('retake resets state to camera phase', () async {
      analysisService.resultToReturn = _testOllResult;
      await notifier.captureAndAnalyze(Uint8List(0));

      expect(notifier.state.phase, equals(CubeScanPhase.results));
      notifier.retake();
      expect(notifier.state.phase, equals(CubeScanPhase.camera));
      expect(notifier.state.result, isNull);
    });

    test('reset returns to initial state', () async {
      analysisService.resultToReturn = _testOllResult;
      await notifier.captureAndAnalyze(Uint8List(0));
      notifier.revealSolution();

      notifier.reset();

      expect(notifier.state.phase, equals(CubeScanPhase.camera));
      expect(notifier.state.result, isNull);
      expect(notifier.state.solutionRevealed, isFalse);
      expect(notifier.state.isKnownAlgorithm, isFalse);
    });

    test('full flow: capture → results → reveal → rate → done', () async {
      analysisService.resultToReturn = _testOllResult;
      algorithmRepo = MockAlgorithmRepository(
        algorithms: [
          const Algorithm(
            id: 'alg-oll-27',
            set: AlgorithmSet.oll,
            name: 'OLL 27',
            defaultAlgs: ["R U R' U R U2 R'"],
          ),
        ],
        userAlgorithms: {
          'alg-oll-27': const UserAlgorithm(
            userId: 'user-1',
            algorithmId: 'alg-oll-27',
            enabled: true,
          ),
        },
      );
      notifier = CubeScanNotifier(analysisService, algorithmRepo, scanRepo);

      // 1. Start at camera
      expect(notifier.state.phase, equals(CubeScanPhase.camera));

      // 2. Capture and analyze
      await notifier.captureAndAnalyze(Uint8List(0));
      expect(notifier.state.phase, equals(CubeScanPhase.results));
      expect(notifier.state.isKnownAlgorithm, isTrue);

      // 3. Reveal solution
      notifier.revealSolution();
      expect(notifier.state.solutionRevealed, isTrue);

      // 4. Rate as Good
      await notifier.rateReview(SRSRating.good);
      expect(notifier.state.phase, equals(CubeScanPhase.done));

      // Verify side effects
      expect(algorithmRepo.recordedReviews.length, equals(1));
      final encounters = await scanRepo.getRecentEncounters('');
      expect(encounters.length, equals(1));
      expect(encounters[0].srsRating, equals('good'));
    });

    test('full flow: capture → results → reveal → add to queue → done', () async {
      analysisService.resultToReturn = _testOllResult;
      algorithmRepo = MockAlgorithmRepository(
        algorithms: [
          const Algorithm(
            id: 'alg-oll-27',
            set: AlgorithmSet.oll,
            name: 'OLL 27',
            defaultAlgs: ["R U R' U R U2 R'"],
          ),
        ],
      );
      notifier = CubeScanNotifier(analysisService, algorithmRepo, scanRepo);

      await notifier.captureAndAnalyze(Uint8List(0));
      expect(notifier.state.isKnownAlgorithm, isFalse);

      notifier.revealSolution();
      await notifier.addToQueue();

      expect(notifier.state.phase, equals(CubeScanPhase.done));
      expect(algorithmRepo.enabledAlgorithms, contains('alg-oll-27'));

      final encounters = await scanRepo.getRecentEncounters('');
      expect(encounters[0].addedToQueue, isTrue);
    });
  });

  // ============ CubeScanState Tests ============

  group('CubeScanState', () {
    test('default state has correct values', () {
      const state = CubeScanState();

      expect(state.phase, equals(CubeScanPhase.camera));
      expect(state.capturedImage, isNull);
      expect(state.result, isNull);
      expect(state.matchedAlgorithmId, isNull);
      expect(state.isKnownAlgorithm, isFalse);
      expect(state.solutionRevealed, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('copyWith preserves unmodified fields', () {
      const state = CubeScanState(
        phase: CubeScanPhase.results,
        isKnownAlgorithm: true,
      );

      final updated = state.copyWith(solutionRevealed: true);

      expect(updated.phase, equals(CubeScanPhase.results));
      expect(updated.isKnownAlgorithm, isTrue);
      expect(updated.solutionRevealed, isTrue);
    });
  });
}
