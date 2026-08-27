import 'package:flutter/cupertino.dart';
import 'package:musified/theme/musified_style.dart';
import 'package:musified/widgets/playlist_cube.dart';
import 'package:musified/widgets/section_header.dart';

class ArtistShelf extends StatelessWidget {
  const ArtistShelf({
    super.key,
    required this.title,
    required this.icon,
    required this.items,
    required this.onTap,
    this.subtitleOf,
    this.cubeIcon = CupertinoIcons.music_note_2,
    this.circular = false,
  });

  final String title;
  final IconData icon;
  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic> item) onTap;
  final String Function(Map<String, dynamic> item)? subtitleOf;
  final IconData cubeIcon;
  final bool circular;

  static const _titleFontSize = 14.0;
  static const _subtitleFontSize = 12.0;
  static const _lineHeight = 1.3;
  static const _artworkGap = 8.0;
  static const _labelGap = 2.0;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final width = MediaQuery.sizeOf(context).width;
    final cubeSize = (width * 0.38).clamp(120.0, 180.0);

    return Column(
      children: [
        SectionHeader(title: title, icon: icon),
        SizedBox(
          height: cubeSize + _labelsHeight(context),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) =>
                _buildCube(context, items[index], cubeSize),
          ),
        ),
      ],
    );
  }

  double _labelsHeight(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    return _artworkGap +
        _labelGap +
        textScaler.scale(_titleFontSize) * _lineHeight * 2 +
        textScaler.scale(_subtitleFontSize) * _lineHeight;
  }

  Widget _buildCube(
    BuildContext context,
    Map<String, dynamic> item,
    double cubeSize,
  ) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final titleColor = isDark ? CupertinoColors.white : CupertinoColors.black;
    final subtitle = subtitleOf?.call(item);
    final artwork = PlaylistCube(
      item,
      size: cubeSize,
      cubeIcon: cubeIcon,
      showTypeLabel: false,
    );

    return SizedBox(
      width: cubeSize,
      child: GestureDetector(
        onTap: () => onTap(item),
        child: Column(
          crossAxisAlignment: circular
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (circular) ClipOval(child: artwork) else artwork,
            const SizedBox(height: _artworkGap),
            Text(
              item['title']?.toString() ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: circular ? TextAlign.center : TextAlign.start,
              style: TextStyle(
                fontFamily: MusifiedStyle.uiFont,
                fontWeight: FontWeight.w600,
                fontSize: _titleFontSize,
                height: _lineHeight,
                color: titleColor,
                decoration: TextDecoration.none,
              ),
            ),
            if (subtitle != null && subtitle.isNotEmpty) ...[
              const SizedBox(height: _labelGap),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: MusifiedStyle.uiFont,
                  fontWeight: FontWeight.w500,
                  fontSize: _subtitleFontSize,
                  height: _lineHeight,
                  color: CupertinoColors.systemGrey,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
