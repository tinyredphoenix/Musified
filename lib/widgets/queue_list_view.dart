import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musified/main.dart';
import 'package:musified/theme/musified_style.dart';
import 'package:musified/widgets/confirmation_dialog.dart';
import 'package:musified/widgets/no_artwork_cube.dart';

class QueueWidget extends StatefulWidget {
  const QueueWidget({super.key, this.isBottomSheet = false});

  final bool isBottomSheet;

  @override
  State<QueueWidget> createState() => _QueueWidgetState();
}

class _QueueWidgetState extends State<QueueWidget> {
  List<Map> _queue = [];
  late StreamSubscription<List<Map>> _subscription;
  late StreamSubscription<MediaItem?> _mediaSubscription;
  bool _isDismissing = false;
  bool _hasScrolledToInitial = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _subscription = audioHandler.queueAsMapStream.listen((queue) {
      if (mounted && !_isDismissing) {
        setState(() {
          _queue = List<Map>.from(queue);
        });
        if (!_hasScrolledToInitial && queue.isNotEmpty) {
          _hasScrolledToInitial = true;
          _scrollToCurrentSong();
        }
      }
    });
    _mediaSubscription = audioHandler.mediaItem
        .distinct((prev, next) => prev?.id == next?.id)
        .listen((_) {
          if (mounted && !_isDismissing) setState(() {});
        });
  }

  void _scrollToCurrentSong() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final currentIndex = audioHandler.currentQueueIndex;
      if (currentIndex <= 0) return;
      const estimatedItemHeight = 60.0;
      final targetOffset = currentIndex * estimatedItemHeight;
      final clampedOffset = targetOffset.clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    _mediaSubscription.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final currentIndex = audioHandler.currentQueueIndex;

    if (widget.isBottomSheet) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context, isDark, compact: true),
          _buildBottomSheetContent(context, isDark, currentIndex),
        ],
      );
    }

    return Column(
      children: [
        _buildHeader(context, isDark, compact: false),
        Container(
          height: 0.5,
          color: isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000),
          margin: const EdgeInsets.symmetric(horizontal: 16),
        ),
        Expanded(
          child: _queue.isEmpty
              ? _buildEmptyState(context, isDark)
              : _buildList(context, isDark, currentIndex),
        ),
      ],
    );
  }

  void _confirmClearQueue(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      builder: (_) => ConfirmationDialog(
        confirmationMessage: 'Clear all upcoming tracks from queue?',
        submitMessage: 'Clear',
        isDangerous: true,
        onCancel: () => Navigator.pop(context),
        onSubmit: () {
          Navigator.pop(context);
          audioHandler.clearQueue();
          if (widget.isBottomSheet) Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDark, {
    required bool compact,
  }) {
    final titleColor = isDark ? CupertinoColors.white : CupertinoColors.black;

    return Padding(
      padding: compact
          ? const EdgeInsets.fromLTRB(16, 12, 16, 12)
          : const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF2D55).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              CupertinoIcons.list_bullet,
              color: Color(0xFFFF2D55),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Playing Next',
                  style: TextStyle(
                    fontFamily: MusifiedStyle.displayFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: titleColor,
                    decoration: TextDecoration.none,
                  ),
                ),
                Text(
                  '${_queue.length} songs',
                  style: const TextStyle(
                    fontFamily: MusifiedStyle.uiFont,
                    fontSize: 12,
                    color: CupertinoColors.systemGrey,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          if (_queue.isNotEmpty)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              onPressed: () => _confirmClearQueue(context),
              child: const Text('Clear', style: TextStyle(color: CupertinoColors.destructiveRed, fontSize: 14)),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomSheetContent(
    BuildContext context,
    bool isDark,
    int currentIndex,
  ) {
    if (_queue.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'Queue is empty',
          style: TextStyle(
            fontFamily: MusifiedStyle.uiFont,
            color: CupertinoColors.systemGrey,
            fontSize: 14,
            decoration: TextDecoration.none,
          ),
        ),
      );
    }
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.52,
      child: _buildList(context, isDark, currentIndex, closeOnTap: true),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.music_note,
                color: CupertinoColors.systemGrey,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No upcoming tracks in queue',
              style: TextStyle(
                fontFamily: MusifiedStyle.uiFont,
                color: CupertinoColors.systemGrey,
                fontSize: 15,
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _queueEntryKey(Map song, int index) {
    final entryId = song['queueEntryId']?.toString() ?? song['ytid'];
    return '${entryId}_$index';
  }

  Widget _buildList(
    BuildContext context,
    bool isDark,
    int currentIndex, {
    bool closeOnTap = false,
  }) {
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      itemCount: _queue.length,
      itemBuilder: (context, index) {
        final song = _queue[index];
        final isCurrentSong = index == currentIndex;
        final queueEntryId = _queueEntryKey(song, index);
        return _QueueTile(
          key: ValueKey(queueEntryId),
          song: song,
          index: index,
          isCurrentSong: isCurrentSong,
          isDark: isDark,
          onTap: () {
            HapticFeedback.selectionClick();
            audioHandler.skipToSong(index);
            if (closeOnTap) Navigator.pop(context);
          },
          onRemove: () {
            setState(() {
              _queue.removeAt(index);
            });
            audioHandler.removeQueueItemAt(index);
          },
        );
      },
    );
  }
}

class _QueueTile extends StatelessWidget {
  const _QueueTile({
    super.key,
    required this.song,
    required this.index,
    required this.isCurrentSong,
    required this.isDark,
    required this.onTap,
    required this.onRemove,
  });

  final Map song;
  final int index;
  final bool isCurrentSong;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final title = song['title']?.toString() ?? 'Track';
    final artist = song['artist']?.toString() ?? 'Artist';
    final image = song['image']?.toString() ?? song['lowResImage']?.toString() ?? '';
    final isLocalFile = image.startsWith('/') || image.startsWith('file://');
    final activeColor = const Color(0xFFFF2D55);
    final titleColor = isCurrentSong
        ? activeColor
        : (isDark ? CupertinoColors.white : CupertinoColors.black);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isCurrentSong
            ? activeColor.withValues(alpha: 0.12)
            : (isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: isLocalFile
                      ? Image.file(
                          File(image.replaceFirst('file://', '')),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const NullArtworkWidget(iconSize: 18, size: 44),
                        )
                      : image.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: image,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const NullArtworkWidget(iconSize: 18, size: 44),
                            )
                          : const NullArtworkWidget(iconSize: 18, size: 44),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: MusifiedStyle.uiFont,
                        fontSize: 14,
                        fontWeight: isCurrentSong ? FontWeight.w700 : FontWeight.w600,
                        color: titleColor,
                        decoration: TextDecoration.none,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      artist,
                      style: const TextStyle(
                        fontFamily: MusifiedStyle.uiFont,
                        fontSize: 12,
                        color: CupertinoColors.systemGrey,
                        decoration: TextDecoration.none,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                onPressed: onRemove,
                child: const Icon(CupertinoIcons.xmark, size: 16, color: CupertinoColors.systemGrey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
