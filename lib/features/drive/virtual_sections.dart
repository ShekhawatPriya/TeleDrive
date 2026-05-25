import '../../models/drive_models.dart';

const Set<String> kVirtualSectionFolderNames = {'Archive', 'Locked'};

bool isVirtualSectionFolder(DriveFolder folder) =>
    folder.parentId == null &&
    kVirtualSectionFolderNames.contains(folder.name.trim());

List<DriveFolder> hideVirtualSectionFolders(List<DriveFolder> folders) {
  var hasVirtual = false;
  for (final f in folders) {
    if (isVirtualSectionFolder(f)) {
      hasVirtual = true;
      break;
    }
  }
  if (!hasVirtual) return folders;
  return folders.where((f) => !isVirtualSectionFolder(f)).toList();
}
