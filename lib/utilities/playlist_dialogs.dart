import 'package:flutter/cupertino.dart';
import 'package:musified/services/playlists_manager.dart';
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

  showCupertinoDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) {
        return CupertinoAlertDialog(
          title: const Text(
            'New Playlist',
            style: TextStyle(
              fontFamily: MusifiedStyle.displayFont,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoSegmentedControl<bool>(
                  children: const {
                    true: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Text('Custom', style: TextStyle(fontSize: 13)),
                    ),
                    false: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Text('YouTube Link', style: TextStyle(fontSize: 13)),
                    ),
                  },
                  groupValue: isCustom,
                  selectedColor: const Color(0xFFFF2D55),
                  onValueChanged: (val) {
                    setDialogState(() {
                      isCustom = val;
                    });
                  },
                ),
                const SizedBox(height: 14),
                if (isCustom)
                  CupertinoTextField(
                    controller: nameController,
                    placeholder: 'Playlist Name',
                    autofocus: true,
                    style: const TextStyle(fontSize: 14),
                  )
                else
                  CupertinoTextField(
                    controller: linkController,
                    placeholder: 'https://youtube.com/playlist?list=...',
                    autofocus: true,
                    style: const TextStyle(fontSize: 14),
                  ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () async {
                Navigator.pop(ctx);
                if (isCustom) {
                  final name = nameController.text.trim();
                  if (name.isNotEmpty) {
                    final res = createCustomPlaylist(name, null, context);
                    if (songToAdd != null && songToAdd is Map) {
                      addSongInCustomPlaylist(context, res.$2, songToAdd);
                    } else if (songsToAdd != null && songsToAdd.isNotEmpty) {
                      addSongsInCustomPlaylist(
                        context,
                        res.$2,
                        songsToAdd.whereType<Map>().toList(),
                      );
                    }
                    if (context.mounted) showToast(context, res.$1);
                  }
                } else {
                  final link = linkController.text.trim();
                  if (link.isNotEmpty) {
                    final result = await addUserPlaylist(link, context);
                    if (context.mounted) showToast(context, result);
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    ),
  );
}

void showAddToPlaylistDialog(
  BuildContext context, {
  required dynamic song,
}) {
  showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: const Text('Add Track to Playlist'),
      actions: [
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
              Text('New Playlist...'),
            ],
          ),
        ),
        ...userCustomPlaylists.value.map((playlist) {
          final p = playlist;
          final name = p['title']?.toString() ?? 'Custom Playlist';
          final id = p['id']?.toString() ?? p['ytid']?.toString() ?? '';

          return CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              if (song is Map) {
                final result = addSongInCustomPlaylist(context, id, song);
                showToast(context, result);
              }
            },
            child: Text(name),
          );
        }),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.pop(ctx),
        child: const Text('Cancel'),
      ),
    ),
  );
}
