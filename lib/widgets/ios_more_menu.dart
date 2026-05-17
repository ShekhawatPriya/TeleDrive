/// Barrel for the iOS-style three-dot menu used across drive screens.
///
/// Existing imports of `widgets/ios_more_menu.dart` continue to resolve
/// without changes.  The implementation lives in [widgets/ios_menu] and is
/// split into models, the anchor button, and the overlay route.
library;

export 'ios_menu/ios_menu_models.dart';
export 'ios_menu/ios_more_button.dart' show IosMoreButton, showIosMoreMenu;
