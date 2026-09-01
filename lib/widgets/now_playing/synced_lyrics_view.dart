import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:musified/main.dart' show logger, audioHandler;
import 'package:musified/theme/app_themes.dart';
import 'package:musified/widgets/now_playing/full_page_lyrics_modal.dart';
import 'package:musified/widgets/now_playing/lyrics/compact_lyrics_panel.dart';
import 'package:musified/widgets/now_playing/lyrics/lrc_parser.dart';
import 'package:musified/widgets/now_playing/lyrics/lyrics_stage.dart';
import 'package:musified/widgets/now_playing/lyrics/lyrics_theme.dart';
import 'package:musified/widgets/now_playing/lyrics/plain_lyrics_reader.dart';

/// Live synced lyrics — compact spotlight panel or full-screen stage.
class SyncedLyricsView extends StatefulWidget {
  const SyncedLyricsView({
    super.key,
    required this.metadata,
    required this.lyrics,
    required this.isActive,
    this.isFullScreen = false,
    this.isCompact = false,
  });

  final MediaItem metadata;
  final String lyrics;
  final bool isActive;
  final bool isFullScreen;
  final bool isCompact;

  @override
  State<SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends State<SyncedLyricsView> {
  List<LrcLine>? _parsedLyrics;
  List<GlobalKey> _lineKeys = [];
  StreamSubscription? _positionSub;
  final ScrollController _scrollController = ScrollController();
  int _currentIndex = -1;
  double _lineProgress = 0;
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToCurrentLine(instant: true);
      });
    } else if (!widget.isActive && oldWidget.isActive) {
      _stopListening();
    }
  }

  void _parseLyrics() {
    try {
      final parsed = parseLrcLyrics(widget.lyrics);
      setState(() {
        _parsedLyrics = parsed.isNotEmpty ? parsed : null;
        _lineKeys = [for (var i = 0; i < parsed.length; i++) GlobalKey()];
        _currentIndex = -1;
        _lineProgress = 0;
      });
      if (widget.isActive && parsed.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToCurrentLine(instant: true);
        });
      }
    } catch (e) {
      logger.log('Error parsing LRC: $e');
      setState(() {
        _parsedLyrics = null;
        _lineKeys = [];
      });
    }
  }

  void _startListening() {
    _positionSub?.cancel();
    _syncToPosition(audioHandler.audioPlayer.position);
    _positionSub =
        audioHandler.audioPlayer.positionStream.listen(_syncToPosition);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToCurrentLine(instant: true);
    });
  }

  void _stopListening() {
    _positionSub?.cancel();
    _positionSub = null;
    _userScrollHoldTimer?.cancel();
  }

  int _findIndexForPosition(Duration position) {
    final lyrics = _parsedLyrics;
    if (lyrics == null) return -1;
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

  double _progressForPosition(Duration position) {
    final lyrics = _parsedLyrics;
    if (lyrics == null || _currentIndex < 0) return 0;
    final songDuration = widget.metadata.duration ?? Duration.zero;
    final start = lyrics[_currentIndex].time;
    final end = lineEndTime(lyrics, _currentIndex, songDuration) ??
        start + const Duration(seconds: 8);
    final span = end - start;
    if (span.inMilliseconds <= 0) return 0;
    final elapsed = position - start;
    return elapsed.inMilliseconds / span.inMilliseconds;
  }

  void _syncToPosition(Duration position) {
    if (!mounted || _parsedLyrics == null) return;

    final newIndex = _findIndexForPosition(position);
    final newProgress = _progressForPosition(position);
    final indexChanged = newIndex != _currentIndex;
    final progressChanged =
        (newProgress - _lineProgress).abs() > 0.02 || newProgress == 0;

    if (indexChanged || progressChanged) {
      setState(() {
        if (indexChanged) _currentIndex = newIndex;
        _lineProgress = newProgress.clamp(0.0, 1.0);
      });
      if (indexChanged && !_userIsScrolling && !widget.isCompact) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_userIsScrolling) _scrollToCurrentLine();
        });
      }
    }
  }

  void _scrollToCurrentLine({bool instant = false}) {
    if (widget.isCompact) return;
    if (_currentIndex < 0 || _currentIndex >= _lineKeys.length) return;

    final duration =
        instant ? Duration.zero : const Duration(milliseconds: 420);
    final ctx = _lineKeys[_currentIndex].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.45,
        duration: duration,
        curve: Curves.easeOutCubic,
      );
      return;
    }

    if (!_scrollController.hasClients) return;
    const lineHeight = 58.0;
    final vp = _scrollController.position.viewportDimension;
    final paddingTop = vp * 0.34;
    final targetOffset = (paddingTop + _currentIndex * lineHeight - vp * 0.45)
        .clamp(0.0, _scrollController.position.maxScrollExtent);

    if (instant) {
      _scrollController.jumpTo(targetOffset);
    } else {
      _scrollController.animateTo(
        targetOffset,
        duration: duration,
        curve: Curves.easeOutCubic,
      );
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

  void _seek(Duration time) {
    audioHandler.seek(time);
    setState(() {
      _currentIndex = _findIndexForPosition(time);
      _userIsScrolling = false;
    });
    if (!widget.isCompact) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToCurrentLine();
      });
    }
  }

  void _openFullScreen() {
    showFullPageLyrics(context, widget.metadata);
  }

  @override
  void dispose() {
    _stopListening();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDarkMode(context);
    final theme = LyricsTheme(
      isDark: isDark,
      accent: CupertinoTheme.of(context).primaryColor,
    );

    if (_parsedLyrics == null) {
      return PlainLyricsReader(
        text: widget.lyrics,
        theme: theme,
        layout: widget.isCompact
            ? LyricsLayout.compact
            : LyricsLayout.stage,
        onExpand: widget.isCompact ? _openFullScreen : null,
      );
    }

    if (widget.isCompact) {
      return CompactLyricsPanel(
        lines: _parsedLyrics!,
        currentIndex: _currentIndex,
        lineProgress: _lineProgress,
        theme: theme,
        onSeek: _seek,
        onExpand: _openFullScreen,
      );
    }

    return LyricsStage(
      lines: _parsedLyrics!,
      currentIndex: _currentIndex,
      theme: theme,
      scrollController: _scrollController,
      lineKeys: _lineKeys,
      onUserScroll: _onUserScroll,
      onSeek: _seek,
      lineProgress: _lineProgress,
    );
  }
}
