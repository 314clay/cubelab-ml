import 'package:flutter/material.dart';
import 'package:cubelab/shared/widgets/section_shell.dart';
import 'package:cubelab/features/cross_trainer/pages/cross_practice_page.dart';
import 'package:cubelab/features/cross_trainer/pages/cross_srs_page.dart';
import 'package:cubelab/features/cross_trainer/pages/cross_stats_page.dart';

/// Cross Trainer section with swipeable pages
///
/// Contains 3 pages:
/// - Practice: Main cross training practice with timer
/// - SRS: Spaced repetition review of saved scrambles
/// - Stats: Performance stats dashboard
class CrossTrainerSection extends StatelessWidget {
  final int initialPage;

  const CrossTrainerSection({super.key, this.initialPage = 0});

  @override
  Widget build(BuildContext context) {
    return SectionShell(
      title: 'Cross Trainer',
      initialPage: initialPage,
      pages: const [
        SectionPage(label: 'Practice', page: CrossPracticePage()),
        SectionPage(label: 'SRS', page: CrossSRSPage()),
        SectionPage(label: 'Stats', page: CrossStatsPage()),
      ],
    );
  }
}
