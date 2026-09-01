import 'package:flutter/cupertino.dart';
import 'package:musified/extensions/l10n.dart';
import 'package:musified/services/playlists_manager.dart';
import 'package:musified/services/youtube_auth_service.dart';
import 'package:musified/services/youtube_music_sync_service.dart';
import 'package:musified/theme/app_themes.dart';
import 'package:musified/theme/musified_style.dart';
import 'package:musified/utilities/flutter_toast.dart';

void showCreatePlaylistDialog(
  BuildContext context, {
  dynamic songToAdd,
  List<dynamic>? songsToAdd,
}) {
  final nameController = TextEditingController();
  final linkController = TextEditingController();
  var isCustom = true;

  showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) {
      final isDark = isAppDarkMode(ctx);
      final sheetColor =
          isDark ? MusifiedStyle.elevated : MusifiedStyle.lightElevated;
      final hairline =
          isDark ? MusifiedStyle.hairline : MusifiedStyle.lightHairline;
      final primary = CupertinoTheme.of(ctx).primaryColor;
      final labelColor =
          isDark ? CupertinoColors.white : CupertinoColors.black;
      final fieldFill =
          isDark ? MusifiedStyle.surface : MusifiedStyle.lightSurfaceHigh;
      final placeholderColor = isDark
          ? MusifiedStyle.tertiaryLabel
          : MusifiedStyle.lightTertiaryLabel;
      final unselectedLabel = isDark
          ? MusifiedStyle.secondaryLabel
          : MusifiedStyle.lightSecondaryLabel;

      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              decoration: BoxDecoration(
                color: sheetColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(MusifiedStyle.radiusXl),
                ),
                border: Border(top: BorderSide(color: hairline)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 8),
                      child: Container(
                        width: 36,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0x66FFFFFF)
                              : const Color(0x33000000),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                    Text(
                      'New Playlist',
                      style: MusifiedStyle.largeTitle(labelColor),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoSlidingSegmentedControl<bool>(
                        groupValue: isCustom,
                        thumbColor: primary,
                        backgroundColor: fieldFill,
                        onValueChanged: (val) {
                          if (val == null) return;
                          setDialogState(() => isCustom = val);
                        },
                        children: {
                          true: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            child: Text(
                              'Custom',
                              style: TextStyle(
                                fontFamily: MusifiedStyle.uiFont,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isCustom
                                    ? CupertinoColors.white
                                    : unselectedLabel,
                              ),
                            ),
                          ),
                          false: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            child: Text(
                              'YouTube Link',
                              style: TextStyle(
                                fontFamily: MusifiedStyle.uiFont,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: !isCustom
                                    ? CupertinoColors.white
                                    : unselectedLabel,
                              ),
                            ),
                          ),
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    CupertinoTextField(
                      controller: isCustom ? nameController : linkController,
                      placeholder: isCustom
                          ? 'Playlist name'
                          : 'YouTube playlist URL',
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      style: TextStyle(
                        fontFamily: MusifiedStyle.uiFont,
                        fontSize: 16,
                        color: labelColor,
                      ),
                      placeholderStyle: TextStyle(
                        fontFamily: MusifiedStyle.uiFont,
                        fontSize: 16,
                        color: placeholderColor,
                      ),
                      cursorColor: primary,
                      decoration: BoxDecoration(
                        color: fieldFill,
                        borderRadius: BorderRadius.circular(
                          MusifiedStyle.radiusMd,
                        ),
                        border: Border.all(color: hairline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: CupertinoButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              ctx.l10n.cancel,
                              style: TextStyle(
                                fontFamily: MusifiedStyle.uiFont,
                                color: unselectedLabel,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CupertinoButton.filled(
                            borderRadius: BorderRadius.circular(
                              MusifiedStyle.radiusMd,
                            ),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              if (isCustom) {
                                final name = nameController.text.trim();
                                if (name.isEmpty) return;
                                final res = createCustomPlaylist(
                                  name,
                                  null,
                                  context,
                                );
                                if (songToAdd != null && songToAdd is Map) {
                                  addSongInCustomPlaylist(
                                    context,
                                    res.$2,
                                    songToAdd,
                                  );
                                } else if (songsToAdd != null &&
                                    songsToAdd.isNotEmpty) {
                                  addSongsInCustomPlaylist(
                                    context,
                                    res.$2,
                                    songsToAdd.whereType<Map>().toList(),
                                  );
                                }
                                if (context.mounted) {
                                  showToast(context, res.$1);
                                }
                              } else {
                                final link = linkController.text.trim();
                                if (link.isNotEmpty) {
                                  final result = await addUserPlaylist(
                                    link,
                                    context,
                                  );
                                  if (context.mounted) {
                                    showToast(context, result);
                                  }
                                }
                              }
                            },
                            child: Text(
                              ctx.l10n.create,
                              style: const TextStyle(
                                fontFamily: MusifiedStyle.uiFont,
                                color: CupertinoColors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  ).whenComplete(() {
    nameController.dispose();
    linkController.dispose();
  });
}

void showAddToPlaylistDialog(
  BuildContext context, {
  required dynamic song,
}) {
  final ytSync = YouTubeMusicSyncService();
  final ytAuth = YouTubeAuthService();

  showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => ListenableBuilder(
      listenable: Listenable.merge([
        userCustomPlaylists,
        ytSync.ytMusicPlaylists,
        ytAuth.isSignedIn,
      ]),
      builder: (context, _) {
        final custom = getUserCustomPlaylists();
        final ytPlaylists = ytAuth.isSignedIn.value
            ? ytSync.ytMusicPlaylists.value
            : <Map<String, dynamic>>[];
        final hasTargets = custom.isNotEmpty || ytPlaylists.isNotEmpty;

        final actions = <Widget>[
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              showCreatePlaylistDialog(context, songToAdd: song);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.plus_circle, size: 20),
                SizedBox(width: 8),
                Text('New Custom Playlist...'),
              ],
            ),
          ),
        ];

        if (ytAuth.isSignedIn.value) {
          actions.add(
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                showCreateYouTubeMusicPlaylistDialog(
                  context,
                  songToAdd: song is Map ? song : null,
                );
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.play_rectangle, size: 20),
                  SizedBox(width: 8),
                  Text('New YouTube Music Playlist...'),
                ],
              ),
            ),
          );
        }

        if (custom.isNotEmpty) {
          for (final playlist in custom) {
            final name = playlist['title']?.toString() ?? 'Custom Playlist';
            final id = playlist['ytid']?.toString() ?? '';
            actions.add(
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (song is Map && id.isNotEmpty) {
                    final result = addSongInCustomPlaylist(context, id, song);
                    showToast(context, result);
                  }
                },
                child: Text('My · $name'),
              ),
            );
          }
        }

        if (ytPlaylists.isNotEmpty) {
          for (final playlist in ytPlaylists) {
            final name = playlist['title']?.toString() ?? 'Playlist';
            final id = playlist['playlistId']?.toString() ?? '';
            if (id.isEmpty) continue;
            actions.add(
              CupertinoActionSheetAction(
                onPressed: () async {
                  Navigator.pop(ctx);
                  if (song is! Map) return;
                  final result = await addSongToYouTubeMusicPlaylist(
                    context,
                    id,
                    song,
                  );
                  if (context.mounted) {
                    showToast(context, result);
                  }
                },
                child: Text('YouTube · $name'),
              ),
            );
          }
        }

        return CupertinoActionSheet(
          title: const Text('Add Track to Playlist'),
          message: hasTargets
              ? null
              : const Text('Create a playlist to save this track'),
          actions: actions,
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        );
      },
    ),
  );
}

void showCreateYouTubeMusicPlaylistDialog(
  BuildContext context, {
  Map? songToAdd,
}) {
  final nameController = TextEditingController();
  showCupertinoDialog<void>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text('YouTube Music Playlist'),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: CupertinoTextField(
          controller: nameController,
          placeholder: 'Playlist name',
          autofocus: true,
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(context.l10n.cancel),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () async {
            final name = nameController.text.trim();
            Navigator.pop(ctx);
            if (name.isEmpty) return;
            final result = await createYouTubeMusicPlaylist(
              name,
              songToAdd,
              context,
            );
            if (context.mounted) {
              showToast(context, result);
            }
          },
          child: Text(context.l10n.create),
        ),
      ],
    ),
  ).whenComplete(nameController.dispose);
}
