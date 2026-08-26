with open('lib/services/audio_service.dart', 'r') as f:
    content = f.read()

replacement = '''
  void _handleNearEndSkip(Duration position) {
    if (_completionEventPending || sleepTimerExpired) return;
    if (_nativeHasSuccessor || _handlingNativeAdvance) return;
    if (!audioPlayer.playing) return;
    if (audioPlayer.processingState == ProcessingState.completed) return;
    
    // Default to the physical audio stream duration
    Duration? duration = audioPlayer.duration;
    
    // If the stream comes from YouTube but the original JioSaavn track is shorter,
    // enforce the original track duration so we don't play YouTube compilations/intros.
    final currentItem = mediaItem.value;
    if (currentItem != null && currentItem.duration != null && currentItem.duration!.inSeconds > 0) {
      final streamDuration = duration;
      final expectedDuration = currentItem.duration!;
      // If stream is significantly longer than expected (e.g. >5 seconds longer),
      // cap the playback length to the expected duration.
      if (streamDuration != null && streamDuration > expectedDuration + const Duration(seconds: 5)) {
        duration = expectedDuration;
      }
    }
    
    if (duration == null || duration < const Duration(seconds: 5)) return;
    final remaining = duration - position;
    if (remaining > const Duration(milliseconds: 450) || remaining.isNegative) {
      return;
    }
    logger.log(
      'Near end of track (${remaining.inMilliseconds}ms left of ${duration.inSeconds}s) — advancing',
    );
    _handleProcessingStateChange(ProcessingState.completed);
  }
'''

import re
content = re.sub(r'  void _handleNearEndSkip\(Duration position\) \{.*?\n  \}', replacement.strip('\n'), content, flags=re.DOTALL)

with open('lib/services/audio_service.dart', 'w') as f:
    f.write(content)
