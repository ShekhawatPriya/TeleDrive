import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        padding: const EdgeInsets.fromLTRB(24, 12, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subtitle,
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.5,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
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
                    alignToScreenEdge: true,
                  ),
                const AccountButton(),
              ],
            ),
            const SizedBox(height: 20),
            DriveSearchField(key: ValueKey(scope), scope: scope),
          ],
        ),
      ),
    );
  }
}

class DriveSearchField extends ConsumerStatefulWidget {
  const DriveSearchField({required this.scope, super.key});
  final SearchScope scope;
  @override
  ConsumerState<DriveSearchField> createState() => _DriveSearchFieldState();
}

class _DriveSearchFieldState extends ConsumerState<DriveSearchField> {
  late final TextEditingController _text;
  @override
  void initState() {
    super.initState();
    _text = TextEditingController(
      text: ref.read(searchQueryProvider(widget.scope)).raw,
    );
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(searchQueryProvider(widget.scope));
    ref.listen(searchQueryProvider(widget.scope), (_, next) {
      if (_text.text != next.raw)
        _text.value = TextEditingValue(
          text: next.raw,
          selection: TextSelection.collapsed(offset: next.raw.length),
        );
    });
    final hint = switch (widget.scope) {
      SearchScope.drive => 'Search files and folders',
      SearchScope.photos => 'Search photos and videos',
      SearchScope.starred => 'Search starred items',
      SearchScope.shared => 'Search shared items',
    };
    return TextField(
      controller: _text,
      textInputAction: TextInputAction.search,
      onChanged: (value) {
        controller.update(value);
        setState(() {});
      },
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _text.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.cancel_rounded),
                onPressed: () {
                  _text.clear();
                  controller.clear();
                  setState(() {});
                },
              ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            Theme.of(context).platform == TargetPlatform.iOS ? 16 : 28,
          ),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            Theme.of(context).platform == TargetPlatform.iOS ? 16 : 28,
          ),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
