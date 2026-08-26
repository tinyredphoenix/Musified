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

final wrappedEnabled = ValueNotifier<bool>(false);
final sponsorBlockSupport = ValueNotifier<bool>(false);

final externalRecommendations = ValueNotifier<bool>(
  // Prefer YouTube-related recommendations for new installs. Existing users
  // retain their explicit setting from Hive.
  _safeBoxGet<bool>('externalRecommendations', true),
);

final useProxy = ValueNotifier<bool>(_safeBoxGet<bool>('useProxy', false));

final audioQualitySetting = ValueNotifier<String>(
  _safeBoxGet<String>('audioQuality', 'high'),
);

final showAudioQualityBadge = ValueNotifier<bool>(
  _safeBoxGet<bool>('showAudioQualityBadge', true),
);

Locale languageSetting = getLocaleFromLanguageCode(
  _safeBoxGet<String>('languageCode', 'en'),
);

int themeModeSetting = _safeBoxGet<int>('themeIndex', 0);

String playlistSortSetting = _safeBoxGet<String>(
  'playlistSortType',
  PlaylistSortType.default_.name,
);

String offlineSortSetting = _safeBoxGet<String>(
  'offlineSortType',
  OfflineSortType.default_.name,
);

Color primaryColorSetting = Color(_safeBoxGet<int>('accentColor', 0xff91cef4));

final shuffleNotifier = ValueNotifier<bool>(
  _safeBoxGet<bool>('shuffleEnabled', false),
);

final repeatNotifier = ValueNotifier<AudioServiceRepeatMode>(
  AudioServiceRepeatMode.values[_safeBoxGet<int>(
    'repeatMode',
    0,
  ).clamp(0, AudioServiceRepeatMode.values.length - 1)],
);

// Non-storage notifiers

var sleepTimerNotifier = ValueNotifier<Duration?>(null);

// Server-Notifiers

final announcementURL = ValueNotifier<String?>(null);

// JioSaavn settings
//
// These previously called `Hive.box('settings')` directly instead of going
// through `_safeBoxGet` like every other notifier in this file. That throws
// a HiveError ("Box not found") if anything reads `.value` before/while Hive
// finishes opening the settings box (or if Phase 1 in main.dart's
// initialisation() ever fails on a given device) - and `jiosaavnEnabled` in
// particular sits right in the song-resolution hot path (checked first, on
// every single song play, before falling back to YouTube), so a stray throw
// here silently kills playback for that call. Routed through the same safe
// helper as everything else for consistency.

final jiosaavnEnabled = ValueNotifier<bool>(
  _safeBoxGet<bool>('jiosaavnEnabled', true),
);

final jiosaavnQuality = ValueNotifier<String>(
  _safeBoxGet<String>('jiosaavnQuality', '320'),
);

final preferredSource = ValueNotifier<String>(
  _safeBoxGet<String>('preferredSource', 'auto'),
);

final downloadSource = ValueNotifier<String>(
  _safeBoxGet<String>('downloadSource', 'best'),
);

final downloadQuality = ValueNotifier<String>(
  _safeBoxGet<String>('downloadQuality', '320'),
);

// YouTube Music sync settings
final ytAutoSyncLikes = ValueNotifier<bool>(
  _safeBoxGet<bool>('ytAutoSyncLikes', true),
);

final ytAutoSyncPlaylists = ValueNotifier<bool>(
  _safeBoxGet<bool>('ytAutoSyncPlaylists', true),
);

final ytReportHistory = ValueNotifier<bool>(
  _safeBoxGet<bool>('ytReportHistory', true),
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
  externalRecommendations.value = settings.get(
    'externalRecommendations',
    // Related YouTube recommendations are the default for new installs.
    // Hive still preserves an existing user's explicit preference.
    defaultValue: true,
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

  ytAutoSyncLikes.value = settings.get('ytAutoSyncLikes', defaultValue: true);
  ytAutoSyncPlaylists.value = settings.get('ytAutoSyncPlaylists', defaultValue: true);
  ytReportHistory.value = settings.get('ytReportHistory', defaultValue: true);
}
