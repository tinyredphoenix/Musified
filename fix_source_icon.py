with open('lib/widgets/now_playing/source_picker_sheet.dart', 'r') as f:
    content = f.read()

replacement = '''
IconData audioSourceIcon(MediaItem metadata) {
  final extras = metadata.extras ?? {};
  final ytid = extras['ytid']?.toString() ?? '';
  final isOffline = extras['isOffline'] == true || hasPlayableOfflineFile(ytid);
  if (isOffline) return CupertinoIcons.device_phone_portrait;
  if (extras['resolvedSource'] == 'jiosaavn') {
    return CupertinoIcons.music_note_2;
  }
  return CupertinoIcons.play_circle_fill;
}

Color audioSourceColor(MediaItem metadata) {
  final extras = metadata.extras ?? {};
  final ytid = extras['ytid']?.toString() ?? '';
  final isOffline = extras['isOffline'] == true || hasPlayableOfflineFile(ytid);
  if (isOffline) return CupertinoColors.systemGrey;
  if (extras['resolvedSource'] == 'jiosaavn') {
    return CupertinoColors.systemGreen;
  }
  return const Color(0xFFFF0033);
}
'''

import re
content = re.sub(
    r'IconData audioSourceIcon\(MediaItem metadata\).*$',
    replacement.strip('\n') + '\n',
    content,
    flags=re.DOTALL
)

with open('lib/widgets/now_playing/source_picker_sheet.dart', 'w') as f:
    f.write(content)
