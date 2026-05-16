import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'country_data.dart';

/// A premium, searchable country code picker shown as a modal bottom sheet.
/// Styled to match the Claude/Anthropic design system — warm, clean, editorial.
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
    const parchment = AppColors.parchment;
    const ivory = AppColors.ivory;
    const nearBlack = AppColors.nearBlack;
    const stone = AppColors.stone;
    const borderCream = AppColors.border;
    const borderWarm = AppColors.warmSand;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: ivory,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: borderWarm,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 16, 0),
            child: Row(
              children: [
                const Text(
                  'Choose a country',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: nearBlack,
                    height: 1.2,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: borderWarm,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Color(0xff4d4c48), // Charcoal Warm
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
            child: Container(
              decoration: BoxDecoration(
                color: parchment,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderCream),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: false,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: nearBlack,
                ),
                decoration: InputDecoration(
                  hintText: 'Search country or code…',
                  hintStyle: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: stone.withValues(alpha: 0.6),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: stone,
                    size: 20,
                  ),
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ),
          // Divider
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Divider(color: borderCream, height: 1),
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
                          size: 44,
                          color: stone.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No countries found',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 15,
                            color: stone.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Divider(
                        color: borderCream,
                        height: 1,
                      ),
                    ),
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
    const nearBlack = AppColors.nearBlack;

    const stone = AppColors.stone;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: AppColors.warmSand.withValues(alpha: 0.4),
        highlightColor: AppColors.warmSand.withValues(alpha: 0.2),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              // Flag emoji
              Text(
                country.flag,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 14),
              // Country name
              Expanded(
                child: Text(
                  country.name,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: nearBlack,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Dial code
              Text(
                country.dialCode,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: stone,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
