with open('lib/widgets/now_playing/synced_lyrics_view.dart', 'r') as f:
    content = f.read()

replacement = '''
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                audioHandler.seek(line.time);
                setState(() {
                  _currentIndex = index;
                });
                _scrollToCurrentLine();
              },
'''
content = content.replace(
    'return GestureDetector(\n              behavior: HitTestBehavior.opaque,\n              onTap: () {\n                audioHandler.seek(line.time);\n              },',
    replacement.strip('\n')
)

with open('lib/widgets/now_playing/synced_lyrics_view.dart', 'w') as f:
    f.write(content)
