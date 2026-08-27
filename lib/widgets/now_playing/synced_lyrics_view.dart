import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musified/main.dart' show logger, audioHandler;
import 'package:musified/theme/musified_style.dart';
import 'package:musified/widgets/now_playing/full_page_lyrics_modal.dart';

typedef LrcLine = ({Duration time, String text});

class SyncedLyricsView extends StatefulWidget {
  const SyncedLyricsView({
    super.key,
    required this.metadata,
    required this.lyrics,
    required this.isActive,
    this.isFullScreen = false,
  });

  final MediaItem metadata;
  final String lyrics;
  final bool isActive;
  final bool isFullScreen;

  @override
  State<SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends State<SyncedLyricsView> {
  List<LrcLine>? _parsedLyrics;
  StreamSubscription? _positionSub;
  final ScrollController _scrollController = ScrollController();
  int _currentIndex = -1;
  Timer? _userScrollHoldTimer;
  bool _userIsScrolling = false;

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
          final millis = millisStr.length == 2
              ? int.parse(millisStr) * 10
              : int.parse(millisStr);
          final text = match.group(4)!.trim();

          if (text.isNotEmpty) {
            parsed.add((
              time: Duration(
                minutes: minutes,
                seconds: seconds,
                milliseconds: millis,
              ),
              text: text,
            ));
          }
        }
      }

      setState(() {
        _parsedLyrics = parsed.isNotEmpty ? parsed : null;
      });
    } catch (e) {
      logger.log('Error parsing LRC: $e');
      setState(() {
        _parsedLyrics = null;
      });
    }
  }

  void _startListening() {
    _positionSub?.cancel();
    // Read live position from audio player directly
    final currentPos = audioHandler.audioPlayer.position;
    _syncToPosition(currentPos);

    _positionSub = audioHandler.audioPlayer.positionStream.listen(_syncToPosition);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollToCurrentLine(instant: true);
      }
    });
  }

  void _stopListening() {
    _positionSub?.cancel();
    _positionSub = null;
    _userScrollHoldTimer?.cancel();
  }

  int _findIndexForPosition(Duration position) {
    if (_parsedLyrics == null) return -1;
    final lyrics = _parsedLyrics!;
    var idx = -1;
    for (var i = 0; i < lyrics.length; i++) {
      if (position.inMilliseconds + 250 >= lyrics[i].time.inMilliseconds) {
        idx = i;
      } else {
        break;
      }
    }
    return idx;
  }

  void _syncToPosition(Duration position) {
    if (!mounted || _parsedLyrics == null) return;
    final newIndex = _findIndexForPosition(position);

    if (newIndex != _currentIndex && newIndex >= 0) {
      if (mounted) {
        setState(() {
          _currentIndex = newIndex;
        });
        if (!_userIsScrolling) {
          _scrollToCurrentLine();
        }
      }
    }
  }

  void _scrollToCurrentLine({bool instant = false}) {
    if (_scrollController.hasClients && _currentIndex >= 0) {
      const lineHeight = 60.0;
      final viewportHeight = _scrollController.position.viewportDimension;
      final targetOffset = ((_currentIndex * lineHeight) - (viewportHeight / 2) + (lineHeight / 2)).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );

      if (instant) {
        _scrollController.jumpTo(targetOffset);
      } else {
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  void _onUserScroll() {
    _userIsScrolling = true;
    _userScrollHoldTimer?.cancel();
    _userScrollHoldTimer = Timer(const Duration(milliseconds: 4500), () {
      if (mounted) {
        _userIsScrolling = false;
        _scrollToCurrentLine();
      }
    });
  }

  @override
  void dispose() {
    _stopListening();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final activeTextColor = isDark ? CupertinoColors.white : CupertinoColors.black;
    final pastTextColor = isDark ? const Color(0x99FFFFFF) : const Color(0x99000000);
    final upcomingTextColor = isDark ? const Color(0x3DFFFFFF) : const Color(0x33000000);
    final glowColor = isDark ? const Color(0x80FFFFFF) : const Color(0x29000000);

    return Stack(
      children: [
        ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x00000000),
                Color(0xFF000000),
                Color(0xFF000000),
                Color(0x00000000),
              ],
              stops: [0.0, 0.12, 0.88, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: _parsedLyrics == null
              ? _buildPlainLyricsView(activeTextColor)
              : _buildSyncedLyricsView(
                  activeTextColor,
                  pastTextColor,
                  upcomingTextColor,
                  glowColor,
                ),
        ),
        if (!widget.isFullScreen)
          Positioned(
            top: 10,
            right: 12,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                showFullPageLyrics(context, widget.metadata);
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0x4DFFFFFF) : const Color(0x29000000),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.fullscreen,
                  color: activeTextColor,
                  size: 16,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlainLyricsView(Color textColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      physics: const BouncingScrollPhysics(),
      child: Text(
        widget.lyrics,
        style: TextStyle(
          fontFamily: MusifiedStyle.displayFont,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textColor,
          height: 1.6,
          decoration: TextDecoration.none,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSyncedLyricsView(
    Color activeTextColor,
    Color pastTextColor,
    Color upcomingTextColor,
    Color glowColor,
  ) {
    final lyrics = _parsedLyrics!;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is UserScrollNotification) {
          _onUserScroll();
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(
          vertical: screenHeight * 0.35,
          horizontal: 20,
        ),
        physics: const BouncingScrollPhysics(),
        itemCount: lyrics.length,
        itemBuilder: (context, index) {
          final line = lyrics[index];
          final isCurrent = index == _currentIndex;
          final isPast = index < _currentIndex;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              audioHandler.seek(line.time);
              setState(() {
                _currentIndex = index;
                _userIsScrolling = false;
              });
              _scrollToCurrentLine();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                vertical: isCurrent ? 14 : 9,
                horizontal: 8,
              ),
              alignment: Alignment.center,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontFamily: MusifiedStyle.displayFont,
                  fontSize: isCurrent ? (widget.isFullScreen ? 28 : 24) : (widget.isFullScreen ? 22 : 19),
                  fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: isCurrent ? -0.3 : -0.1,
                  color: isCurrent
                      ? activeTextColor
                      : (isPast ? pastTextColor : upcomingTextColor),
                  height: 1.28,
                  decoration: TextDecoration.none,
                  shadows: isCurrent
                      ? [
                          Shadow(
                            color: glowColor,
                            blurRadius: 16,
                          ),
                        ]
                      : null,
                ),
                textAlign: TextAlign.center,
                child: Text(line.text),
              ),
            ),
          );
        },
      ),
    );
  }
}
