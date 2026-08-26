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
  Duration _currentPosition = Duration.zero;
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
    // Using audioHandler.positionStream since positionDataStream is not a standard audio_service stream usually, or we can use AudioService.position
    _positionSub = AudioService.position.listen((position) {
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _updateCurrentIndex();
      });
    });
  }

  void _stopListening() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  void _updateCurrentIndex() {
    if (_parsedLyrics == null) return;
    int newIndex = -1;
    for (int i = 0; i < _parsedLyrics!.length; i++) {
      if (_currentPosition >= _parsedLyrics![i].time) {
        newIndex = i;
      } else {
        break;
      }
    }
    
    if (newIndex != _currentIndex && newIndex >= 0) {
      _currentIndex = newIndex;
      _scrollToCurrentLine();
    }
  }

  void _scrollToCurrentLine() {
    if (_scrollController.hasClients && _currentIndex >= 0) {
      // Calculate approximate position
      final double position = _currentIndex * 60.0; // Rough height per item
      _scrollController.animateTo(
        position,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
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
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        physics: const BouncingScrollPhysics(),
        child: Text(
          widget.lyrics,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
            height: 1.6,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 100, horizontal: 24),
      physics: const BouncingScrollPhysics(),
      itemCount: _parsedLyrics!.length,
      itemBuilder: (context, index) {
        final line = _parsedLyrics![index];
        final isCurrent = index == _currentIndex;
        final isPast = index < _currentIndex;
        
        final color = isCurrent 
            ? Colors.white 
            : (isPast ? Colors.white.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.3));

        return GestureDetector(
          onTap: () {
            audioHandler.seek(line.time);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Text(
              line.text,
              style: TextStyle(
                fontSize: isCurrent ? 24 : 20,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                color: color,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}
