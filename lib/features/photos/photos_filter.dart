import '../../core/utils/file_type_detector.dart';
import '../../models/drive_models.dart';

enum PhotosFilter { all, photos, videos }

extension PhotosFilterX on PhotosFilter {
  String get queryValue => switch (this) {
    PhotosFilter.all => 'all',
    PhotosFilter.photos => 'photos',
    PhotosFilter.videos => 'videos',
  };

  String get label => switch (this) {
    PhotosFilter.all => 'All',
    PhotosFilter.photos => 'Photos',
    PhotosFilter.videos => 'Videos',
  };

  bool accepts(DriveFile file) => switch (this) {
    PhotosFilter.all => isMediaFile(file),
    PhotosFilter.photos => isImageFile(file),
    PhotosFilter.videos => isVideoFile(file),
  };

  static PhotosFilter fromQuery(String? raw) {
    return switch (raw) {
      'videos' => PhotosFilter.videos,
      'photos' => PhotosFilter.photos,
      _ => PhotosFilter.all,
    };
  }
}
