import '../../core/utils/file_type_detector.dart';
import '../../models/drive_models.dart';

enum PhotosFilter { photos, videos }

extension PhotosFilterX on PhotosFilter {
  String get queryValue => switch (this) {
    PhotosFilter.photos => 'photos',
    PhotosFilter.videos => 'videos',
  };

  String get label => switch (this) {
    PhotosFilter.photos => 'Photos',
    PhotosFilter.videos => 'Videos',
  };

  bool accepts(DriveFile file) => switch (this) {
    PhotosFilter.photos => isImageFile(file),
    PhotosFilter.videos => isVideoFile(file),
  };

  static PhotosFilter fromQuery(String? raw) {
    return switch (raw) {
      'videos' => PhotosFilter.videos,
      _ => PhotosFilter.photos,
    };
  }
}
