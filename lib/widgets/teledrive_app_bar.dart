import 'drive_search_field.dart';
export 'drive_search_field.dart';
import 'package:flutter/material.dart';
import '../features/search/search_controller.dart';
import 'account_button.dart';
import 'ios_more_menu.dart';

/// Compact search toolbar for secondary sliver-based screens.
class TeleDriveAppBar extends StatelessWidget {
  const TeleDriveAppBar({required this.scope, this.menuSections, super.key});
  final SearchScope scope;
  final IosMenuSectionsBuilder? menuSections;
  @override
  Widget build(BuildContext context) => SliverAppBar(
    pinned: true,
    title: DriveSearchField(scope: scope),
    actions: [
      if (menuSections != null) IosMoreButton(sectionsBuilder: menuSections!),
      const AccountButton(),
    ],
  );
}

/// Clear destination title, scoped search and a consistent account entry point.
class TeleDriveTopBar extends StatelessWidget {
  const TeleDriveTopBar({required this.scope, this.menuSections, super.key});
  final SearchScope scope;
  final IosMenuSectionsBuilder? menuSections;

  @override
  Widget build(BuildContext context) {
    final title = switch (scope) {
      SearchScope.drive => 'Your drive',
      SearchScope.photos => 'Photos',
      SearchScope.starred => 'Starred',
      SearchScope.shared => 'Shared',
    };
    final theme = Theme.of(context);
    final ios = theme.platform == TargetPlatform.iOS;
    final subtitle = switch (scope) {
      SearchScope.drive => 'YOUR EVERYDAY SPACE',
      SearchScope.photos => 'THE MOMENTS YOU KEEP',
      SearchScope.starred => 'ALWAYS WITHIN REACH',
      SearchScope.shared => 'GOOD THINGS, SHARED',
    };
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!ios)
                        Text(
                          subtitle,
                          style: theme.textTheme.labelSmall?.copyWith(
                            letterSpacing: 1.5,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (!ios) const SizedBox(height: 6),
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontSize: ios ? 34 : 36,
                            letterSpacing: -1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (menuSections != null)
                  IosMoreButton(
                    sectionsBuilder: menuSections!,
                    size: 44,
                    visualSize: 34,
                    alignToScreenEdge: true,
                  ),
                const AccountButton(avatarSize: 44),
              ],
            ),
            if (scope != SearchScope.photos) ...[
              const SizedBox(height: 16),
              DriveSearchField(key: ValueKey(scope), scope: scope),
            ],
          ],
        ),
      ),
    );
  }
}
