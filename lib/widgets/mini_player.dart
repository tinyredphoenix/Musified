import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musified/main.dart';
import 'package:musified/models/full_player_state.dart';
import 'package:musified/screens/now_playing_page.dart';
import 'package:musified/theme/musified_style.dart';

/// Clean, high-performance iOS floating mini player.
class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  static const double playerHeight = 64;

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _openNowPlaying() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, _) => const NowPlayingPage(),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final tween = Tween(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeInOutCubic));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isAudioHandlerInitialized) return const SizedBox.shrink();

    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, mediaSnapshot) {
        final metadata = mediaSnapshot.data;
        if (metadata == null) return const SizedBox.shrink();

        return StreamBuilder<FullPlayerState>(
          stream: audioHandler.fullPlayerStateStream,
          builder: (context, stateSnapshot) {
            final state = stateSnapshot.data;
            if (state == null) return const SizedBox.shrink();

            final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
            final bg = isDark ? const Color(0xE61C1C1E) : const Color(0xE6FFFFFF);
            final border = isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000);
            final titleColor = isDark ? CupertinoColors.white : CupertinoColors.black;
            final artistColor = CupertinoColors.systemGrey;

            final metadataDuration = metadata.duration;
            final totalDuration = (metadataDuration != null && metadataDuration > Duration.zero)
                ? metadataDuration
                : (state.position.duration > Duration.zero
                    ? state.position.duration
                    : Duration.zero);
            final progress = totalDuration.inMilliseconds == 0
                ? 0.0
                : (state.position.position.inMilliseconds / totalDuration.inMilliseconds)
                    .clamp(0.0, 1.0);

            final ytid = metadata.extras?['ytid']?.toString() ?? metadata.id;
            final imageUrl = metadata.artUri?.toString() ??
                metadata.extras?['lowResImage']?.toString() ??
                metadata.extras?['image']?.toString() ??
                'https://i.ytimg.com/vi/$ytid/hqdefault.jpg';

            final isPlaying = state.playbackState.playing;
            final isLoading = state.playbackState.processingState == AudioProcessingState.loading ||
                state.playbackState.processingState == AudioProcessingState.buffering;
            final hasNext = audioHandler.hasNext;

            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) => Transform.scale(
                  scale: _scaleAnimation.value,
                  child: GestureDetector(
                    onTapDown: (_) => _pressController.forward(),
                    onTapUp: (_) => _pressController.reverse(),
                    onTapCancel: () => _pressController.reverse(),
                    onTap: _openNowPlaying,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          height: MiniPlayer.playerHeight,
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: border, width: 0.5),
                          ),
                          child: Stack(
                            children: [
                              // Progress line
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 2,
                                  color: isDark ? const Color(0x22FFFFFF) : const Color(0x11000000),
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: progress,
                                    child: Container(
                                      color: const Color(0xFFFF2D55),
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        width: 44,
                                        height: 44,
                                        child: CachedNetworkImage(
                                          imageUrl: imageUrl,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) => Container(
                                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                                            child: const Icon(
                                              CupertinoIcons.music_note,
                                              size: 20,
                                              color: CupertinoColors.systemGrey,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            metadata.title,
                                            style: TextStyle(
                                              fontFamily: MusifiedStyle.uiFont,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: -0.2,
                                              color: titleColor,
                                              decoration: TextDecoration.none,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            metadata.artist ?? '',
                                            style: TextStyle(
                                              fontFamily: MusifiedStyle.uiFont,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w400,
                                              color: artistColor,
                                              decoration: TextDecoration.none,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isLoading)
                                      const Padding(
                                        padding: EdgeInsets.all(8),
                                        child: CupertinoActivityIndicator(radius: 10),
                                      )
                                    else
                                      CupertinoButton(
                                        padding: const EdgeInsets.all(8),
                                        minimumSize: const Size(36, 36),
                                        onPressed: () {
                                          HapticFeedback.selectionClick();
                                          if (isPlaying) {
                                            audioHandler.pause();
                                          } else {
                                            audioHandler.play();
                                          }
                                        },
                                        child: Icon(
                                          isPlaying
                                              ? CupertinoIcons.pause_fill
                                              : CupertinoIcons.play_fill,
                                          color: titleColor,
                                          size: 22,
                                        ),
                                      ),
                                    if (hasNext)
                                      CupertinoButton(
                                        padding: const EdgeInsets.all(8),
                                        minimumSize: const Size(36, 36),
                                        onPressed: () {
                                          HapticFeedback.selectionClick();
                                          audioHandler.skipToNext();
                                        },
                                        child: Icon(
                                          CupertinoIcons.forward_fill,
                                          color: artistColor,
                                          size: 20,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
