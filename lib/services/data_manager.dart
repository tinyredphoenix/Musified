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

import 'package:hive/hive.dart';
import 'package:musify/main.dart' show logger;

// Cache durations for different types of data
const Duration songCacheDuration = Duration(hours: 1, minutes: 30);
const Duration playlistCacheDuration = Duration(hours: 5);
const Duration searchCacheDuration = Duration(days: 1);
const Duration defaultCacheDuration = Duration(days: 2);

// In-memory cache for frequently accessed items
final _memoryCache = <String, _CacheEntry>{};

class _CacheEntry {
  _CacheEntry(this.data, this.timestamp);
  final dynamic data;
  final DateTime timestamp;

  bool isValid(Duration cacheDuration) {
    return DateTime.now().difference(timestamp) < cacheDuration;
  }
}

DateTime? _parseCacheDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

// Maximum number of entries allowed in the memory cache
const int _maxMemoryCacheSize = 500;
const int _memoryCacheTrimSize = 100;

void _setMemoryCacheEntry(String key, _CacheEntry entry) {
  _memoryCache
    ..remove(key)
    ..[key] = entry;
  _trimMemoryCacheIfNeeded();
}

void _touchMemoryCacheEntry(String key) {
  final entry = _memoryCache.remove(key);
  if (entry != null) {
    _memoryCache[key] = entry;
  }
}

void _trimMemoryCacheIfNeeded() {
  if (_memoryCache.length > _maxMemoryCacheSize) {
    final keysToRemove = _memoryCache.keys.take(_memoryCacheTrimSize).toList();
    for (final key in keysToRemove) {
      _memoryCache.remove(key);
    }
  }
}

Future<void> addOrUpdateData<T>(String category, String key, T value) async {
  final _box = await _openBox(category);
  await _box.put(key, value);

  if (category == 'cache') {
    await _box.put('${key}_date', DateTime.now());

    // Update memory cache too
    final cacheKey = '${category}_$key';
    _setMemoryCacheEntry(cacheKey, _CacheEntry(value, DateTime.now()));
  }
}

Future<dynamic> getData(
  String category,
  String key, {
  dynamic defaultValue,
  Duration? cachingDuration,
}) async {
  // Set appropriate cache duration based on key
  cachingDuration ??= _getCacheDurationForKey(key);

  // Check memory cache first
  final cacheKey = '${category}_$key';
  final memCacheEntry = _memoryCache[cacheKey];
  if (memCacheEntry != null && memCacheEntry.isValid(cachingDuration)) {
    _touchMemoryCacheEntry(cacheKey);
    return memCacheEntry.data;
  }
  _trimMemoryCacheIfNeeded();

  final _box = await _openBox(category);
  if (category == 'cache') {
    final cacheIsValid = isCacheValid(_box, key, cachingDuration);
    if (!cacheIsValid) {
      await deleteData(category, key);
      await deleteData(category, '${key}_date');
      return defaultValue;
    }
  }

  final data = await _box.get(key, defaultValue: defaultValue);

  // Store in memory cache for faster access next time
  if (data != null && category == 'cache') {
    final timestamp =
        _parseCacheDate(await _box.get('${key}_date')) ?? DateTime.now();
    _setMemoryCacheEntry(cacheKey, _CacheEntry(data, timestamp));
  }

  return data;
}

Future<void> deleteData(String category, String key) async {
  _memoryCache
    ..remove('${category}_$key')
    ..remove('${category}_${key}_date');

  final _box = await _openBox(category);
  await _box.delete(key);
}

Future<bool> clearCache() async {
  try {
    // Clear memory cache
    _memoryCache.clear();

    final cacheBox = await _openBox('cache');
    await cacheBox.clear();
    return true;
  } catch (e, stackTrace) {
    logger.log('Failed to clear cache', error: e, stackTrace: stackTrace);
    return false;
  }
}

// Clean up old cache entries to prevent excessive storage usage
Future<void> cleanupOldCacheEntries() async {
  try {
    final cacheBox = await _openBox('cache');
    final now = DateTime.now();

    // Get all keys except the ones with _date suffix
    final keys = cacheBox.keys
        .where((k) => !k.toString().endsWith('_date'))
        .toList();

    for (final key in keys) {
      final dateKey = '${key}_date';
      final date = cacheBox.get(dateKey);
      final cacheKey = 'cache_$key';

      if (_parseCacheDate(date) == null) {
        await cacheBox.delete(key);
        await cacheBox.delete(dateKey);
        _memoryCache.remove(cacheKey);
        continue;
      }

      final age = now.difference(_parseCacheDate(date)!);
      // Very old cache entries (older than 2 days) should be removed
      if (age > const Duration(days: 2)) {
        await cacheBox.delete(key);
        await cacheBox.delete(dateKey);
        _memoryCache.remove(cacheKey);
      }
    }
  } catch (e, stackTrace) {
    logger.log(
      'Error cleaning up old cache entries',
      error: e,
      stackTrace: stackTrace,
    );
  }
}

// Check if the cache is still valid based on the caching duration
bool isCacheValid(Box box, String key, Duration cachingDuration) {
  final date = _parseCacheDate(box.get('${key}_date'));
  if (date == null) {
    return false;
  }
  final age = DateTime.now().difference(date);
  return age < cachingDuration;
}

Duration _getCacheDurationForKey(String key) {
  if (key.startsWith('song_') || key.contains('manifest_')) {
    return songCacheDuration;
  } else if (key.startsWith('playlist_') || key.contains('playlistSongs')) {
    return playlistCacheDuration;
  } else if (key.startsWith('search_')) {
    return searchCacheDuration;
  }
  return defaultCacheDuration;
}

Future<Box> _openBox(String category) async {
  if (Hive.isBoxOpen(category)) {
    return Hive.box(category);
  } else {
    return Hive.openBox(category);
  }
}



