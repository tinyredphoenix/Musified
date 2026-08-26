with open('lib/widgets/now_playing/synced_lyrics_view.dart', 'r') as f:
    content = f.read()

replacement = '''
  void _startListening() {
    _positionSub?.cancel();
    
    // Immediately sync to the current position before the stream ticks
    if (audioHandler.playbackState.value.playing) {
      _syncToPosition(AudioService.position.value);
    }
    
    _positionSub = AudioService.position.listen((position) {
      _syncToPosition(position);
    });
  }

  void _syncToPosition(Duration position) {
    if (!mounted || _parsedLyrics == null) return;

    int newIndex = -1;
    final lyrics = _parsedLyrics;
    if (lyrics != null) {
      for (int i = 0; i < lyrics.length; i++) {
        // Look ahead slightly for karaoke effect (lead by 200ms)
        if (position.inMilliseconds + 200 >= lyrics[i].time.inMilliseconds) {
          newIndex = i;
        } else {
          break;
        }
      }
    }

    if (newIndex != _currentIndex && newIndex >= 0) {
      if (mounted) {
        setState(() {
          _currentIndex = newIndex;
        });
        _scrollToCurrentLine();
      }
    }
  }
'''

import re
content = re.sub(r'  void _startListening\(\) \{.*?\n  \}', replacement.strip('\n'), content, flags=re.DOTALL)

with open('lib/widgets/now_playing/synced_lyrics_view.dart', 'w') as f:
    f.write(content)
