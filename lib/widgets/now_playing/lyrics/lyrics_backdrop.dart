import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:musified/utilities/mediaitem.dart' show upgradeArtworkUrl;
import 'package:musified/widgets/now_playing/lyrics/lyrics_theme.dart';

/// Full-screen blurred artwork atmosphere behind lyrics.
class LyricsBackdrop extends StatelessWidget {
  const LyricsBackdrop({
    super.key,
    required this.metadata,
    required this.theme,
  });

  final MediaItem metadata;
  final LyricsTheme theme;

  String _artUrl() {
    final extrasImage = metadata.extras?['highResImage']?.toString() ??
        metadata.extras?['image']?.toString();
    final ytid = metadata.extras?['ytid']?.toString() ?? metadata.id;
    final raw = metadata.artUri?.toString();
    final fallback = extrasImage ??
        'https://i.ytimg.com/vi/$ytid/hqdefault.jpg';
    final url = (raw != null && raw.isNotEmpty && raw != 'null') ? raw : fallback;
    return upgradeArtworkUrl(url, targetSize: 800);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Transform.scale(
          scale: 1.15,
          child: CachedNetworkImage(
            imageUrl: _artUrl(),
            fit: BoxFit.cover,
            placeholder: (_, __) => ColoredBox(color: theme.canvas),
            errorWidget: (_, __, ___) => ColoredBox(color: theme.canvas),
          ),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
          child: const ColoredBox(color: Color(0x00000000)),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: theme.isDark
                  ? [
                      const Color(0xCC000000),
                      const Color(0xE60A0A0E),
                      const Color(0xF00A0A0E),
                      const Color(0xFF000000),
                    ]
                  : [
                      const Color(0xDDF2F2F7),
                      const Color(0xF0F7F7FA),
                      const Color(0xF8F7F7FA),
                      const Color(0xFFF2F2F7),
                    ],
            ),
          ),
        ),
      ],
    );
  }
}
