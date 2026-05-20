import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import 'local_cache_card.dart';
import 'storage_donut_card.dart';

// Premium callback-based widget measurement helper using RenderProxyBox
typedef OnWidgetSizeChange = void Function(Size size);

class MeasureSizeRenderObject extends RenderProxyBox {
  Size? oldSize;
  OnWidgetSizeChange onChange;

  MeasureSizeRenderObject(this.onChange);

  @override
  void performLayout() {
    super.performLayout();

    final newSize = child?.size;
    if (newSize != null && oldSize != newSize) {
      oldSize = newSize;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onChange(newSize);
      });
    }
  }
}

class MeasureSize extends SingleChildRenderObjectWidget {
  final OnWidgetSizeChange onChange;

  const MeasureSize({
    required this.onChange,
    required super.child,
    super.key,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return MeasureSizeRenderObject(onChange);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant MeasureSizeRenderObject renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class StorageSwipeCard extends ConsumerStatefulWidget {
  const StorageSwipeCard({
    required this.used,
    required this.categories,
    super.key,
  });

  final int used;
  final List<StorageCategory> categories;

  @override
  ConsumerState<StorageSwipeCard> createState() => _StorageSwipeCardState();
}

class _StorageSwipeCardState extends ConsumerState<StorageSwipeCard> {
  late final PageController _pageController;
  final Map<int, double> _heights = {};
  double _currentPage = 0.0;
  double? _currentHeight;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onScroll);
    _pageController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    if (_pageController.hasClients) {
      final page = _pageController.page ?? 0.0;
      setState(() {
        _currentPage = page;
        _updateHeight(page);
      });
    }
  }

  void _updateHeight(double page) {
    final index = page.floor();
    final nextIndex = page.ceil();
    final h1 = _heights[index];
    final h2 = _heights[nextIndex];

    if (h1 != null && h2 != null) {
      final fraction = page - index;
      _currentHeight = h1 + (h2 - h1) * fraction;
    } else if (h1 != null) {
      _currentHeight = h1;
    } else if (h2 != null) {
      _currentHeight = h2;
    }
  }

  void _onSizeChanged(int index, Size size) {
    if (!mounted) return;
    _heights[index] = size.height;
    
    if (_pageController.hasClients) {
      setState(() {
        _updateHeight(_pageController.page ?? 0.0);
      });
    } else if (index == 0) {
      setState(() {
        _currentHeight = size.height;
      });
    }
  }

  void _navigateToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final activeIndex = _currentPage.round();

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.mdR,
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header segmented tabs capsule
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            child: SlidingSegmentedTab(
              selectedIndex: activeIndex,
              onTabSelected: _navigateToPage,
            ),
          ),
          
          const SizedBox(height: AppSpacing.sm),

          // Scrollable content area
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.fastOutSlowIn,
            height: _currentHeight ?? 340.0,
            child: PageView(
              controller: _pageController,
              children: [
                OverflowBox(
                  minHeight: 0,
                  maxHeight: double.infinity,
                  alignment: Alignment.topCenter,
                  child: MeasureSize(
                    onChange: (size) => _onSizeChanged(0, size),
                    child: StorageDonutCard(
                      used: widget.used,
                      categories: widget.categories,
                      embed: true,
                    ),
                  ),
                ),
                OverflowBox(
                  minHeight: 0,
                  maxHeight: double.infinity,
                  alignment: Alignment.topCenter,
                  child: MeasureSize(
                    onChange: (size) => _onSizeChanged(1, size),
                    child: LocalCacheCard(
                      embed: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class SlidingSegmentedTab extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const SlidingSegmentedTab({
    required this.selectedIndex,
    required this.onTabSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final tabWidth = (width - 8) / 2;

          return Stack(
            children: [
              // Sliding pill background
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.fastOutSlowIn,
                left: selectedIndex == 0 ? 0 : tabWidth,
                width: tabWidth,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              // Interactive tabs
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onTabSelected(0),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: theme.textTheme.labelLarge!.copyWith(
                            fontWeight: FontWeight.w600,
                            color: selectedIndex == 0
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                          child: const Text('Cloud Storage'),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onTabSelected(1),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: theme.textTheme.labelLarge!.copyWith(
                            fontWeight: FontWeight.w600,
                            color: selectedIndex == 1
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                          child: const Text('Device Cache'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
