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
    this.compact = false,
    this.onBack,
    this.horizontalPadding = 16,
  });
  final double horizontalPadding;
  final String title;
  final List<Widget> children;
  final Widget? trailing, footer;
  final Future<void> Function()? onRefresh;
  final ScrollController? controller;
  final bool modal, compact;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compactNavigation = modal || compact;
    final leading = modal
        ? null
        : NativeGlassButton(
            label: 'Back',
            symbol: 'chevron.left',
            icon: CupertinoIcons.chevron_back,
            size: 44,
            symbolSize: 18,
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          );
    return Scaffold(
      appBar: modal
          ? PreferredSize(
              preferredSize: const Size.fromHeight(76),
              child: _IosSheetHeader(title: title),
            )
          : compactNavigation
          ? PreferredSize(
              preferredSize: const Size.fromHeight(44),
              child: CupertinoNavigationBar(
                automaticallyImplyLeading: false,
                transitionBetweenRoutes: false,
                backgroundColor: scheme.surface,
                border: null,
                middle: Text(title),
                leading: leading,
                trailing: trailing,
              ),
            )
          : null,
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          CustomScrollView(
            controller: controller,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              if (!compactNavigation)
                CupertinoSliverNavigationBar(
                  transitionBetweenRoutes: false,
                  heroTag: title,
                  automaticallyImplyLeading: false,
                  backgroundColor: scheme.surface,
                  border: null,
                  largeTitle: Text(title),
                  leading: leading,
                  trailing: trailing,
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
          if (modal)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 14,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        scheme.surface,
                        scheme.surface.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: footer,
    );
  }
}

/// A quiet, fixed sheet header; the route continues to own drag gestures.
class _IosSheetHeader extends StatelessWidget {
  const _IosSheetHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: Column(
        children: [
          const SizedBox(height: 10),
          ExcludeSemantics(
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: .3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const SizedBox(width: 44),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.3,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ),
                NativeGlassButton(
                  label: 'Close',
                  symbol: 'xmark',
                  icon: CupertinoIcons.xmark,
                  size: 44,
                  symbolSize: 15,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class IosGroup extends StatelessWidget {
  const IosGroup({
    super.key,
    this.title,
    this.footer,
    required this.children,
    this.bottomSpacing = 28,
    this.dividerInset,
  });
  final double bottomSpacing;
  final double? dividerInset;
  final String? title, footer;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
              child: Text(
                title!,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          // Own the clip: CupertinoListSection applies a fixed corner radius
          // even when its decoration specifies a different radius.
          ClipRSuperellipse(
            borderRadius: BorderRadius.circular(28),
            child: ColoredBox(
              color: scheme.surfaceContainerLow,
              child: Column(
                children: [
                  for (var index = 0; index < children.length; index++) ...[
                    if (index > 0)
                      Padding(
                        padding: EdgeInsetsDirectional.only(
                          start:
                              dividerInset ??
                              (_hasIcon(children[index]) ? 54 : 14),
                          end: 16,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 1 / MediaQuery.devicePixelRatioOf(context),
                          child: ColoredBox(color: scheme.outlineVariant),
                        ),
                      ),
                    children[index],
                  ],
                ],
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
              child: Text(
                footer!,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static bool _hasIcon(Widget child) {
    if (child is IosRow) return child.icon != null;
    if (child is Semantics && child.child != null)
      return _hasIcon(child.child!);
    return false;
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
    this.leading,
    this.destructive = false,
    this.action = false,
    this.enabled = true,
  });
  final String title;
  final String? subtitle, value;
  final IconData? icon;
  final Color? color;
  final Widget? trailing;
  final Widget? leading;
  final VoidCallback? onTap;
  final bool destructive, action, enabled;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final large = MediaQuery.textScalerOf(context).scale(17) > 24;
    final tint = color ?? scheme.primary;
    return CupertinoListTile.notched(
      backgroundColor: scheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      leadingSize: leading == null ? 28 : 40,
      leading:
          leading ??
          (icon == null
              ? null
              : Container(
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 19, color: Colors.white),
                )),
      title: Text(
        title,
        maxLines: 4,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w400,
          color: !enabled
              ? scheme.onSurfaceVariant.withValues(alpha: .55)
              : destructive
              ? scheme.error
              : action
              ? scheme.primary
              : scheme.onSurface,
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
              style: TextStyle(fontSize: 17, color: scheme.onSurfaceVariant),
            )
          : null,
      trailing:
          trailing ?? (onTap != null ? const CupertinoListTileChevron() : null),
      onTap: enabled ? onTap : null,
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

/// A quiet category introduction, matching the grouped settings surfaces.
class IosSettingsIntro extends StatelessWidget {
  const IosSettingsIntro({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final Color color;
  final String title, description;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: ClipRSuperellipse(
        borderRadius: BorderRadius.circular(28),
        child: ColoredBox(
          color: scheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 30, color: Colors.white),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
