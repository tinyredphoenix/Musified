import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:musified/utilities/mediaitem.dart' show upgradeArtworkUrl;
import 'package:musified/widgets/no_artwork_cube.dart';
import 'package:musified/widgets/spinner.dart';

class SongArtworkWidget extends StatelessWidget {
  const SongArtworkWidget({
    super.key,
    required this.size,
    required this.metadata,
    this.borderRadius = 10.0,
    this.errorWidgetIconSize = 20.0,
  });
  final double size;
  final MediaItem metadata;
  final double borderRadius;
  final double errorWidgetIconSize;

  @override
  Widget build(BuildContext context) {
    // Decode target is the painted square (physical pixels), not full
    // remote resolution. YouTube ytimg art stays at hqdefault so the
    // square BoxFit.cover crop is closer to 1:1 than 16:9 maxresdefault.
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheDimension = (size * devicePixelRatio).round().clamp(64, 800);

    final rawArtUri = metadata.artUri?.toString();
    final isValidUri =
        rawArtUri != null && rawArtUri.isNotEmpty && rawArtUri != 'null';

    final fallbackUrl = metadata.extras?['highResImage']?.toString() ??
        metadata.extras?['image']?.toString() ??
        'https://i.ytimg.com/vi/${metadata.extras?['ytid'] ?? metadata.id}/hqdefault.jpg';

    final imageUrl = upgradeArtworkUrl(
      isValidUri ? rawArtUri : fallbackUrl,
      targetSize: cacheDimension,
    );

    return metadata.artUri?.scheme == 'file'
        ? SizedBox(
            width: size,
            height: size,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Image.file(
                key: ValueKey('${metadata.id}:${metadata.artUri}'),
                File(
                  metadata.artUri?.toFilePath() ??
                      metadata.extras?['artworkPath']?.toString() ??
                      metadata.extras?['artWorkPath']?.toString() ??
                      '',
                ),
                fit: BoxFit.cover,
                cacheWidth: cacheDimension,
                cacheHeight: cacheDimension,
              ),
            ),
          )
        : CachedNetworkImage(
            key: ValueKey('${metadata.id}:$imageUrl'),
            width: size,
            height: size,
            imageUrl: imageUrl,
            memCacheWidth: cacheDimension,
            memCacheHeight: cacheDimension,
            fadeInDuration: const Duration(milliseconds: 300),
            imageBuilder: (context, imageProvider) => ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Image(image: imageProvider, fit: BoxFit.cover),
            ),
            placeholder: (context, url) => const Spinner(),
            errorWidget: (context, url, error) =>
                NullArtworkWidget(iconSize: errorWidgetIconSize, size: size),
          );
  }
}
