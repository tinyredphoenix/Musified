import 'package:flutter/cupertino.dart';
import 'package:musified/extensions/l10n.dart';
import 'package:musified/utilities/playlist_image_picker.dart';

class EditPlaylistDialog extends StatefulWidget {
  const EditPlaylistDialog({super.key, required this.playlistData});

  final Map playlistData;

  @override
  State<EditPlaylistDialog> createState() => _EditPlaylistDialogState();
}

class _EditPlaylistDialogState extends State<EditPlaylistDialog> {
  late TextEditingController _titleController;
  late TextEditingController _imageUrlController;
  String? _imageBase64;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.playlistData['title'],
    );
    final image = widget.playlistData['image'] as String?;
    if (image != null && image.startsWith('data:')) {
      _imageBase64 = image;
      _imageUrlController = TextEditingController(text: '');
    } else {
      _imageBase64 = null;
      _imageUrlController = TextEditingController(text: image);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await pickImage();
    if (result != null) {
      setState(() {
        _imageBase64 = result;
        _imageUrlController.text = '';
      });
    }
  }

  Map<String, dynamic> _buildResult() {
    return {
      'ytid': widget.playlistData['ytid'],
      'title': _titleController.text,
      'source': widget.playlistData['source'] ?? 'user-created',
      if (_imageBase64 != null)
        'image': _imageBase64
      else if (_imageUrlController.text.isNotEmpty)
        'image': _imageUrlController.text,
      'list': widget.playlistData['list'],
      if (widget.playlistData['createdAt'] != null)
        'createdAt': widget.playlistData['createdAt'],
    };
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text(context.l10n.editPlaylist),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: _titleController,
              placeholder: context.l10n.customPlaylistName,
              prefix: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(CupertinoIcons.textformat, size: 18),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            if (_imageBase64 == null) ...[
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: _imageUrlController,
                placeholder: context.l10n.customPlaylistImgUrl,
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(CupertinoIcons.photo, size: 18),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                onChanged: (_) => setState(() => _imageBase64 = null),
              ),
            ],
            const SizedBox(height: 12),
            if (_imageUrlController.text.isEmpty || _imageBase64 != null) ...[
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _pickImage,
                child: Text(
                  _imageBase64 != null
                      ? context.l10n.imagePicked
                      : context.l10n.pickImageFromDevice,
                  style: const TextStyle(color: Color(0xFFFF2D55), fontSize: 15),
                ),
              ),
              buildImagePreview(
                imageBase64: _imageBase64,
                imageUrl: _imageUrlController.text.isEmpty
                    ? null
                    : _imageUrlController.text,
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context, _buildResult()),
          child: Text(context.l10n.update),
        ),
      ],
    );
  }
}
