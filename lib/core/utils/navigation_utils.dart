import 'package:flutter/material.dart';
import 'package:cubelab/features/cross_trainer/cross_trainer_section.dart';
import 'package:cubelab/features/algorithm/algorithm_section.dart';
import 'package:cubelab/features/daily_scramble/daily_scramble_section.dart';
import 'package:cubelab/features/timer/timer_page.dart';
import 'package:cubelab/features/profile/profile_page.dart';

/// Navigation utilities for CubeLab
class NavigationUtils {
  /// Navigate to Cross Trainer section
  static void goToCrossTrainer(BuildContext context, {int initialPage = 0}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CrossTrainerSection(initialPage: initialPage),
      ),
    );
  }

  /// Navigate to Algorithm section
  static void goToAlgorithm(BuildContext context, {int initialPage = 0}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlgorithmSection(initialPage: initialPage),
      ),
    );
  }

  /// Navigate to Daily Scramble section
  static void goToDailyScramble(BuildContext context, {int initialPage = 0}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DailyScrambleSection(initialPage: initialPage),
      ),
    );
  }

  /// Navigate to Timer
  static void goToTimer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TimerPage()),
    );
  }

  /// Navigate to Profile
  static void goToProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfilePage()),
    );
  }

  /// Return to Home from anywhere
  static void goHome(BuildContext context) {
    Navigator.popUntil(context, (route) => route.isFirst);
  }
}
