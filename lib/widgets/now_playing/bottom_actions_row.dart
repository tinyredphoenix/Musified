/*
 * Apple Music-style now-playing accessory row.
 * Icons only. Source tap opens a compact iOS list — never switches immediately.
 */

import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musified/extensions/l10n.dart';
import 'package:musified/main.dart';
import 'package:musified/services/common_services.dart';
import 'package:musified/services/playlist_download_service.dart';
import 'package:musified/services/settings_manager.dart';
import 'package:musified/utilities/flutter_bottom_sheet.dart';
import 'package:musified/utilities/flutter_toast.dart';
import 'package:musified/utilities/mediaitem.dart';
import 'package:musified/utilities/playlist_dialogs.dart';
import 'package:musified/widgets/download_picker_sheet.dart';
import 'package:musified/widgets/now_playing/source_picker_sheet.dart';
import 'package:musified/widgets/queue_list_view.dart';

class BottomActionsRow extends StatefulWidget {
  const BottomActionsRow({
    super.key,
    required this.metadata,
    required this.iconSize,
    required this.isLargeScreen,
    required this.lyricsController,
  });
  final MediaItem metadata;
  final double iconSize;
  final bool isLargeScreen;
  final dynamic lyricsController;

  @override
  State<BottomActionsRow> createState() => _BottomActionsRowState();
}

class _BottomActionsRowState extends State<BottomActionsRow> {
  late final ValueNotifier<bool> _songOfflineStatus;
  late final ValueNotifier<bool> _downloadInProgress;
  late String? _audioId = widget.metadata.extras?['ytid']?.toString();

  @override
  void initState() {
    super.initState();
    _songOfflineStatus = ValueNotifier<bool>(isSongAlreadyOffline(_audioId));
    _downloadInProgress = ValueNotifier<bool>(false);
    userOfflineSongs.addListener(_syncOfflineStatus);
  }

  void _syncOfflineStatus() {
    final newStatus = isSongAlreadyOffline(_audioId);
    if (_songOfflineStatus.value != newStatus) {
      _songOfflineStatus.value = newStatus;
    }
  }

  @override
  void didUpdateWidget(BottomActionsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldAudioId = oldWidget.metadata.extras?['ytid']?.toString();
    final newAudioId = widget.metadata.extras?['ytid']?.toString();
    if (oldAudioId != newAudioId) {
      _audioId = newAudioId;
      _songOfflineStatus.value = isSongAlreadyOffline(_audioId);
    }
  }

  @override
  void dispose() {
    userOfflineSongs.removeListener(_syncOfflineStatus);
    _songOfflineStatus.dispose();
    _downloadInProgress.dispose();
    super.dispose();
  }

  Color get _iconColor =>
      CupertinoDynamicColor.resolve(CupertinoColors.label, context);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final iconSize = widget.iconSize.clamp(22, 26).toDouble();

    return ValueListenableBuilder<int>(
      valueListenable: audioHandler.queueItemCount,
      builder: (context, queueLength, _) {
        final showQueueButton = queueLength > 0 && !widget.isLargeScreen;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _iconButton(
                icon: CupertinoIcons.quote_bubble,
                onPressed: widget.lyricsController.flipcard,
                size: iconSize,
              ),
              _iconButton(
                icon: audioSourceIcon(widget.metadata),
                color: audioSourceColor(widget.metadata),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  showAudioSourcePicker(context, widget.metadata);
                },
                size: iconSize,
              ),
              ValueListenableBuilder<bool>(
                valueListenable: _downloadInProgress,
                builder: (_, busy, __) {
                  if (busy) {
                    return const SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(child: CupertinoActivityIndicator()),
                    );
                  }
                  return ValueListenableBuilder<bool>(
                    valueListenable: _songOfflineStatus,
                    builder: (_, isOffline, __) {
                      return _iconButton(
                        icon: isOffline
                            ? CupertinoIcons.arrow_down_circle_fill
                            : CupertinoIcons.arrow_down_circle,
                        color: isOffline
                            ? CupertinoColors.activeBlue
                            : null,
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          unawaited(
                            _toggleOffline(
                              context,
                              _songOfflineStatus,
                              _audioId,
                              widget.metadata,
                              isDownloading: _downloadInProgress,
                            ),
                          );
                        },
                        size: iconSize,
                      );
                    },
                  );
                },
              ),
              if (showQueueButton)
                _iconButton(
                  icon: CupertinoIcons.list_bullet,
                  onPressed: () => showCustomBottomSheet(
                    context,
                    const QueueWidget(isBottomSheet: true),
                  ),
                  size: iconSize,
                ),
              ValueListenableBuilder<Duration?>(
                valueListenable: sleepTimerNotifier,
                builder: (_, timer, __) {
                  return _iconButton(
                    icon: CupertinoIcons.ellipsis,
                    onPressed: () => _showMoreSheet(context, l10n),
                    size: iconSize,
                    active: timer != null,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _iconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required double size,
    Color? color,
    bool active = false,
  }) {
    return CupertinoButton(
      padding: const EdgeInsets.all(10),
      minimumSize: const Size(44, 44),
      onPressed: onPressed,
      child: Icon(
        icon,
        size: size,
        color: color ??
            (active
                ? CupertinoColors.activeBlue
                : _iconColor.withValues(alpha: 0.85)),
      ),
    );
  }

  void _showMoreSheet(BuildContext context, dynamic l10n) {
    final isOffline = _songOfflineStatus.value;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        return CupertinoActionSheet(
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                if (_audioId == null) return;
                unawaited(
                  _toggleOffline(
                    context,
                    _songOfflineStatus,
                    _audioId,
                    widget.metadata,
                    isDownloading: _downloadInProgress,
                  ),
                );
              },
              child: Text(isOffline ? 'Remove Download' : l10n.makeOffline),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                if (sleepTimerNotifier.value != null) {
                  audioHandler.cancelSleepTimer();
                  sleepTimerNotifier.value = null;
                  showToast(context, context.l10n.sleepTimerCancelled);
                } else {
                  _showSleepTimerDialog(context);
                }
              },
              child: Text(
                sleepTimerNotifier.value != null
                    ? context.l10n.sleepTimerCancelled
                    : l10n.sleepTimer,
              ),
            ),
            if (!offlineMode.value)
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(ctx);
                  showAddToPlaylistDialog(
                    context,
                    song: mediaItemToMap(widget.metadata),
                  );
                },
                child: Text(l10n.addToPlaylist),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
        );
      },
    );
  }
}

Future<void> _toggleOffline(
  BuildContext context,
  ValueNotifier<bool> status,
  String? audioId,
  MediaItem metadata, {
  ValueNotifier<bool>? isDownloading,
}) async {
  final originalValue = status.value;

  if (originalValue) {
    status.value = false;
    try {
      final success =
          !(audioId == null) &&
          await OfflinePlaylistService().removeSongFromOfflineAndResync(
            audioId,
          );
      if (success && context.mounted) {
        showToast(context, 'Removed from downloads');
      } else if (!success) {
        status.value = originalValue;
        if (context.mounted) showToast(context, 'Failed to remove');
      }
    } catch (e) {
      status.value = originalValue;
      logger.log('Error toggling offline status', error: e);
      if (context.mounted) showToast(context, 'Error: $e');
    }
  } else {
    if (!context.mounted) return;
    final songMap = mediaItemToMap(metadata);
    unawaited(
      showDownloadPicker(context, songMap, (source, quality) async {
        if (!context.mounted) return;
        isDownloading?.value = true;
        showToast(context, 'Downloading...');
        try {
          final success = await makeSongOffline(
            songMap,
            source: source,
            quality: quality,
          );
          if (!context.mounted) return;
          if (success) {
            status.value = true;
            final offline = getOfflineSongByYtid(audioId ?? '');
            final actualSource = offline['downloadSource'] == 'jiosaavn'
                ? 'JioSaavn 320k'
                : 'YouTube AAC';
            final fallbackNotice =
                (source == 'saavn' || source == 'jiosaavn') &&
                    offline['downloadSource'] == 'youtube'
                ? ' (not on JioSaavn, saved via YouTube)'
                : '';
            showToast(context, 'Downloaded via $actualSource$fallbackNotice');
          } else {
            final sourceLabel = source == 'saavn' || source == 'jiosaavn'
                ? 'JioSaavn'
                : 'YouTube';
            showToast(
              context,
              '$sourceLabel download unavailable for this track. Try the other source.',
            );
          }
        } catch (e) {
          logger.log('Error downloading song', error: e);
          if (context.mounted) {
            showToast(
              context,
              'Download failed. Check your connection and try again.',
            );
          }
        } finally {
          isDownloading?.value = false;
        }
      }),
    );
  }
}

void _showSleepTimerDialog(BuildContext context) {
  showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) {
      return CupertinoActionSheet(
        title: Text(context.l10n.sleepTimer),
        message: Text(context.l10n.selectDuration),
        actions: [
          for (final mins in [15, 30, 45, 60])
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                audioHandler.setSleepTimer(Duration(minutes: mins));
                showToast(
                  context,
                  context.l10n.sleepTimerSet,
                  duration: const Duration(seconds: 1, milliseconds: 500),
                );
              },
              child: Text('$mins min'),
            ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              audioHandler.setSleepTimerEndOfSong();
              showToast(
                context,
                context.l10n.sleepTimerSet,
                duration: const Duration(seconds: 1, milliseconds: 500),
              );
            },
            child: Text(context.l10n.endOfSong),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: Text(context.l10n.cancel),
        ),
      );
    },
  );
}
