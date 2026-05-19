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
