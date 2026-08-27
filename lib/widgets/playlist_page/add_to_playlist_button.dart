import 'package:flutter/cupertino.dart';
import 'package:musified/utilities/flutter_toast.dart';
import 'package:musified/utilities/playlist_dialogs.dart';

class PlaylistAddToPlaylistButton extends StatefulWidget {
  const PlaylistAddToPlaylistButton({super.key, required this.resolvePlaylist});

  final Future<Map?> Function() resolvePlaylist;

  @override
  State<PlaylistAddToPlaylistButton> createState() =>
      _PlaylistAddToPlaylistButtonState();
}

class _PlaylistAddToPlaylistButtonState
    extends State<PlaylistAddToPlaylistButton> {
  bool _isResolving = false;

  @override
  Widget build(BuildContext context) {
    if (_isResolving) {
      return const SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: CupertinoActivityIndicator(),
        ),
      );
    }

    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;

    return CupertinoButton(
      padding: const EdgeInsets.all(10),
      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
      borderRadius: BorderRadius.circular(22),
      onPressed: _resolveAndAdd,
      child: const Icon(CupertinoIcons.plus, size: 20, color: Color(0xFFFF2D55)),
    );
  }

  Future<void> _resolveAndAdd() async {
    if (_isResolving) return;
    setState(() => _isResolving = true);

    Map? playlist;
    try {
      playlist = await widget.resolvePlaylist();
    } catch (_) {
      if (mounted) showToast(context, 'Unable to load playlist');
      return;
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
    if (!mounted) return;

    if (playlist == null || playlist['list'] is! List) {
      showToast(context, 'Unable to load playlist');
      return;
    }

    final songs = playlist['list'] as List;
    if (songs.isEmpty) {
      showToast(context, 'Playlist is empty');
      return;
    }

    showAddToPlaylistDialog(context, song: null);
  }
}
