import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../native_glass_button.dart';

/// iOS account destinations share Cupertino navigation and inset list geometry.
class IosPage extends StatelessWidget {
  const IosPage({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
    this.footer,
    this.onRefresh,
    this.controller,
    this.modal = false,
    this.onBack,
    this.horizontalPadding = 20,
  });
  final double horizontalPadding;
  final String title;
  final List<Widget> children;
  final Widget? trailing, footer;
  final Future<void> Function()? onRefresh;
  final ScrollController? controller;
  final bool modal;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        controller: controller,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverNavigationBar(
            transitionBetweenRoutes: false,
            heroTag: title,
            automaticallyImplyLeading: false,
            backgroundColor: scheme.surface.withValues(alpha: .92),
            border: null,
            largeTitle: Text(title),
            leading: modal
                ? null
                : NativeGlassButton(
                    label: 'Back',
                    symbol: 'chevron.left',
                    icon: CupertinoIcons.chevron_back,
                    onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                  ),
            trailing: modal
                ? NativeGlassButton(
                    label: 'Close',
                    symbol: 'xmark',
                    icon: CupertinoIcons.xmark,
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : trailing,
          ),
          if (onRefresh != null)
            CupertinoSliverRefreshControl(onRefresh: onRefresh),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              12,
              horizontalPadding,
              28 + MediaQuery.paddingOf(context).bottom,
            ),
            sliver: SliverList.list(children: children),
          ),
        ],
      ),
      bottomNavigationBar: footer,
    );
  }
}

class IosGroup extends StatelessWidget {
  const IosGroup({super.key, this.title, this.footer, required this.children});
  final String? title, footer;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: CupertinoListSection.insetGrouped(
        margin: EdgeInsets.zero,
        additionalDividerMargin: 0,
        dividerMargin: 16,
        backgroundColor: Colors.transparent,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
        ),
        header: title == null
            ? null
            : Text(
                title!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: scheme.onSurfaceVariant,
                ),
              ),
        footer: footer == null
            ? null
            : Text(
                footer!,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: scheme.onSurfaceVariant,
                ),
              ),
        children: children,
      ),
    );
  }
}

class IosRow extends StatelessWidget {
  const IosRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.color,
    this.value,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });
  final String title;
  final String? subtitle, value;
  final IconData? icon;
  final Color? color;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final large = MediaQuery.textScalerOf(context).scale(17) > 24;
    final tint = color ?? scheme.primary;
    return CupertinoListTile.notched(
      backgroundColor: scheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leadingSize: 30,
      leading: icon == null
          ? null
          : Container(
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(7),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 19, color: Colors.white),
            ),
      title: Text(
        title,
        maxLines: 4,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w400,
          color: destructive ? scheme.error : scheme.onSurface,
        ),
      ),
      subtitle: subtitle == null && (!large || value == null)
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                [
                  if (subtitle != null) subtitle!,
                  if (large && value != null) value!,
                ].join('\n'),
                maxLines: 8,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
      additionalInfo: value != null && !large
          ? Text(
              value!,
              style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
            )
          : null,
      trailing:
          trailing ?? (onTap != null ? const CupertinoListTileChevron() : null),
      onTap: onTap,
    );
  }
}

class IosNote extends StatelessWidget {
  const IosNote(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(fontSize: 13, height: 1.45),
    ),
  );
}
