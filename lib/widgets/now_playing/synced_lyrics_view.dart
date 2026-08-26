import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:musify/main.dart' show logger, audioHandler;

typedef LrcLine = ({Duration time, String text});

class SyncedLyricsView extends StatefulWidget {
  final MediaItem metadata;
  final String lyrics;
  final bool isActive;

  const SyncedLyricsView({
    super.key,
    required this.metadata,
    required this.lyrics,
    required this.isActive,
  });

  @override
  State<SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends State<SyncedLyricsView> {
  List<LrcLine>? _parsedLyrics;
  StreamSubscription? _positionSub;
  final ScrollController _scrollController = ScrollController();
  int _currentIndex = -1;

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
      final List<LrcLine> parsed = [];

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
    _positionSub = AudioService.position.listen((position) {
      if (!mounted || _parsedLyrics == null) return;

      int newIndex = -1;
      final lyrics = _parsedLyrics;
      if (lyrics != null) {
        for (int i = 0; i < lyrics.length; i++) {
          if (position >= lyrics[i].time) {
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
    });
  }

  void _stopListening() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  void _scrollToCurrentLine() {
    if (_scrollController.hasClients && _currentIndex >= 0) {
      final double targetOffset = (_currentIndex * 58.0).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 350),
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
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 120, horizontal: 28),
        physics: const BouncingScrollPhysics(),
        itemCount: _parsedLyrics!.length,
        itemBuilder: (context, index) {
          final line = _parsedLyrics![index];
          final isCurrent = index == _currentIndex;
          final isPast = index < _currentIndex;

          return GestureDetector(
            onTap: () {
              audioHandler.seek(line.time);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              padding: EdgeInsets.symmetric(
                vertical: isCurrent ? 16.0 : 10.0,
              ),
              child: Text(
                line.text,
                style: TextStyle(
                  fontSize: isCurrent ? 26 : 21,
                  fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                  color: isCurrent
                      ? Colors.white
                      : (isPast
                          ? Colors.white.withValues(alpha: 0.55)
                          : Colors.white.withValues(alpha: 0.28)),
                  height: 1.35,
                  decoration: TextDecoration.none,
                  shadows: isCurrent
                      ? [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }
}
