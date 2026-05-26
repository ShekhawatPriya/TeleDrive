enum AppUpdateCheckReason { startup, resume, manual }

class AndroidUpdateManifest {
  const AndroidUpdateManifest({
    required this.versionName,
    required this.versionCode,
    required this.apkUrl,
    this.releaseNotes = const [],
    this.publishedAt,
    this.sha256,
    this.minimumSupportedVersionCode,
    this.mandatory = false,
  });

  final String versionName;
  final int versionCode;
  final String apkUrl;
  final List<String> releaseNotes;
  final DateTime? publishedAt;
  final String? sha256;
  final int? minimumSupportedVersionCode;
  final bool mandatory;

  static AndroidUpdateManifest? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final versionName = raw['versionName'];
    final versionCodeRaw = raw['versionCode'];
    final apkUrlRaw = raw['apkUrl'];

    final int? versionCode = switch (versionCodeRaw) {
      int v => v,
      String v => int.tryParse(v.trim()),
      _ => null,
    };
    if (versionCode == null) return null;

    if (apkUrlRaw is! String || apkUrlRaw.trim().isEmpty) return null;
    final parsedUri = Uri.tryParse(apkUrlRaw.trim());
    if (parsedUri == null || !parsedUri.hasScheme) return null;

    final notes = <String>[];
    final notesRaw = raw['releaseNotes'];
    if (notesRaw is List) {
      for (final entry in notesRaw) {
        if (entry is String && entry.trim().isNotEmpty) {
          notes.add(entry.trim());
        }
      }
    }

    DateTime? publishedAt;
    final publishedRaw = raw['publishedAt'];
    if (publishedRaw is String && publishedRaw.trim().isNotEmpty) {
      publishedAt = DateTime.tryParse(publishedRaw.trim())?.toUtc();
    }

    int? minimumSupported;
    final minRaw = raw['minimumSupportedVersionCode'];
    if (minRaw is int) {
      minimumSupported = minRaw;
    } else if (minRaw is String) {
      minimumSupported = int.tryParse(minRaw.trim());
    }

    final mandatoryRaw = raw['mandatory'];
    final mandatory = mandatoryRaw is bool
        ? mandatoryRaw
        : (mandatoryRaw is String &&
              {'1', 'true', 'yes'}.contains(mandatoryRaw.toLowerCase().trim()));

    final sha256Raw = raw['sha256'];
    final sha256 = (sha256Raw is String && sha256Raw.trim().isNotEmpty)
        ? sha256Raw.trim()
        : null;

    return AndroidUpdateManifest(
      versionName: versionName is String && versionName.trim().isNotEmpty
          ? versionName.trim()
          : versionCode.toString(),
      versionCode: versionCode,
      apkUrl: apkUrlRaw.trim(),
      releaseNotes: notes,
      publishedAt: publishedAt,
      sha256: sha256,
      minimumSupportedVersionCode: minimumSupported,
      mandatory: mandatory,
    );
  }
}

class AppUpdateManifest {
  const AppUpdateManifest({this.android});

  final AndroidUpdateManifest? android;

  static AppUpdateManifest? tryParse(Object? raw) {
    if (raw is! Map) return null;
    return AppUpdateManifest(
      android: AndroidUpdateManifest.tryParse(raw['android']),
    );
  }
}

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.installedVersionName,
    required this.installedVersionCode,
    required this.latestVersionName,
    required this.latestVersionCode,
    required this.apkUrl,
    required this.releaseNotes,
    required this.mandatory,
    this.publishedAt,
  });

  final String installedVersionName;
  final int installedVersionCode;
  final String latestVersionName;
  final int latestVersionCode;
  final String apkUrl;
  final List<String> releaseNotes;
  final bool mandatory;
  final DateTime? publishedAt;
}
