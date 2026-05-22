import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../models/drive_models.dart';

enum SortField { name, kind, size, date }

enum LayoutMode { list, grid }

class ViewPreferencesController extends ChangeNotifier {
  LayoutMode layout = LayoutMode.list;
  SortField sort = SortField.name;
  bool ascending = true;

  void setLayout(LayoutMode mode) {
    if (layout == mode) return;
    layout = mode;
    notifyListeners();
  }

  void selectSort(SortField field) {
    if (sort == field) {
      ascending = !ascending;
    } else {
      sort = field;
      ascending = true;
    }
    notifyListeners();
  }

  String sortSubtitle(SortField field) {
    if (field != sort) return '';
    return switch (field) {
      SortField.name => ascending ? 'A to Z' : 'Z to A',
      SortField.kind => ascending ? 'A to Z' : 'Z to A',
      SortField.size =>
        ascending ? 'Smallest to Largest' : 'Largest to Smallest',
      SortField.date => ascending ? 'Oldest to Newest' : 'Newest to Oldest',
    };
  }
}

final viewPreferencesProvider =
    ChangeNotifierProvider<ViewPreferencesController>(
      (_) => ViewPreferencesController(),
    );

List<DriveFile> sortDriveFiles(
  List<DriveFile> input, {
  required SortField sort,
  required bool ascending,
}) {
  final list = [...input];
  list.sort((a, b) {
    final cmp = switch (sort) {
      SortField.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      SortField.kind => a.kind.name.compareTo(b.kind.name),
      SortField.size => a.size.compareTo(b.size),
      SortField.date => a.modifiedAt.compareTo(b.modifiedAt),
    };
    return ascending ? cmp : -cmp;
  });
  return list;
}

List<DriveFolder> sortDriveFolders(
  List<DriveFolder> input, {
  required bool ascending,
}) {
  final list = [...input]
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return ascending ? list : list.reversed.toList();
}
