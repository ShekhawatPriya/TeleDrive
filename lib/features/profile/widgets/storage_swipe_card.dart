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

  const MeasureSize({required this.onChange, required super.child, super.key});

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
  int _activeIndex = 0;

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
      final newActiveIndex = page.round();
      if (newActiveIndex != _activeIndex) {
        setState(() {
          _activeIndex = newActiveIndex;
        });
      }
    }
  }

  void _onSizeChanged(int index, Size size) {
    if (!mounted) return;
    final oldHeight = _heights[index];
    if (oldHeight == size.height)
      return; // Skip redundant updates if height is unchanged

    _heights[index] = size.height;

    // Trigger height adjustment rebuild if this page size is finalized
    if (index == _activeIndex || oldHeight == null) {
      setState(() {});
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

    // Use sensible defaults on first frame if sizes are not yet measured
    final targetHeight =
        _heights[_activeIndex] ?? (_activeIndex == 0 ? 340.0 : 500.0);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.mdR,
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header segmented tabs capsule driven directly by PageController
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            child: SlidingSegmentedTab(
              controller: _pageController,
              onTabSelected: _navigateToPage,
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Scrollable content area with smooth threshold-based height transitions
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.fastOutSlowIn,
            height: targetHeight,
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
                    child: LocalCacheCard(embed: true),
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
  final PageController controller;
  final ValueChanged<int> onTabSelected;

  const SlidingSegmentedTab({
    required this.controller,
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
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final tabWidth = (width - 8) / 2;

          return AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              double page = 0.0;
              if (controller.hasClients) {
                try {
                  page = controller.page ?? 0.0;
                } catch (_) {
                  page = 0.0;
                }
              }
              final clampedPage = page.clamp(0.0, 1.0);

              return Stack(
                children: [
                  // Sliding pill background
                  Positioned(
                    left: clampedPage * tabWidth,
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
                  // Interactive tabs with dynamic cross-fading text colors
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => onTabSelected(0),
                          behavior: HitTestBehavior.opaque,
                          child: Center(
                            child: Text(
                              'Cloud Storage',
                              style: theme.textTheme.labelLarge!.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Color.lerp(
                                  scheme.onSurfaceVariant,
                                  scheme.primary,
                                  1.0 - clampedPage,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => onTabSelected(1),
                          behavior: HitTestBehavior.opaque,
                          child: Center(
                            child: Text(
                              'Device Cache',
                              style: theme.textTheme.labelLarge!.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Color.lerp(
                                  scheme.onSurfaceVariant,
                                  scheme.primary,
                                  clampedPage,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
