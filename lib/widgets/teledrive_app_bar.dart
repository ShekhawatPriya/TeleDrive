import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
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
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
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
            const SizedBox(height: 12),
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
          borderRadius: AppRadii.smR,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.smR,
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
