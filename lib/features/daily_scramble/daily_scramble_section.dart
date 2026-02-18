import 'package:flutter/material.dart';
import 'package:cubelab/shared/widgets/section_shell.dart';
import 'package:cubelab/features/daily_scramble/pages/daily_scramble_page.dart';
import 'package:cubelab/features/daily_scramble/pages/community_solves_page.dart';
import 'package:cubelab/features/daily_scramble/pages/goat_list_page.dart';

/// Daily Scramble section with swipeable pages
///
/// Contains 3 pages:
/// - Solve: Main page where users attempt today's scramble
/// - Community: View all community solves for today
/// - GOAT: List view of professional reconstructions
class DailyScrambleSection extends StatelessWidget {
  final int initialPage;

  const DailyScrambleSection({super.key, this.initialPage = 0});

  @override
  Widget build(BuildContext context) {
    return SectionShell(
      title: 'Daily Scramble',
      initialPage: initialPage,
      pages: const [
        SectionPage(label: 'Solve', page: DailyScramblePage()),
        SectionPage(label: 'Community', page: CommunitySolvesPage()),
        SectionPage(label: 'GOAT', page: GoatListPage()),
      ],
    );
  }
}
