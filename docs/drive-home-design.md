# Drive home refinement

## Design basis

The reference screenshot had three different visual languages: uncontained utility shortcuts, a large recent-file preview, and outlined folder cards with oversized counts. The update uses a consistent 20-point content inset, restrained surfaces, and a clearer order: search, spaces, recent files, folders, files.

Apple's [Get to know the new design system](https://developer.apple.com/videos/play/wwdc2025/356/) recommends expressing hierarchy through layout and grouping and keeping shapes harmonious. Here, the three spaces share one opaque rounded panel. Folder cards use the same surface and corner treatment, with names taking precedence over metadata. Glass remains a navigation/control treatment.

Apple's [Design intuitive search experiences](https://developer.apple.com/videos/play/wwdc2026/292/) describes recognizable search/clear controls, explicit exit controls during focus, and inline placement for searches scoped to a tab. We retain inline scoped search. Keyboard Search submits immediately and resigns focus while preserving results. Clear retains editing; a separate X cancels the query and exits search. See [current mobile interactions](mobile-ux-refinements.md).

Apple's [UI Design Dos and Don'ts](https://developer.apple.com/design/tips/) recommends touch targets of at least 44 points. Folder menus and the header menu retain that size. Spaces are whole-cell targets, not just tappable icons. At larger text sizes the spaces become vertically arranged rows; the existing folder list fallback remains available.

## Changes

- Archive, Locked, and Trash move above recents into one grouped panel. iOS uses a consistent Cupertino outline icon family and system-blue tint, separated by subtle dividers.
- Recent-file cards are shorter, with integrated thumbnail/metadata surfaces and a concise section heading.
- Folder cards use a 40-point iOS / 44-point Android folder icon, an 18-point iOS / 20-point Android two-line name, and a secondary count/size line. Normal heights are 156 and 176 points respectively, growing with text; large text uses rows. Shared, starred, optimistic, selection, and action behaviors remain supported.
- Section headings and content share alignment. Header spacing and menu size are tightened.
- Search separates into a field and independent X while editing. iOS uses UIKit glass on supported systems; Android uses opaque Material surfaces. Clear keeps editing active, keyboard Search preserves the query, and X clears/exits. Touch outside and navigation resign focus.
- Floating upload controls are hidden but remain mounted while the keyboard occupies the main shell. This preserves pending create-folder callbacks. Keyboard visibility is read above Scaffold because its resized body removes the inset.

## Verification

`flutter analyze --no-pub` and targeted widget suites cover search dismissal, the home layout, shared navigation, and folder editing. Light/dark fixture previews were rendered and visually inspected. Layout coverage includes 320-point screens, 200% text, and increased contrast.

Reproduce previews and tests:

```sh
flutter test --no-pub test/drive_search_dismissal_test.dart test/modernization_ui_test.dart test/navigation_shell_test.dart test/platform_folder_ui_test.dart --dart-define=WRITE_UI_PREVIEWS=true
```

Outputs: `build/modernization/full-drive-iOS-dark.png` and `full-drive-iOS-light.png`. Widget previews use portable fonts and fallback navigation; native glass, device safe areas, and physical-keyboard transitions require a device build to assess exactly.

## Selection and header refinements

iOS selection replaces the tab bar with a grouped native action toolbar and
overflow. The header keeps Select All, a centered selected count and a blue
checkmark; scoped search stays available. Select All includes only eligible loaded
files/folders in the visible scope. The profile avatar is visually larger than
the 34-point overflow surface, whose hit target remains 44 points. See
[iOS item menus and selection](ios-design.md#native-item-menus-and-selection).
