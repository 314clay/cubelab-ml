import 'package:cubelab/data/repositories/algorithm_repository.dart';
import 'package:cubelab/data/repositories/cross_trainer_repository.dart';
import 'package:cubelab/data/repositories/profile_repository.dart';
import 'package:cubelab/data/repositories/timer_repository.dart';
import 'package:cubelab/data/repositories/user_repository.dart';

class StubProfileRepository implements ProfileRepository {
  final AlgorithmRepository algorithmRepository;
  final CrossTrainerRepository crossTrainerRepository;
  final TimerRepository timerRepository;
  final UserRepository userRepository;

  StubProfileRepository({
    required this.algorithmRepository,
    required this.crossTrainerRepository,
    required this.timerRepository,
    required this.userRepository,
  });

  @override
  Future<Map<String, dynamic>> getProfileStats() async {
    return {};
  }

  @override
  Future<List<Map<String, dynamic>>> getAchievements() async {
    return [];
  }

  @override
  Future<Map<String, dynamic>> getActivitySummary() async {
    return {};
  }
}
