import 'package:flutter/material.dart';

/// Material 3 corner radii.
///
/// Token names match the M3 shape scale:
/// - [xs] 4 dp  — snackbar, chip
/// - [sm] 8 dp  — chip selected, switch track
/// - [md] 12 dp — card, small FAB
/// - [lg] 16 dp — text field corner, regular FAB, extended FAB
/// - [xl] 28 dp — dialog, large modal
/// - [sheet] 28 dp — bottom sheet top corners (alias of [xl])
/// - [pill] stadium / fully rounded — buttons, FilterChip, NavigationBar pill
class AppRadii {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 28.0;
  static const sheet = 28.0;
  static const pill = 9999.0;

  static BorderRadius get xsR => BorderRadius.circular(xs);
  static BorderRadius get smR => BorderRadius.circular(sm);
  static BorderRadius get mdR => BorderRadius.circular(md);
  static BorderRadius get lgR => BorderRadius.circular(lg);
  static BorderRadius get xlR => BorderRadius.circular(xl);
  static const sheetTop = BorderRadius.vertical(top: Radius.circular(sheet));
}
