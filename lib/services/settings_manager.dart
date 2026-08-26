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

import 'package:audio_service/audio_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/screens/playlist_page.dart';
import 'package:musify/screens/user_songs_page.dart';
import 'package:musify/utilities/language_utils.dart';

T _safeBoxGet<T>(String key, T defaultValue) {
  try {
    if (!Hive.isBoxOpen('settings')) return defaultValue;
    final v = Hive.box('settings').get(key, defaultValue: defaultValue);
    if (v is T) return v;
    // Handle nullable bool case where Hive returns null
    if (v == null && null is T) return v as T;
    return defaultValue;
  } catch (_) {
    return defaultValue;
  }
}

List<double> _readEqualizerGainsSafe() {
  try {
    if (!Hive.isBoxOpen('settings')) return <double>[];
    final raw = Hive.box('settings')
        .get('equalizerBandGains', defaultValue: const <dynamic>[]);
    if (raw is List) {
      return raw.map((value) => value is num ? value.toDouble() : 0.0).toList();
    }
  } catch (_) {}
  return <double>[];
}

// Preferences - safely initialized even before Hive is open.
// After Hive opens, reloadSettingsFromStorage() restores persisted values.

final shouldWeCheckUpdates = ValueNotifier<bool?>(
  _safeBoxGet<bool?>('shouldWeCheckUpdates', null),
);

final playNextSongAutomatically = ValueNotifier<bool>(
  _safeBoxGet<bool>('playNextSongAutomatically', false),
);

final useSystemColor = ValueNotifier<bool>(
  _safeBoxGet<bool>('useSystemColor', true),
);

final usePureBlackColor = ValueNotifier<bool>(
  _safeBoxGet<bool>('usePureBlackColor', false),
);

final offlineMode = ValueNotifier<bool>(
  _safeBoxGet<bool>('offlineMode', false),
);

final wrappedEnabled = ValueNotifier<bool>(
  _safeBoxGet<bool>('wrappedEnabled', true),
);

final sponsorBlockSupport = ValueNotifier<bool>(
  _safeBoxGet<bool>('sponsorBlockSupport', false),
);

final externalRecommendations = ValueNotifier<bool>(
  _safeBoxGet<bool>('externalRecommendations', false),
);

final useProxy = ValueNotifier<bool>(
  _safeBoxGet<bool>('useProxy', false),
);

final audioQualitySetting = ValueNotifier<String>(
  _safeBoxGet<String>('audioQuality', 'high'),
);

final showAudioQualityBadge = ValueNotifier<bool>(
  _safeBoxGet<bool>('showAudioQualityBadge', true),
);

List<double> _readEqualizerGains() => _readEqualizerGainsSafe();

final equalizerEnabled = ValueNotifier<bool>(
  _safeBoxGet<bool>('equalizerEnabled', false),
);

final equalizerBandGains = ValueNotifier<List<double>>(_readEqualizerGainsSafe());

Locale languageSetting = getLocaleFromLanguageCode(
  _safeBoxGet<String>('languageCode', 'en'),
);

int themeModeSetting = _safeBoxGet<int>('themeIndex', 0);

String playlistSortSetting =
    _safeBoxGet<String>('playlistSortType', PlaylistSortType.default_.name);

String offlineSortSetting =
    _safeBoxGet<String>('offlineSortType', OfflineSortType.default_.name);

Color primaryColorSetting = Color(
  _safeBoxGet<int>('accentColor', 0xff91cef4),
);

final shuffleNotifier = ValueNotifier<bool>(
  _safeBoxGet<bool>('shuffleEnabled', false),
);

final repeatNotifier = ValueNotifier<AudioServiceRepeatMode>(
  AudioServiceRepeatMode.values[_safeBoxGet<int>('repeatMode', 0).clamp(
    0,
    AudioServiceRepeatMode.values.length - 1,
  )],
);

// Non-storage notifiers

var sleepTimerNotifier = ValueNotifier<Duration?>(null);

// Server-Notifiers

final announcementURL = ValueNotifier<String?>(null);

// JioSaavn settings

final jiosaavnEnabled = ValueNotifier<bool>(
  Hive.box('settings').get('jiosaavnEnabled', defaultValue: true),
);

final jiosaavnQuality = ValueNotifier<String>(
  Hive.box('settings').get('jiosaavnQuality', defaultValue: '320'),
);

final preferredSource = ValueNotifier<String>(
  Hive.box('settings').get('preferredSource', defaultValue: 'auto'),
);

final downloadSource = ValueNotifier<String>(
  Hive.box('settings').get('downloadSource', defaultValue: 'best'),
);

final downloadQuality = ValueNotifier<String>(
  Hive.box('settings').get('downloadQuality', defaultValue: '320'),
);

void reloadSettingsFromStorage() {
  final settings = Hive.box('settings');

  shouldWeCheckUpdates.value = settings.get(
    'shouldWeCheckUpdates',
    defaultValue: null,
  );
  playNextSongAutomatically.value = settings.get(
    'playNextSongAutomatically',
    defaultValue: false,
  );
  useSystemColor.value = settings.get('useSystemColor', defaultValue: true);
  usePureBlackColor.value = settings.get(
    'usePureBlackColor',
    defaultValue: false,
  );
  offlineMode.value = settings.get('offlineMode', defaultValue: false);
  wrappedEnabled.value = settings.get('wrappedEnabled', defaultValue: true);
  sponsorBlockSupport.value = settings.get(
    'sponsorBlockSupport',
    defaultValue: false,
  );
  externalRecommendations.value = settings.get(
    'externalRecommendations',
    defaultValue: false,
  );
  useProxy.value = settings.get('useProxy', defaultValue: false);
  audioQualitySetting.value = settings.get(
    'audioQuality',
    defaultValue: 'high',
  );
  showAudioQualityBadge.value = settings.get(
    'showAudioQualityBadge',
    defaultValue: false,
  );
  equalizerEnabled.value = settings.get(
    'equalizerEnabled',
    defaultValue: false,
  );
  equalizerBandGains.value = _readEqualizerGains();

  final restoredThemeIndex = settings.get('themeIndex', defaultValue: 0);
  if (restoredThemeIndex is int) themeModeSetting = restoredThemeIndex;

  final restoredLanguageCode = settings.get('languageCode', defaultValue: 'en');
  if (restoredLanguageCode is String) {
    languageSetting = getLocaleFromLanguageCode(restoredLanguageCode);
  }

  final restoredPlaylistSort = settings.get(
    'playlistSortType',
    defaultValue: PlaylistSortType.default_.name,
  );
  if (restoredPlaylistSort is String) {
    playlistSortSetting = restoredPlaylistSort;
  }

  final restoredOfflineSort = settings.get(
    'offlineSortType',
    defaultValue: OfflineSortType.default_.name,
  );
  if (restoredOfflineSort is String) {
    offlineSortSetting = restoredOfflineSort;
  }

  final restoredAccentColor = settings.get(
    'accentColor',
    defaultValue: 0xff91cef4,
  );
  if (restoredAccentColor is int) {
    primaryColorSetting = Color(restoredAccentColor);
  }

  shuffleNotifier.value = settings.get('shuffleEnabled', defaultValue: false);
  final restoredRepeatIndex = settings.get('repeatMode', defaultValue: 0);
  if (restoredRepeatIndex is int &&
      restoredRepeatIndex >= 0 &&
      restoredRepeatIndex < AudioServiceRepeatMode.values.length) {
    repeatNotifier.value = AudioServiceRepeatMode.values[restoredRepeatIndex];
  }

  jiosaavnEnabled.value = settings.get('jiosaavnEnabled', defaultValue: true);
  jiosaavnQuality.value = settings.get('jiosaavnQuality', defaultValue: '320');
  preferredSource.value = settings.get('preferredSource', defaultValue: 'auto');
  downloadSource.value = settings.get('downloadSource', defaultValue: 'best');
  downloadQuality.value = settings.get('downloadQuality', defaultValue: '320');
}
