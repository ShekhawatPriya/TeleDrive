import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Drive's recovery spaces reveal the whole page on tap. Retain Cupertino's
/// interactive edge-back gesture, while Android keeps its Material transition.
Page<void> recoveryPage({
  required BuildContext context,
  required LocalKey key,
  required Widget child,
}) => Theme.of(context).platform == TargetPlatform.iOS
    ? _RecoveryPage(key: key, child: child)
    : MaterialPage<void>(key: key, child: child);

class _RecoveryPage extends CupertinoPage<void> {
  const _RecoveryPage({required super.key, required super.child});

  @override
  Route<void> createRoute(BuildContext context) => _RecoveryRoute(this);
}

class _RecoveryRoute extends PageRoute<void>
    with CupertinoRouteTransitionMixin<void> {
  _RecoveryRoute(_RecoveryPage page) : super(settings: page);

  _RecoveryPage get _page => settings as _RecoveryPage;

  // A tap must not sweep loaded text in from outside the viewport. Cupertino's
  // gesture controller still drives the animation interactively on edge-back.
  @override
  Duration get transitionDuration => Duration.zero;
  @override
  DelegatedTransitionBuilder get delegatedTransition =>
      CupertinoPageTransition.delegatedTransition;
  @override
  Widget buildContent(BuildContext context) => _page.child;
  @override
  String? get title => _page.title;
  @override
  bool get maintainState => _page.maintainState;
}
