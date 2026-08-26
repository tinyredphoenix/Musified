import re

with open('lib/widgets/now_playing/source_picker_sheet.dart', 'r') as f:
    content = f.read()

# Fix the audioSourceIcon logic
content = re.sub(
    r'IconData audioSourceIcon\(MediaItem metadata\) \{.*?\}',
    '''IconData audioSourceIcon(MediaItem metadata) {
  final extras = metadata.extras ?? {};
  if (extras['resolvedSource'] == 'jiosaavn') {
    return CupertinoIcons.music_note_2;
  }
  return CupertinoIcons.play_circle_fill;
}''',
    content,
    flags=re.DOTALL
)

# Fix the audioSourceColor logic
content = re.sub(
    r'Color audioSourceColor\(MediaItem metadata\) \{.*?\}',
    '''Color audioSourceColor(MediaItem metadata) {
  final extras = metadata.extras ?? {};
  if (extras['resolvedSource'] == 'jiosaavn') {
    return CupertinoColors.systemGreen;
  }
  return const Color(0xFFFF0033);
}''',
    content,
    flags=re.DOTALL
)

# Add decoration: TextDecoration.none to all Text widgets inside source_picker_sheet
content = content.replace(
    'fontSize: 17,\n                            fontWeight: FontWeight.w600,\n                            color: label,',
    'fontSize: 17,\n                            fontWeight: FontWeight.w600,\n                            color: label,\n                            decoration: TextDecoration.none,'
)
content = content.replace(
    'style: TextStyle(fontSize: 13, color: secondary)',
    'style: TextStyle(fontSize: 13, color: secondary, decoration: TextDecoration.none)'
)

with open('lib/widgets/now_playing/source_picker_sheet.dart', 'w') as f:
    f.write(content)
