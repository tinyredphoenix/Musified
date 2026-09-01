import 'package:flutter/cupertino.dart';
import 'package:musified/theme/app_themes.dart';
import 'package:musified/theme/musified_style.dart';

class PlaylistHeader extends StatelessWidget {
  const PlaylistHeader(
    this.image,
    this.title, {
    super.key,
    this.songsLength,
    this.isAlbum,
    this.isArtist = false,
    this.showImage = true,
    this.showTitle = true,
    this.monthlyListeners,
    this.description,
  });

  final Widget image;
  final String title;
  final int? songsLength;
  final bool? isAlbum;
  final bool isArtist;
  final bool showImage;
  final bool showTitle;
  final String? monthlyListeners;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDarkMode(context);
    final titleColor = isDark ? CupertinoColors.white : CupertinoColors.black;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        children: [
          if (showImage) ...[
            if (isArtist)
              ClipOval(child: image)
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: image,
              ),
          ],
          if (showTitle) ...[
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontFamily: MusifiedStyle.displayFont,
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: titleColor,
                letterSpacing: -0.3,
                decoration: TextDecoration.none,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
          ] else
            const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (isArtist)
                _Chip(
                  icon: CupertinoIcons.person,
                  label: 'Artist',
                  isDark: isDark,
                )
              else if (isAlbum != null)
                _Chip(
                  icon: isAlbum!
                      ? CupertinoIcons.music_note_2
                      : CupertinoIcons.list_bullet,
                  label: isAlbum! ? 'Album' : 'Playlist',
                  isDark: isDark,
                ),
              if (songsLength != null)
                _Chip(
                  icon: CupertinoIcons.music_note_list,
                  label: '$songsLength songs',
                  isDark: isDark,
                ),
              if (monthlyListeners != null)
                _Chip(
                  icon: CupertinoIcons.headphones,
                  label: '$monthlyListeners listeners',
                  isDark: isDark,
                ),
            ],
          ),
          if (description != null && description!.trim().isNotEmpty)
            _Description(description!.trim(), isDark: isDark),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Description extends StatefulWidget {
  const _Description(this.text, {required this.isDark});

  final String text;
  final bool isDark;

  @override
  State<_Description> createState() => _DescriptionState();
}

class _DescriptionState extends State<_Description> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: GestureDetector(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        child: Text(
          widget.text,
          style: const TextStyle(
            fontFamily: MusifiedStyle.uiFont,
            color: CupertinoColors.systemGrey,
            fontSize: 13,
            height: 1.4,
            decoration: TextDecoration.none,
          ),
          textAlign: TextAlign.center,
          maxLines: _isExpanded ? null : 3,
          overflow: _isExpanded ? TextOverflow.clip : TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final chipBg = musifiedSecondarySurface(isDark);
    final chipText = isDark ? CupertinoColors.white : CupertinoColors.black;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFFFF2D55)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: MusifiedStyle.uiFont,
              color: chipText,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}
