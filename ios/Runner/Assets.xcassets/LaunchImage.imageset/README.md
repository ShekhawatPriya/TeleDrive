# Launch mark

This template PDF is generated from `assets/icon/launch_mark.svg` together
with the Android vector and synchronous Flutter painter.

From the repository root:

```sh
python scripts/generate_launch_mark.py
dart format lib/shared/launch_mark.dart
```

Do not replace this with a launcher-icon bitmap. The storyboard tints the PDF
using LaunchForeground and constrains it to 96 points.
