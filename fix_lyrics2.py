with open('lib/widgets/now_playing/synced_lyrics_view.dart', 'r') as f:
    content = f.read()

content = content.replace(
    '_syncToPosition(AudioService.position.value);',
    '_syncToPosition(audioHandler.playbackState.value.position);'
)
content = content.replace(
    'Colors.white.withOpacity(0.4)',
    'Colors.white.withValues(alpha: 0.4)'
)
content = content.replace(
    'Colors.white.withOpacity(0.15)',
    'Colors.white.withValues(alpha: 0.15)'
)
content = content.replace(
    'Colors.white.withOpacity(0.3)',
    'Colors.white.withValues(alpha: 0.3)'
)

with open('lib/widgets/now_playing/synced_lyrics_view.dart', 'w') as f:
    f.write(content)
