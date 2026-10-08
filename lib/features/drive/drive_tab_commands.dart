import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

class DriveTabCommands extends ChangeNotifier {
  int _selectRequests = 0;

  int get selectRequests => _selectRequests;

  void requestSelectMode() {
    _selectRequests += 1;
    notifyListeners();
  }
}

final driveTabCommandsProvider = ChangeNotifierProvider<DriveTabCommands>(
  (_) => DriveTabCommands(),
);

final photosTabCommandsProvider = ChangeNotifierProvider<DriveTabCommands>(
  (_) => DriveTabCommands(),
);

class SelectionModeState extends ChangeNotifier {
  bool _driveSelectMode = false;
  bool _photosSelectMode = false;
  bool _starredSelectMode = false;

  bool get driveSelectMode => _driveSelectMode;
  bool get photosSelectMode => _photosSelectMode;

  bool isSelectModeForTab(int tabIndex) {
    if (tabIndex == 0) return _driveSelectMode;
    if (tabIndex == 1) return _photosSelectMode;
    if (tabIndex == 2) return _starredSelectMode;
    return false;
  }

  void setDriveSelectMode(bool value) {
    if (_driveSelectMode == value) return;
    _driveSelectMode = value;
    notifyListeners();
  }

  bool get starredSelectMode => _starredSelectMode;
  void setStarredSelectMode(bool value) {
    if (_starredSelectMode == value) return;
    _starredSelectMode = value;
    notifyListeners();
  }

  void setPhotosSelectMode(bool value) {
    if (_photosSelectMode == value) return;
    _photosSelectMode = value;
    notifyListeners();
  }
}

final selectionModeStateProvider = ChangeNotifierProvider<SelectionModeState>(
  (_) => SelectionModeState(),
);

final starredTabCommandsProvider = ChangeNotifierProvider<DriveTabCommands>(
  (_) => DriveTabCommands(),
);
