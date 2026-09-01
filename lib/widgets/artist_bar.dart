import 'package:flutter/cupertino.dart';
import 'package:musified/services/artist_service.dart';
import 'package:musified/theme/app_themes.dart';
import 'package:musified/theme/musified_style.dart';
import 'package:musified/utilities/artwork_provider.dart';

class ArtistBar extends StatelessWidget {
  const ArtistBar({
    super.key,
    required this.artist,
    required this.onTap,
    this.borderRadius = BorderRadius.zero,
  });

  final Map artist;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDarkMode(context);
    final title = normalizeArtistDisplayTitle(
      artist['title']?.toString() ?? 'Artist',
    );
    final image = normalizeArtistThumbnailUrl(artist['image']?.toString());
    final cardBg = musifiedElevatedSurface(isDark);
    final titleColor = isDark ? CupertinoColors.white : CupertinoColors.black;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: borderRadius == BorderRadius.zero ? BorderRadius.circular(12) : borderRadius,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          child: Row(
            children: [
              _ArtistArtwork(image: image, isDark: isDark),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: MusifiedStyle.uiFont,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: titleColor,
                        decoration: TextDecoration.none,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Artist',
                      style: TextStyle(
                        fontFamily: MusifiedStyle.uiFont,
                        color: CupertinoColors.systemGrey,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_forward,
                color: CupertinoColors.systemGrey,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtistArtwork extends StatelessWidget {
  const _ArtistArtwork({required this.image, required this.isDark});

  final String? image;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (image != null && image!.isNotEmpty) {
      return ClipOval(
        child: Image(
          image: ArtworkProvider.get(image!),
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }

    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: musifiedSecondarySurface(isDark),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        CupertinoIcons.person_fill,
        size: 26,
        color: Color(0xFFFF2D55),
      ),
    );
  }
}
