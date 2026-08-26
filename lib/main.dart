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

import 'package:app_links/app_links.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/localization/app_localizations.dart';
import 'package:musify/services/audio_service.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/io_service.dart';
import 'package:musify/services/listening_stats_service.dart';
import 'package:musify/services/logger_service.dart';
import 'package:musify/services/playlist_download_service.dart';
import 'package:musify/services/playlist_sharing.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/services/source_resolver.dart';
import 'package:musify/theme/app_themes.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/language_utils.dart';
import 'package:musify/utilities/playlist_utils.dart';
import 'package:path_provider/path_provider.dart';

MusifyAudioHandler? _audioHandlerInstance;
MusifyAudioHandler get audioHandler {
  final h = _audioHandlerInstance;
  if (h != null) return h;
  throw StateError('audioHandler not initialized yet');
}

bool get isAudioHandlerInitialized => _audioHandlerInstance != null;

final logger = Logger();
final appLinks = AppLinks();

class Musify extends StatefulWidget {
  const Musify({super.key});

  static Future<void> updateAppState(
    BuildContext context, {
    ThemeMode? newThemeMode,
    Locale? newLocale,
    Color? newAccentColor,
    bool? useSystemColor,
  }) async {
    context.findAncestorStateOfType<_MusifyState>()?.changeSettings(
      newThemeMode: newThemeMode,
      newLocale: newLocale,
      newAccentColor: newAccentColor,
      systemColorStatus: useSystemColor,
    );
  }

  @override
  _MusifyState createState() => _MusifyState();
}

class _MusifyState extends State<Musify> with WidgetsBindingObserver {
  void changeSettings({
    ThemeMode? newThemeMode,
    Locale? newLocale,
    Color? newAccentColor,
    bool? systemColorStatus,
  }) {
    setState(() {
      if (newThemeMode != null) {
        themeMode = newThemeMode;
        brightness = getBrightnessFromThemeMode(newThemeMode);
      }
      if (newLocale != null) {
        languageSetting = newLocale;
      }
      if (newAccentColor != null) {
        if (systemColorStatus != null &&
            useSystemColor.value != systemColorStatus) {
          useSystemColor.value = systemColorStatus;
          addOrUpdateData<bool>(
            'settings',
            'useSystemColor',
            systemColorStatus,
          );
        }
        primaryColorSetting = newAccentColor;
      }
    });
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    final platformDispatcher = PlatformDispatcher.instance;

    // This callback is called every time the brightness changes.
    platformDispatcher.onPlatformBrightnessChanged = () {
      if (themeMode == ThemeMode.system) {
        setState(() {
          brightness = platformDispatcher.platformBrightness;
        });
      }
    };

    offlineMode.addListener(_onOfflineModeChanged);

    try {
      LicenseRegistry.addLicense(() async* {
        final license = await rootBundle.loadString(
          'assets/licenses/paytone.txt',
        );
        yield LicenseEntryWithLineBreaks(['paytoneOne'], license);
      });
    } catch (e, stackTrace) {
      logger.log(
        'License Registration Error',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (isAudioHandlerInitialized) {
        listeningStatsService.recordListeningSessionProgress(
          wasPlaying: audioHandler.audioPlayer.playing,
        );
        unawaited(listeningStatsService.flush());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    offlineMode.removeListener(_onOfflineModeChanged);

    Hive.close();
    super.dispose();
  }

  void _onOfflineModeChanged() {
    // Force rebuild when offline mode changes
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = getAppColorScheme(null, null);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: true,
        statusBarBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        statusBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: MaterialApp.router(
        themeMode: themeMode,
        darkTheme: getAppTheme(colorScheme),
        theme: getAppTheme(colorScheme),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: appSupportedLocales,
        locale: languageSetting,
        routerConfig: NavigationManager.router,
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFF121212),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 44),
              const SizedBox(height: 12),
              const Text(
                'Musified Notice',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              SelectableText(
                '${details.exception}\n\n${details.stack?.toString().split('\n').take(12).join('\n') ?? ''}',
                style: const TextStyle(color: Colors.grey, fontSize: 11, fontFamily: 'monospace'),
                textAlign: TextAlign.left,
              ),
            ],
          ),
        ),
      ),
    );
  };

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    logger.log('FlutterError', error: details.exception, stackTrace: details.stack);
  };

  try {
    await initialisation().timeout(const Duration(seconds: 4));
  } catch (e, st) {
    logger.log('initialisation error or timeout: $e', stackTrace: st);
  }

  runApp(const Musify());
}

Future<void> initialisation() async {
  // Phase 1: Hive + settings (never let this kill the app)
  try {
    await Hive.initFlutter();

    await Future.wait([
      Hive.openBox('settings'),
      Hive.openBox('user'),
      Hive.openBox('userNoBackup'),
      Hive.openBox('cache'),
    ]);
    // Restore persisted settings into ValueNotifiers + theme globals
    reloadSettingsFromStorage();
    syncThemeFromSettings();
    reloadSongLibraryStateFromStorage();
    reloadPlaylistsStateFromStorage();
    OfflinePlaylistService().reloadOfflinePlaylistsFromStorage();
  } catch (e, stackTrace) {
    logger.log('Hive Initialization Error', error: e, stackTrace: stackTrace);
  }

  // Phase 2: directories (must succeed for offline)
  try {
    applicationDirPath = (await getApplicationDocumentsDirectory()).path;
    await FilePaths.ensureDirectoriesExist();
  } catch (e, stackTrace) {
    logger.log('Directory init error', error: e, stackTrace: stackTrace);
    // Fallback to temp dir so app still launches
    try {
      applicationDirPath = (await getApplicationDocumentsDirectory()).path;
    } catch (_) {
      applicationDirPath = '/tmp';
    }
  }

  // Phase 3: audio + saavn (isolated so router always initializes)
  try {
    await SourceResolver().init();
  } catch (e, stackTrace) {
    logger.log('SourceResolver init error', error: e, stackTrace: stackTrace);
  }

  try {
    _audioHandlerInstance = await AudioService.init(
      builder: MusifyAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.tinyred.musified',
        androidNotificationChannelName: 'Musified',
        androidNotificationIcon: 'drawable/ic_launcher_foreground',
        androidShowNotificationBadge: true,
        androidStopForegroundOnPause: false,
      ),
    );
  } catch (e, stackTrace) {
    logger.log('AudioService init error', error: e, stackTrace: stackTrace);
    // Fallback: create handler directly so UI never sees a LateError.
    try {
      _audioHandlerInstance = MusifyAudioHandler();
      logger.log('Created fallback MusifyAudioHandler without AudioService');
    } catch (e2, st2) {
      logger.log('Fallback handler also failed', error: e2, stackTrace: st2);
    }
  }
  if (_audioHandlerInstance == null) {
    try {
      _audioHandlerInstance = MusifyAudioHandler();
    } catch (e, st) {
      logger.log('Last-resort handler failed', error: e, stackTrace: st);
    }
  }

  // Phase 4: router - MUST always run
  try {
    NavigationManager.instance;
  } catch (e, stackTrace) {
    logger.log('Router init error', error: e, stackTrace: stackTrace);
  }

  // Phase 5: deep links
  try {
    appLinks.uriLinkStream.listen(
      handleIncomingLink,
      onError: (err) {
        logger.log('URI link error:', error: err);
      },
    );
  } on PlatformException {
    logger.log('Failed to get initial uri');
  } catch (e, stackTrace) {
    logger.log('AppLinks listen error', error: e, stackTrace: stackTrace);
  }
}

void handleIncomingLink(Uri? uri) async {
  if (uri == null || uri.scheme != 'musify' || uri.host != 'playlist') return;

  if (uri.pathSegments.length < 2 || uri.pathSegments[0] != 'custom') return;

  try {
    final encodedPlaylist = uri.pathSegments[1];
    final playlist = await PlaylistSharingService.decodeAndExpandPlaylist(
      encodedPlaylist,
    );

    if (playlist == null) {
      _showPlaylistError();
      return;
    }

    // Ensure the incoming playlist has a unique id so it can be removed later
    if (playlist['ytid'] == null || playlist['ytid'].toString().isEmpty) {
      playlist['ytid'] = PlaylistUtils.generateCustomPlaylistId();
    }

    // Check for duplicate by title and song ytids
    final incomingYtids = (playlist['list'] as List<dynamic>)
        .map((s) => s['ytid'].toString())
        .toList();

    final isDuplicate = PlaylistUtils.playlistExists(
      playlist,
      incomingYtids,
      userCustomPlaylists.value,
    );

    if (isDuplicate) {
      showToast(
        NavigationManager().context,
        NavigationManager().context.l10n.playlistAlreadyExists,
      );
    } else {
      userCustomPlaylists.value = [...userCustomPlaylists.value, playlist];
      unawaited(
        addOrUpdateData<List>(
          'user',
          'customPlaylists',
          userCustomPlaylists.value,
        ),
      );
      showToast(
        NavigationManager().context,
        '${NavigationManager().context.l10n.addedSuccess}!',
      );
    }
  } catch (e) {
    _showPlaylistError();
  }
}

void _showPlaylistError() {
  showToast(
    NavigationManager().context,
    NavigationManager().context.l10n.failedToLoadPlaylist,
  );
}
