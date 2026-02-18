import 'package:flutter/material.dart';
import 'package:cubelab/core/theme/app_colors.dart';
import 'package:cubelab/core/theme/app_text_styles.dart';

/// Describes a page within a [SectionShell].
class SectionPage {
  final String label;
  final Widget page;

  const SectionPage({required this.label, required this.page});
}

/// Shell with a top AppBar, TabBar, and swipeable PageView.
class SectionShell extends StatefulWidget {
  final String title;
  final int initialPage;
  final List<SectionPage> pages;

  const SectionShell({
    super.key,
    required this.title,
    this.initialPage = 0,
    required this.pages,
  });

  @override
  State<SectionShell> createState() => _SectionShellState();
}

class _SectionShellState extends State<SectionShell>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.pages.length,
      vsync: this,
      initialIndex: widget.initialPage,
    );
    _pageController = PageController(initialPage: widget.initialPage);

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _pageController.animateToPage(
          _tabController.index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
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
        title: Text(widget.title, style: AppTextStyles.h3),
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) {
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: AppTextStyles.buttonText,
          unselectedLabelStyle: AppTextStyles.buttonText,
          tabs: widget.pages.map((p) => Tab(text: p.label)).toList(),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) {
          _tabController.animateTo(index);
        },
        children: widget.pages.map((p) => p.page).toList(),
      ),
    );
  }
}
