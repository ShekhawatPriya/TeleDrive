# Android Settings and item status

## Direction and evidence

The Android Settings overview and its server, uploads, backup, cache, privacy and
notification pages use a Material 3 Expressive direction. This supersedes older
Android settings-card styling in the general design workflow. iOS keeps its
Cupertino pages and controls. Routes, settings persistence and account contracts
are unchanged.

Primary sources reviewed September 18, 2026:

- [Google Design research](https://design.google/library/expressive-material-design-google-research):
  Google describes 46 studies with more than 18,000 participants, including
  eye tracking, usability testing and preference research. Its finding is that
  intentional emphasis and containment can improve recognition and navigation.
  This is Google's published research summary, not an independent trial of
  TeleDrive. Its reported speed improvements cannot be claimed for this app.
- [Material team roundtable](https://storage.googleapis.com/gd-misc/DesignNotes_Transcript_M3-Expressive.pdf):
  researcher Michael Gilbert, creative director Andy Stewart and product manager
  Aneesha Kommineni discuss expression as a spectrum, including quiet interfaces,
  and adaptation to product needs. We retain a calm file-management experience.
- [Android/Pixel Expressive introduction](https://blog.google/products-and-platforms/platforms/android/material-3-expressive-android-wearos-launch/):
  the direction combines shape, color, typography and responsive interaction.
  Pixel is a platform reference; these Flutter screens do not embed Pixel Settings.
- [Android mobile color guidance](https://developer.android.com/design/ui/mobile/guides/styles/color):
  semantic container/on-container pairs maintain hierarchy and contrast across
  light and dark themes. We reuse the brand seed and existing ColorScheme roles.
- [Android accessibility](https://developer.android.com/design/ui/mobile/guides/foundations/accessibility):
  generous targets, readable contrast, scalable content and non-color state cues
  are design requirements, not optional finishing touches.
- [Android 17](https://developer.android.com/about/versions/17):
  the platform emphasizes adaptive experiences. OS compatibility requirements
  are separate from visual styling; this work does not change target SDK or
  claim Android 17 device certification.

The Material lists website was also consulted, but its JavaScript-only article
was not readable by the research tool. No unpublished Pixel geometry is assumed.

## Why the previous presentation felt muted

The supplied screenshots and source showed several unrelated desaturated category
accents, translucent icon backgrounds, low-emphasis borders around every group,
centered compact titles and a second large boxed introduction on detail pages.
These were application styling choices, not requirements of an Android version.
The diagnosis is a design judgment informed by the sources above.

## Current contract

- Use large, leading, collapsing Material titles and existing back navigation.
- Group related rows with 24-point outer corners, 4-point inner corners and
  four-point gaps. Use opaque surfaceContainer fills; outline only in high contrast.
- Use primaryContainer/onPrimaryContainer for category icons, primary section
  labels and full-strength secondary text. Keep the shared brand palette.
- Give detail introductions open space instead of another nested card.
- Keep Material ink feedback and real switches. Enabled switches include a check;
  a merged semantic node announces each label and toggle state.
- Appearance uses full-width mutually exclusive Light/Dark/System choices.
  This replaces miniature decorative previews that overflowed at narrow widths.
- Numeric backup controls have their own line and 48-point targets. Dropdowns
  use available width and server action buttons wrap. Content scrolls at 200% text.
- Connection status is real resolver state, with contrast-aware semantic colors.
  No invented security or activity claims are introduced.

## Country and file state

The collapsed login country control renders Country.flag, matching the picker,
while the selected name and dial code continue to drive the unchanged login flow.
The Android/iOS system emoji font supplies the flag glyph. Portable Windows test
fonts do not prove native emoji appearance.

Android files and folders use ItemStatusIndicators: distinct star/link symbols in
one opaque tonal marker with a semantic label. Folder cards reserve space below
the name, rather than stacking symbols over a shared-folder icon. Android folder
cards are 176 points tall at normal text; iOS retains its existing geometry.
File cards, recent previews and photo grids share the marker; photo markers stay
above video duration labels. List rows keep the existing Star/Unstar action and
omit a duplicate passive star. On narrow or enlarged-text rows, actions move
below the label so filenames have usable space. Selection, overflow menus,
optimistic updates and sharing callbacks retain their existing handlers.

## Repeatable checks

```sh
flutter analyze --no-pub
flutter test --no-pub
flutter test --no-pub test/login_design_test.dart test/modernization_ui_test.dart test/navigation_shell_test.dart test/platform_folder_ui_test.dart --dart-define=WRITE_UI_PREVIEWS=true
dart run scripts/build_design_gallery.dart
```

Populated Android fixtures cover the overview and six detail pages, both themes,
320-point widths, 200% text, high contrast and reduced motion. Interaction checks
exercise country choice, toggle callbacks and non-overlapping folder markers.
The gallery under build/modernization is fixture evidence. Native flag glyphs,
TalkBack, physical-device scrolling and UIKit appearance need device validation;
no native bridge or transfer behavior changed.

Verification for this change: analyzer clean; full Flutter suite passed 372 tests.
The populated preview suites and final Android fixture pass completed successfully.
Light/dark and enlarged-text renders were visually inspected. Native compilation
and physical-device interactions were not performed in this change.
