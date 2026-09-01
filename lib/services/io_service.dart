import 'dart:io';

import 'package:musified/utilities/app_utils.dart';

String applicationDirPath = '';

class FilePaths {
  // File extensions
  static const String audioExtension = '.m4a';
  static const String artworkExtension = '.jpg';

  // Directory names
  static const String tracksDir = 'tracks';
  static const String artworksDir = 'artworks';

  // Get full paths for various file types
  static String getAudioPath(String songId) {
    final safeId = sanitizeStorageSongId(songId);
    return '$applicationDirPath/$tracksDir/$safeId$audioExtension';
  }

  static String getArtworkPath(String songId) {
    final safeId = sanitizeStorageSongId(songId);
    return '$applicationDirPath/$artworksDir/$safeId$artworkExtension';
  }

  // Ensure directories exist
  static Future<void> ensureDirectoriesExist() async {
    final tracksDirectory = Directory('$applicationDirPath/$tracksDir');
    final artworksDirectory = Directory('$applicationDirPath/$artworksDir');

    if (!await tracksDirectory.exists()) {
      await tracksDirectory.create(recursive: true);
    }

    if (!await artworksDirectory.exists()) {
      await artworksDirectory.create(recursive: true);
    }
  }
}
