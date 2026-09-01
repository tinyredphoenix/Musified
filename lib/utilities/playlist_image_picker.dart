import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:musified/theme/app_themes.dart';

Future<String?> pickImage() async {
  final file = await FilePicker.pickFile(type: FileType.image);

  if (file != null) {
    final bytes = await file.readAsBytes();
    String? mimeType;

    final fileName = file.name;
    final extensionStart = fileName.lastIndexOf('.') + 1;
    if (extensionStart > 0 && extensionStart < fileName.length) {
      switch (fileName.substring(extensionStart).toLowerCase()) {
        case 'jpg':
        case 'jpeg':
          mimeType = 'image/jpeg';
          break;
        case 'png':
          mimeType = 'image/png';
          break;
        case 'gif':
          mimeType = 'image/gif';
          break;
        case 'bmp':
          mimeType = 'image/bmp';
          break;
        case 'webp':
          mimeType = 'image/webp';
          break;
      }
    }

    mimeType ??= 'image/jpeg';
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }

  return null;
}

Widget buildImagePreview({
  String? imageBase64,
  String? imageUrl,
  double width = 80,
  double height = 80,
}) {
  Widget? imageWidget;

  if (imageBase64 != null) {
    try {
      final base64Data = imageBase64.split(',').last;
      final bytes = base64Decode(base64Data);
      imageWidget = Image.memory(
        bytes,
        width: width,
        height: height,
        fit: BoxFit.cover,
      );
    } catch (_) {
      imageWidget = null;
    }
  } else if (imageUrl != null && imageUrl.isNotEmpty) {
    imageWidget = Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      cacheWidth: (width * 2).round(),
      cacheHeight: (height * 2).round(),
      errorBuilder: (context, _, __) => const Icon(
        CupertinoIcons.photo,
        color: CupertinoColors.systemGrey,
      ),
    );
  }

  if (imageWidget == null) return const SizedBox.shrink();

  return Padding(
    padding: const EdgeInsets.only(top: 12),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: imageWidget,
    ),
  );
}

Widget buildImagePickerRow(
  BuildContext context,
  Function() onPickImage,
  bool isImagePicked,
) {
  final isDark = isAppDarkMode(context);

  return SizedBox(
    width: double.infinity,
    child: CupertinoButton(
      color: musifiedSecondarySurface(isDark),
      borderRadius: BorderRadius.circular(12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onPressed: onPickImage,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isImagePicked
                ? CupertinoIcons.checkmark_circle_fill
                : CupertinoIcons.photo_on_rectangle,
            size: 20,
            color: const Color(0xFFFF2D55),
          ),
          const SizedBox(width: 8),
          Text(
            isImagePicked ? 'Image Selected' : 'Choose Image from Files',
            style: TextStyle(
              color: isDark ? CupertinoColors.white : CupertinoColors.black,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}
