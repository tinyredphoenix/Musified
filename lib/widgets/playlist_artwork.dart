import 'package:flutter/cupertino.dart';
import 'package:musified/utilities/artwork_provider.dart';
import 'package:musified/widgets/no_artwork_cube.dart';

class PlaylistArtwork extends StatelessWidget {
  const PlaylistArtwork({
    super.key,
    required this.playlistArtwork,
    this.playlistTitle,
    this.cubeIcon = CupertinoIcons.list_bullet,
    this.iconSize,
    this.size = 220,
  });

  final String? playlistArtwork;
  final String? playlistTitle;
  final IconData cubeIcon;
  final double? iconSize;
  final double size;

  Widget _nullArtwork() => NullArtworkWidget(
    icon: cubeIcon,
    iconSize: iconSize ?? (size * 0.3), // Default to 30% of container size
    size: size,
    title: playlistTitle,
  );

  @override
  Widget build(BuildContext context) {
    final image = playlistArtwork;
    if (image == null) return _nullArtwork();

    try {
      final provider = ArtworkProvider.get(image);
      return SizedBox(
        width: size,
        height: size,
        child: Image(
          image: provider,
          height: size,
          width: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _nullArtwork(),
        ),
      );
    } catch (_) {
      return _nullArtwork();
    }
  }
}
