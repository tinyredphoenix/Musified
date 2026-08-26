/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Musify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Musify, including how to contribute,
 *     please visit: https://github.com/gokadzev/Musify
 */

import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/playlist_download_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/flutter_bottom_sheet.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/mediaitem.dart';
import 'package:musify/utilities/playlist_dialogs.dart';
import 'package:musify/widgets/download_picker_sheet.dart';
import 'package:musify/widgets/queue_list_view.dart';

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
  late final ValueNotifier<bool> _songLikeStatus;
  late final ValueNotifier<bool> _songOfflineStatus;
  late final ValueNotifier<bool> _downloadInProgress;
  late String? _audioId = widget.metadata.extras?['ytid']?.toString();
  late bool _isRadioStation = widget.metadata.extras?['isLive'] == true;

  @override
  void initState() {
    super.initState();
    if (_isRadioStation) {
      _songLikeStatus = ValueNotifier<bool>(
        isRadioStationLiked(_audioId ?? ''),
      );
      userLikedRadioStations.addListener(_syncRadioLikeStatus);
    } else {
      _songLikeStatus = ValueNotifier<bool>(isSongAlreadyLiked(_audioId));
      userLikedSongsList.addListener(_syncLikeStatus);
    }
    _songOfflineStatus = ValueNotifier<bool>(isSongAlreadyOffline(_audioId));
    _downloadInProgress = ValueNotifier<bool>(false);
    userOfflineSongs.addListener(_syncOfflineStatus);
  }

  void _syncLikeStatus() {
    final newStatus = isSongAlreadyLiked(_audioId);
    if (_songLikeStatus.value != newStatus) {
      _songLikeStatus.value = newStatus;
    }
  }

  void _syncRadioLikeStatus() {
    final newStatus = isRadioStationLiked(_audioId ?? '');
    if (_songLikeStatus.value != newStatus) {
      _songLikeStatus.value = newStatus;
    }
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
    final newIsRadioStation = widget.metadata.extras?['isLive'] == true;
    if (oldAudioId != newAudioId || _isRadioStation != newIsRadioStation) {
      if (_isRadioStation) {
        userLikedRadioStations.removeListener(_syncRadioLikeStatus);
      } else {
        userLikedSongsList.removeListener(_syncLikeStatus);
      }
      _audioId = newAudioId;
      _isRadioStation = newIsRadioStation;
      if (_isRadioStation) {
        _songLikeStatus.value = isRadioStationLiked(_audioId ?? '');
        userLikedRadioStations.addListener(_syncRadioLikeStatus);
      } else {
        _songLikeStatus.value = isSongAlreadyLiked(_audioId);
        userLikedSongsList.addListener(_syncLikeStatus);
      }
      _songOfflineStatus.value = isSongAlreadyOffline(_audioId);
    }
  }

  @override
  void dispose() {
    if (_isRadioStation) {
      userLikedRadioStations.removeListener(_syncRadioLikeStatus);
    } else {
      userLikedSongsList.removeListener(_syncLikeStatus);
    }
    userOfflineSongs.removeListener(_syncOfflineStatus);
    _songLikeStatus.dispose();
    _songOfflineStatus.dispose();
    _downloadInProgress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final responsiveIconSize = screenWidth < 360
        ? widget.iconSize * 0.85
        : widget.iconSize;

    return StreamBuilder<List<Map>>(
      stream: audioHandler.queueAsMapStream,
      builder: (context, snapshot) {
        final queue = snapshot.data ?? [];

        final actions = <Widget>[
          if (!_isRadioStation)
            _buildActionButton(
              context: context,
              icon: FluentIcons.cloud_arrow_down_24_regular,
              activeIcon: FluentIcons.cloud_off_24_filled,
              colorScheme: colorScheme,
              size: responsiveIconSize,
              statusNotifier: _songOfflineStatus,
              onPressed: _audioId == null
                  ? null
                  : () => _toggleOffline(
                      context,
                      _songOfflineStatus,
                      _audioId,
                      widget.metadata,
                      isDownloading: _downloadInProgress,
                    ),
              tooltip: l10n.makeOffline,
              busyNotifier: _downloadInProgress,
            ),
          _buildSleepTimerButton(context, colorScheme, responsiveIconSize),
          if (!offlineMode.value && !_isRadioStation)
            _buildSimpleActionButton(
              context: context,
              icon: FluentIcons.album_add_24_regular,
              colorScheme: colorScheme,
              size: responsiveIconSize,
              onPressed: () => showAddToPlaylistDialog(
                context,
                song: mediaItemToMap(widget.metadata),
              ),
              tooltip: l10n.addToPlaylist,
            ),
          if (queue.isNotEmpty && !_isRadioStation && !widget.isLargeScreen)
            _buildSimpleActionButton(
              context: context,
              icon: FluentIcons.apps_list_24_filled,
              colorScheme: colorScheme,
              size: responsiveIconSize,
              onPressed: () => showCustomBottomSheet(
                context,
                const QueueWidget(isBottomSheet: true),
              ),
              tooltip: l10n.queue,
            ),
          if (!offlineMode.value) ...[
            if (!_isRadioStation)
              _buildSimpleActionButton(
                context: context,
                icon: FluentIcons.text_quote_24_regular,
                colorScheme: colorScheme,
                size: responsiveIconSize,
                onPressed: widget.lyricsController.flipcard,
                tooltip: l10n.lyrics,
              ),
            _buildActionButton(
              context: context,
              icon: FluentIcons.heart_24_regular,
              activeIcon: FluentIcons.heart_24_filled,
              colorScheme: colorScheme,
              size: responsiveIconSize,
              statusNotifier: _songLikeStatus,
              activeColor: colorScheme.primary,
              onPressed: () async {
                final id = _audioId;
                if (id == null) return;

                final originalValue = _songLikeStatus.value;
                _songLikeStatus.value = !originalValue;

                try {
                  if (_isRadioStation) {
                    if (originalValue) {
                      await removeRadioStationFromLiked(id);
                    } else {
                      await addRadioStationToLiked(id);
                    }
                  } else {
                    await updateSongLikeStatus(
                      _audioId,
                      !originalValue,
                      songData: mediaItemToMap(widget.metadata),
                    );
                  }
                } catch (e) {
                  _songLikeStatus.value = originalValue; // revert on failure
                  logger.log('Error toggling like status', error: e);
                }
              },
              tooltip: l10n.likedSongs,
            ),
          ],
        ];

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: actions,
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required ColorScheme colorScheme,
    required double size,
    required ValueNotifier<bool> statusNotifier,
    required VoidCallback? onPressed,
    Color? activeColor,
    String? tooltip,
    ValueNotifier<bool>? busyNotifier,
  }) {
    final button = ValueListenableBuilder<bool>(
      valueListenable: statusNotifier,
      builder: (_, isActive, __) {
        return IconButton(
          icon: Icon(
            isActive ? activeIcon : icon,
            color: isActive
                ? (activeColor ?? colorScheme.primary)
                : colorScheme.onSurfaceVariant,
          ),
          iconSize: size,
          tooltip: tooltip,
          style: IconButton.styleFrom(
            backgroundColor: isActive
                ? (activeColor ?? colorScheme.primary).withValues(alpha: 0.15)
                : Colors.transparent,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: onPressed,
        );
      },
    );
    if (busyNotifier == null) return button;
    return ValueListenableBuilder<bool>(
      valueListenable: busyNotifier,
      builder: (_, busy, __) => busy
          ? CupertinoButton(
              onPressed: null,
              padding: EdgeInsets.zero,
              minimumSize: Size(size + 24, size + 24),
              child: const CupertinoActivityIndicator(),
            )
          : button,
    );
  }

  Widget _buildSimpleActionButton({
    required BuildContext context,
    required IconData icon,
    required ColorScheme colorScheme,
    required double size,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    return IconButton(
      icon: Icon(icon, color: colorScheme.onSurfaceVariant),
      iconSize: size,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
    );
  }

  Widget _buildSleepTimerButton(
    BuildContext context,
    ColorScheme colorScheme,
    double size,
  ) {
    return ValueListenableBuilder<Duration?>(
      valueListenable: sleepTimerNotifier,
      builder: (_, value, __) {
        final isActive = value != null;
        return IconButton(
          icon: Icon(
            isActive
                ? FluentIcons.timer_24_filled
                : FluentIcons.timer_24_regular,
            color: isActive
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
          iconSize: size,
          tooltip: context.l10n.sleepTimer,
          style: IconButton.styleFrom(
            backgroundColor: isActive
                ? colorScheme.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            if (isActive) {
              audioHandler.cancelSleepTimer();
              sleepTimerNotifier.value = null;
              showToast(
                context,
                context.l10n.sleepTimerCancelled,
                duration: const Duration(seconds: 1, milliseconds: 500),
              );
            } else {
              _showSleepTimerDialog(context);
            }
          },
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
            showToast(context, 'Downloaded successfully');
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
  final colorScheme = Theme.of(context).colorScheme;

  showDialog(
    context: context,
    builder: (context) {
      final duration = sleepTimerNotifier.value ?? Duration.zero;
      var hours = duration.inMinutes ~/ 60;
      var minutes = duration.inMinutes % 60;

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(FluentIcons.timer_24_regular, color: colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  context.l10n.sleepTimer,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.selectDuration,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                _buildTimeSelector(
                  context: context,
                  label: context.l10n.hours,
                  value: hours,
                  colorScheme: colorScheme,
                  onDecrement: () {
                    if (hours > 0) setState(() => hours--);
                  },
                  onIncrement: () => setState(() => hours++),
                ),
                const SizedBox(height: 16),
                _buildTimeSelector(
                  context: context,
                  label: context.l10n.minutes,
                  value: minutes,
                  colorScheme: colorScheme,
                  onDecrement: () {
                    if (minutes > 0) setState(() => minutes--);
                  },
                  onIncrement: () {
                    if (minutes < 59) setState(() => minutes++);
                  },
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ...[15, 30, 45, 60].map((mins) {
                      return ActionChip(
                        label: Text('$mins min'),
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        labelStyle: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onPressed: () {
                          setState(() {
                            hours = mins ~/ 60;
                            minutes = mins % 60;
                          });
                        },
                      );
                    }),
                    ActionChip(
                      label: Text(context.l10n.endOfSong),
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      labelStyle: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onPressed: () {
                        audioHandler.setSleepTimerEndOfSong();
                        showToast(
                          context,
                          context.l10n.sleepTimerSet,
                          duration: const Duration(
                            seconds: 1,
                            milliseconds: 500,
                          ),
                        );
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                onPressed: () {
                  final duration = Duration(hours: hours, minutes: minutes);
                  if (duration.inSeconds > 0) {
                    audioHandler.setSleepTimer(duration);
                    showToast(
                      context,
                      context.l10n.sleepTimerSet,
                      duration: const Duration(seconds: 1, milliseconds: 500),
                    );
                  }
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(context.l10n.setTimer),
              ),
            ],
          );
        },
      );
    },
  );
}

Widget _buildTimeSelector({
  required BuildContext context,
  required String label,
  required int value,
  required ColorScheme colorScheme,
  required VoidCallback onDecrement,
  required VoidCallback onIncrement,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(
                FluentIcons.line_horizontal_1_24_regular,
                color: colorScheme.onSurfaceVariant,
              ),
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: onDecrement,
            ),
            Container(
              width: 48,
              alignment: Alignment.center,
              child: Text(
                '$value',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                FluentIcons.add_24_regular,
                color: colorScheme.onSurfaceVariant,
              ),
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: onIncrement,
            ),
          ],
        ),
      ],
    ),
  );
}
