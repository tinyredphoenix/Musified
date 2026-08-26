with open('lib/widgets/now_playing/source_picker_sheet.dart', 'r') as f:
    content = f.read()

# Let's cleanly replace the two functions at the bottom.
import re
content = re.sub(
    r'IconData audioSourceIcon\(MediaItem metadata\).*$',
    '''IconData audioSourceIcon(MediaItem metadata) {
  final extras = metadata.extras ?? {};
  if (extras['resolvedSource'] == 'jiosaavn') {
    return CupertinoIcons.music_note_2;
  }
  return CupertinoIcons.play_circle_fill;
}

Color audioSourceColor(MediaItem metadata) {
  final extras = metadata.extras ?? {};
  if (extras['resolvedSource'] == 'jiosaavn') {
    return CupertinoColors.systemGreen;
  }
  return const Color(0xFFFF0033);
}
''',
    content,
    flags=re.DOTALL
)

with open('lib/widgets/now_playing/source_picker_sheet.dart', 'w') as f:
    f.write(content)
