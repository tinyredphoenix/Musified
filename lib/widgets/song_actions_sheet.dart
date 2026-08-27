import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musified/main.dart';
import 'package:musified/services/common_services.dart';
import 'package:musified/services/settings_manager.dart';
import 'package:musified/utilities/flutter_toast.dart';
import 'package:musified/utilities/playlist_dialogs.dart';
import 'package:musified/utilities/song_info_dialog.dart';

/// Shows a pure iOS Cupertino action sheet for a song's contextual actions.
void showSongActionsSheet(
  BuildContext context, {
  required Map song,
  bool canRemove = false,
  VoidCallback? onRemove,
  bool isRecent = false,
}) {
  final ytid = song['ytid']?.toString() ?? '';
  final title = song['title']?.toString() ?? 'Track Options';
  final artist = song['artist']?.toString() ?? '';
  final isLiked = isSongAlreadyLiked(ytid);
  final isOffline = isSongAlreadyOffline(ytid);

  showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      message: artist.isNotEmpty
          ? Text(
              artist,
              style: const TextStyle(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      actions: [
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(ctx);
            audioHandler.playNext(song);
            showToast(context, 'Playing next');
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.play_rectangle, size: 20),
              SizedBox(width: 10),
              Text('Play Next'),
            ],
          ),
        ),
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(ctx);
            audioHandler.addToQueue(song);
            showToast(context, 'Added to queue');
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.text_badge_plus, size: 20),
              SizedBox(width: 10),
              Text('Add to Queue'),
            ],
          ),
        ),
        if (!offlineMode.value)
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              HapticFeedback.mediumImpact();
              final nextLiked = !isLiked;
              await updateSongLikeStatus(ytid, nextLiked, songData: song);
              if (context.mounted) {
                showToast(
                  context,
                  nextLiked ? 'Added to Liked Songs' : 'Removed from Liked Songs',
                );
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isLiked ? CupertinoIcons.heart_slash_fill : CupertinoIcons.heart_fill,
                  size: 20,
                  color: isLiked ? CupertinoColors.systemRed : const Color(0xFFFF2D55),
                ),
                const SizedBox(width: 10),
                Text(isLiked ? 'Remove from Favorites' : 'Favorite'),
              ],
            ),
          ),
        if (!offlineMode.value)
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              showAddToPlaylistDialog(context, song: song);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.plus_circle, size: 20),
                SizedBox(width: 10),
                Text('Add to a Playlist...'),
              ],
            ),
          ),
        CupertinoActionSheetAction(
          onPressed: () async {
            Navigator.pop(ctx);
            if (isOffline) {
              await removeSongFromOffline(ytid);
              if (context.mounted) showToast(context, 'Download removed');
            } else {
              showToast(context, 'Downloading track...');
              final success = await makeSongOffline(song);
              if (context.mounted) {
                showToast(
                  context,
                  success ? 'Downloaded to Device' : 'Download failed',
                );
              }
            }
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isOffline ? CupertinoIcons.trash : CupertinoIcons.arrow_down_circle,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(isOffline ? 'Remove Download' : 'Download to Device'),
            ],
          ),
        ),
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(ctx);
            showSongInfoDialog(context, song);
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.info_circle, size: 20),
              SizedBox(width: 10),
              Text('Track Details'),
            ],
          ),
        ),
        if (canRemove && onRemove != null)
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              onRemove();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.delete, size: 20, color: CupertinoColors.destructiveRed),
                SizedBox(width: 10),
                Text('Remove'),
              ],
            ),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.pop(ctx),
        child: const Text('Done'),
      ),
    ),
  );
}
