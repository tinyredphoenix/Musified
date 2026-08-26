import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:musify/main.dart' show logger, audioHandler;

typedef LrcLine = ({Duration time, String text});

class SyncedLyricsView extends StatefulWidget {

  const SyncedLyricsView({
    super.key,
    required this.metadata,
    required this.lyrics,
    required this.isActive,
  });
  final MediaItem metadata;
  final String lyrics;
  final bool isActive;

  @override
  State<SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends State<SyncedLyricsView> {
  List<LrcLine>? _parsedLyrics;
  StreamSubscription? _positionSub;
  final ScrollController _scrollController = ScrollController();
  int _currentIndex = -1;
  Duration _lastPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _parseLyrics();
    if (widget.isActive) {
      _startListening();
    }
  }

  @override
  void didUpdateWidget(covariant SyncedLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lyrics != oldWidget.lyrics) {
      _parseLyrics();
    }
    if (widget.isActive && !oldWidget.isActive) {
      _startListening();
    } else if (!widget.isActive && oldWidget.isActive) {
      _stopListening();
    }
  }

  void _parseLyrics() {
    try {
      final lines = widget.lyrics.split('\n');
      final lrcRegex = RegExp(r'^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$');
      final parsed = <LrcLine>[];

      for (final line in lines) {
        final match = lrcRegex.firstMatch(line.trim());
        if (match != null) {
          final minutes = int.parse(match.group(1)!);
          final seconds = int.parse(match.group(2)!);
          final millisStr = match.group(3)!;
          final millis = millisStr.length == 2 ? int.parse(millisStr) * 10 : int.parse(millisStr);
          final text = match.group(4)!.trim();
          
          if (text.isNotEmpty) {
            parsed.add((
              time: Duration(minutes: minutes, seconds: seconds, milliseconds: millis),
              text: text
            ));
          }
        }
      }

      if (parsed.isNotEmpty) {
        setState(() {
          _parsedLyrics = parsed;
        });
      } else {
        setState(() {
          _parsedLyrics = null;
        });
      }
    } catch (e) {
      logger.log('Error parsing LRC: $e');
      setState(() {
        _parsedLyrics = null;
      });
    }
  }

  void _startListening() {
    _positionSub?.cancel();
    
    // Immediately sync to the current position before the stream ticks
    final currentPos = audioHandler.playbackState.value.position;
    _syncToPosition(currentPos);
    
    // Use the player's positionStream directly — it fires on seek too
    _positionSub = audioHandler.audioPlayer.positionStream.listen(
      _syncToPosition,
    );
  }

  int _findIndexForPosition(Duration position) {
    if (_parsedLyrics == null) return -1;
    final lyrics = _parsedLyrics!;
    var idx = -1;
    for (var i = 0; i < lyrics.length; i++) {
      if (position.inMilliseconds + 200 >= lyrics[i].time.inMilliseconds) {
        idx = i;
      } else {
        break;
      }
    }
    return idx;
  }

  void _syncToPosition(Duration position) {
    if (!mounted || _parsedLyrics == null) return;

    _lastPosition = position;
    final newIndex = _findIndexForPosition(position);

    // Always update — even if the same index (seek may have jumped back
    // within the same line's time range).
    if (newIndex != _currentIndex) {
      if (mounted) {
        setState(() {
          _currentIndex = newIndex;
        });
        _scrollToCurrentLine();
      }
    }
  }

  void _stopListening() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  void _scrollToCurrentLine() {
    if (_scrollController.hasClients && _currentIndex >= 0) {
      final targetOffset = (_currentIndex * 72.0).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _stopListening();
    _scrollController.dispose();
    super.dispose();
  }

  /// Compute karaoke fill progress for the current line (0.0 → 1.0)
  double _currentLineFill() {
    if (_parsedLyrics == null || _currentIndex < 0) return 0;
    final lyrics = _parsedLyrics!;
    final lineStart = lyrics[_currentIndex].time;
    final lineEnd = _currentIndex + 1 < lyrics.length
        ? lyrics[_currentIndex + 1].time
        : lineStart + const Duration(seconds: 4);
    final lineDuration = lineEnd - lineStart;
    if (lineDuration.inMilliseconds <= 0) return 1;
    final elapsed = _lastPosition - lineStart;
    return (elapsed.inMilliseconds / lineDuration.inMilliseconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    if (_parsedLyrics == null) {
      return Material(
        type: MaterialType.transparency,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          physics: const BouncingScrollPhysics(),
          child: Text(
            widget.lyrics,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
              height: 1.6,
              decoration: TextDecoration.none,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: const TextStyle(decoration: TextDecoration.none),
        child: ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.symmetric(
            vertical: MediaQuery.sizeOf(context).height * 0.35, 
            horizontal: 24,
          ),
          physics: const BouncingScrollPhysics(),
          itemCount: _parsedLyrics!.length,
          itemBuilder: (context, index) {
            final line = _parsedLyrics![index];
            final isCurrent = index == _currentIndex;
            final isPast = index < _currentIndex;
            final fill = isCurrent ? _currentLineFill() : 0.0;

            // Karaoke style: current line uses a gradient shader to
            // show a "fill" effect from left to right as playback progresses.
            final baseStyle = TextStyle(
              fontFamily: '.SF Pro Display',
              fontSize: isCurrent ? 34 : 22,
              fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: isCurrent ? 0.0 : 0.5,
              color: isCurrent
                  ? Colors.white
                  : (isPast
                      ? Colors.white.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.15)),
              height: 1.25,
              decoration: TextDecoration.none,
            );

            Widget lineWidget;
            if (isCurrent) {
              // Karaoke fill: bright white fills from left, dim white on right
              lineWidget = ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) {
                  return LinearGradient(
                    colors: const [
                      Colors.white,
                      Colors.white,
                      Color(0x66FFFFFF), // dimmer unfilled portion
                      Color(0x66FFFFFF),
                    ],
                    stops: [0.0, fill, fill, 1.0],
                  ).createShader(bounds);
                },
                child: Text(
                  line.text,
                  style: baseStyle.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              );
            } else {
              lineWidget = Text(
                line.text,
                style: baseStyle,
                textAlign: TextAlign.center,
              );
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                audioHandler.seek(line.time);
                setState(() {
                  _currentIndex = index;
                });
                _scrollToCurrentLine();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  vertical: isCurrent ? 16 : 12,
                ),
                alignment: Alignment.center,
                child: AnimatedScale(
                  scale: isCurrent ? 1.0 : 0.85,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutBack,
                  child: lineWidget,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
