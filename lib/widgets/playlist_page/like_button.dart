import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musified/services/common_services.dart';
import 'package:musified/services/playlists_manager.dart';

class PlaylistLikeButton extends StatefulWidget {
  const PlaylistLikeButton({
    super.key,
    required this.playlistId,
    required this.playlistData,
  });

  final String playlistId;
  final Map? Function() playlistData;

  @override
  State<PlaylistLikeButton> createState() => _PlaylistLikeButtonState();
}

class _PlaylistLikeButtonState extends State<PlaylistLikeButton> {
  late final ValueNotifier<bool> _isLiked = ValueNotifier<bool>(
    isPlaylistAlreadyLiked(widget.playlistId),
  );

  @override
  void initState() {
    super.initState();
    userLikedPlaylists.addListener(_syncLikeStatus);
  }

  @override
  void didUpdateWidget(covariant PlaylistLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playlistId != widget.playlistId) _syncLikeStatus();
  }

  @override
  void dispose() {
    userLikedPlaylists.removeListener(_syncLikeStatus);
    _isLiked.dispose();
    super.dispose();
  }

  void _syncLikeStatus() {
    _isLiked.value = isPlaylistAlreadyLiked(widget.playlistId);
  }

  void _toggleLikeStatus() {
    HapticFeedback.mediumImpact();
    _isLiked.value = !_isLiked.value;
    unawaited(
      updatePlaylistLikeStatus(
        widget.playlistId,
        _isLiked.value,
        playlistData: widget.playlistData(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.playlistId.isEmpty) return const SizedBox.shrink();

    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;

    return ValueListenableBuilder<bool>(
      valueListenable: _isLiked,
      builder: (context, isLiked, __) {
        return CupertinoButton(
          padding: const EdgeInsets.all(10),
          color: isLiked
              ? const Color(0xFFFF2D55)
              : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA)),
          borderRadius: BorderRadius.circular(22),
          onPressed: _toggleLikeStatus,
          child: Icon(
            isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
            color: isLiked ? CupertinoColors.white : const Color(0xFFFF2D55),
            size: 20,
          ),
        );
      },
    );
  }
}
