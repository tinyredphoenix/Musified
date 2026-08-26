with open('lib/services/audio_service.dart', 'r') as f:
    content = f.read()

content = content.replace(
'''    _subscriptions.add(
      audioPlayer.processingStateStream.distinct().listen(
        _handleProcessingStateChange,
        onError: (error, stackTrace) {
          _logStreamError('Processing state stream error', error, stackTrace);
        },
      ),
    );

    _subscriptions.add(
      audioPlayer.positionStream
          .throttleTime(const Duration(milliseconds: 250))
          .listen(
            _handleNearEndSkip,
            onError: (error, stackTrace) {
              _logStreamError('Position stream error', error, stackTrace);
            },
          ),
    );

    _subscriptions.add(
      audioPlayer.playbackEventStream.listen(
        _handlePlaybackEvent,
        onError: (error, stackTrace) {
          _logStreamError('Playback event stream error', error, stackTrace);
        },
      ),
    );

    _subscriptions.add(
      audioPlayer.currentIndexStream.listen(
        _handleIndexChange,
        onError: (error, stackTrace) {
          _logStreamError('Index stream error', error, stackTrace);
        },
      ),
    );

    _subscriptions.add(
      audioPlayer.sequenceStateStream.listen(
        _handleSequenceStateChange,
        onError: (error, stackTrace) {
          _logStreamError('Sequence state stream error', error, stackTrace);
        },
      ),
    );''',
'''    _subscriptions
      ..add(
        audioPlayer.processingStateStream.distinct().listen(
          _handleProcessingStateChange,
          onError: (error, stackTrace) {
            _logStreamError('Processing state stream error', error, stackTrace);
          },
        ),
      )
      ..add(
        audioPlayer.positionStream
            .throttleTime(const Duration(milliseconds: 250))
            .listen(
              _handleNearEndSkip,
              onError: (error, stackTrace) {
                _logStreamError('Position stream error', error, stackTrace);
              },
            ),
      )
      ..add(
        audioPlayer.playbackEventStream.listen(
          _handlePlaybackEvent,
          onError: (error, stackTrace) {
            _logStreamError('Playback event stream error', error, stackTrace);
          },
        ),
      )
      ..add(
        audioPlayer.currentIndexStream.listen(
          _handleIndexChange,
          onError: (error, stackTrace) {
            _logStreamError('Index stream error', error, stackTrace);
          },
        ),
      )
      ..add(
        audioPlayer.sequenceStateStream.listen(
          _handleSequenceStateChange,
          onError: (error, stackTrace) {
            _logStreamError('Sequence state stream error', error, stackTrace);
          },
        ),
      );'''
)

content = content.replace('''
      _subscriptions.add(
        session.interruptionEventStream.listen((event) {
          if (event.begin) {
            switch (event.type) {
              case AudioInterruptionType.duck:
                if (session.androidAudioAttributes!.usage ==
                    AndroidAudioUsage.game) {
                  audioPlayer.setVolume(audioPlayer.volume / 2);
                }
                _playInterrupted = false;
              case AudioInterruptionType.pause:
              case AudioInterruptionType.unknown:
                if (audioPlayer.playing) {
                  unawaited(pause());
                  _playInterrupted = true;
                }
            }
          } else {
            switch (event.type) {
              case AudioInterruptionType.duck:
                audioPlayer.setVolume(min(1, audioPlayer.volume * 2));
                _playInterrupted = false;
              case AudioInterruptionType.pause:
                if (_playInterrupted) {
                  unawaited(play());
                }
                _playInterrupted = false;
              case AudioInterruptionType.unknown:
                _playInterrupted = false;
            }
          }
        }),
      );

      _subscriptions.add(
        session.becomingNoisyEventStream.listen((_) {
          unawaited(pause());
        }),
      );
''',
'''
      _subscriptions
        ..add(
          session.interruptionEventStream.listen((event) {
            if (event.begin) {
              switch (event.type) {
                case AudioInterruptionType.duck:
                  if (session.androidAudioAttributes!.usage ==
                      AndroidAudioUsage.game) {
                    audioPlayer.setVolume(audioPlayer.volume / 2);
                  }
                  _playInterrupted = false;
                case AudioInterruptionType.pause:
                case AudioInterruptionType.unknown:
                  if (audioPlayer.playing) {
                    unawaited(pause());
                    _playInterrupted = true;
                  }
              }
            } else {
              switch (event.type) {
                case AudioInterruptionType.duck:
                  audioPlayer.setVolume(min(1, audioPlayer.volume * 2));
                  _playInterrupted = false;
                case AudioInterruptionType.pause:
                  if (_playInterrupted) {
                    unawaited(play());
                  }
                  _playInterrupted = false;
                case AudioInterruptionType.unknown:
                  _playInterrupted = false;
              }
            }
          }),
        )
        ..add(
          session.becomingNoisyEventStream.listen((_) {
            unawaited(pause());
          }),
        );
'''
)

with open('lib/services/audio_service.dart', 'w') as f:
    f.write(content)


with open('lib/services/data_manager.dart', 'r') as f:
    dm = f.read()

dm = dm.replace('''  downloadsBox.put(key, value);
  downloadsBox.flush();''',
'''  downloadsBox
    ..put(key, value)
    ..flush();''')

with open('lib/services/data_manager.dart', 'w') as f:
    f.write(dm)


with open('lib/services/youtube_auth_service.dart', 'r') as f:
    ya = f.read()

ya = ya.replace('''      box.putAll(cookies);
      box.flush();''',
'''      box
        ..putAll(cookies)
        ..flush();''')

with open('lib/services/youtube_auth_service.dart', 'w') as f:
    f.write(ya)

