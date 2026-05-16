import 'package:flutter/material.dart';

import 'country_data.dart';

/// A premium, searchable country code picker shown as a modal bottom sheet.
/// Inspired by Telegram's country picker — smooth, minimal, and fast.
Future<Country?> showCountryPicker(BuildContext context) {
  return showModalBottomSheet<Country>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CountryPickerSheet(),
  );
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet();

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchController = TextEditingController();
  List<Country> _filtered = countries;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearch);
  }

  void _onSearch() {
    final query = _searchController.text;
    setState(() {
      _filtered = countries.where((c) => c.matches(query)).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xff1e1e1c) : Colors.white;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                Text(
                  'Choose a country',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close_rounded,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Search country or code...',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  size: 22,
                ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Country list
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No countries found',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _filtered.length,
                    itemExtent: 56,
                    itemBuilder: (context, index) {
                      final country = _filtered[index];
                      return _CountryTile(
                        country: country,
                        onTap: () => Navigator.pop(context, country),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CountryTile extends StatelessWidget {
  const _CountryTile({required this.country, required this.onTap});

  final Country country;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Flag emoji
              Text(
                country.flag,
                style: const TextStyle(fontSize: 26),
              ),
              const SizedBox(width: 14),
              // Country name
              Expanded(
                child: Text(
                  country.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Dial code
              Text(
                country.dialCode,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
