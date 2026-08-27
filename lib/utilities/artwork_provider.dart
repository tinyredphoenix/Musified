import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class ArtworkProvider {
  ArtworkProvider._();

  static const int _maxEntries = 80;
  static final Map<String, ImageProvider> _cache = {};

  static ImageProvider get(String artwork) {
    if (artwork.isEmpty) throw ArgumentError('artwork must not be empty');

    final cached = _cache.remove(artwork);
    if (cached != null) {
      _cache[artwork] = cached;
      return cached;
    }

    late ImageProvider provider;
    try {
      if (artwork.startsWith('http')) {
        provider = CachedNetworkImageProvider(artwork);
      } else if (artwork.startsWith('data:image')) {
        final commaIdx = artwork.indexOf(',');
        if (commaIdx == -1) throw Exception('invalid base64 image');
        final bytes = base64Decode(artwork.substring(commaIdx + 1));
        provider = MemoryImage(bytes);
      } else if (!kIsWeb &&
          (artwork.startsWith('file://') || artwork.startsWith('/'))) {
        final path = artwork.replaceFirst('file://', '');
        provider = FileImage(File(path));
      } else {
        provider = AssetImage(artwork);
      }
    } catch (_) {
      provider = const AssetImage('assets/placeholder.png');
    }

    _cache[artwork] = provider;
    _trimIfNeeded();
    return provider;
  }

  static void _trimIfNeeded() {
    while (_cache.length > _maxEntries) {
      _cache.remove(_cache.keys.first);
    }
  }

  static void clearCache() => _cache.clear();
}
