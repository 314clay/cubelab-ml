import 'package:flutter/material.dart';
import 'package:cubelab/shared/widgets/section_shell.dart';
import 'package:cubelab/features/algorithm/pages/algorithm_catalog_page.dart';
import 'package:cubelab/features/algorithm/pages/algorithm_training_page.dart';
import 'package:cubelab/features/algorithm/pages/algorithm_srs_page.dart';
import 'package:cubelab/features/algorithm/pages/algorithm_stats_page.dart';

/// Algorithm section with swipeable pages
///
/// Contains 4 pages:
/// - Catalog: Browse and enable/disable algorithms by set
/// - Train: Active drilling with timer
/// - SRS: Spaced repetition review queue
/// - Stats: Performance statistics dashboard
class AlgorithmSection extends StatelessWidget {
  final int initialPage;

  const AlgorithmSection({super.key, this.initialPage = 0});

  @override
  Widget build(BuildContext context) {
    return SectionShell(
      title: 'Algorithms',
      initialPage: initialPage,
      pages: const [
        SectionPage(label: 'Catalog', page: AlgorithmCatalogPage()),
        SectionPage(label: 'Train', page: AlgorithmTrainingPage()),
        SectionPage(label: 'SRS', page: AlgorithmSRSPage()),
        SectionPage(label: 'Stats', page: AlgorithmStatsPage()),
      ],
    );
  }
}
