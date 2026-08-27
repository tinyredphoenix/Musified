import 'package:flutter/cupertino.dart';
import 'package:musified/theme/musified_style.dart';
import 'package:musified/widgets/playlist_artwork.dart';

class PlaylistCube extends StatelessWidget {
  const PlaylistCube(
    this.playlist, {
    super.key,
    this.playlistData,
    this.cubeIcon = CupertinoIcons.music_albums_fill,
    this.size = 220,
    this.borderRadius = 16,
    this.showTypeLabel = true,
  });

  final Map? playlistData;
  final Map playlist;
  final IconData cubeIcon;
  final double size;
  final double borderRadius;
  final bool showTypeLabel;

  static const double typeLabelOffset = 8;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        children: [
          PlaylistArtwork(
            playlistArtwork: playlist['image'],
            size: size,
            cubeIcon: cubeIcon,
          ),
          if (showTypeLabel && playlist['image'] != null)
            Positioned(
              top: typeLabelOffset,
              right: typeLabelOffset,
              child: _buildLabel(context),
            ),
        ],
      ),
    );
  }

  Widget _buildLabel(BuildContext context) {
    final isAlbum = playlist['isAlbum'] == true;
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        isAlbum ? 'Album' : 'Playlist',
        style: const TextStyle(
          fontFamily: MusifiedStyle.uiFont,
          color: CupertinoColors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}
