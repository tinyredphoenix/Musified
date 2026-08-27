import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:musified/extensions/l10n.dart';
import 'package:musified/localization/app_localizations.dart';
import 'package:musified/services/audio_service.dart';
import 'package:musified/services/common_services.dart';
import 'package:musified/services/data_manager.dart';
import 'package:musified/services/io_service.dart';
import 'package:musified/services/logger_service.dart';
import 'package:musified/services/playlist_download_service.dart';
import 'package:musified/services/playlist_sharing.dart';
import 'package:musified/services/playlists_manager.dart';
import 'package:musified/services/router_service.dart';
import 'package:musified/services/settings_manager.dart';
import 'package:musified/services/source_resolver.dart';
import 'package:musified/services/youtube_auth_service.dart';
import 'package:musified/services/youtube_music_sync_service.dart';
import 'package:musified/theme/app_themes.dart';
import 'package:musified/utilities/flutter_toast.dart';
import 'package:musified/utilities/language_utils.dart';
import 'package:musified/utilities/playlist_utils.dart';
import 'package:path_provider/path_provider.dart';

MusifiedAudioHandler? _audioHandlerInstance;
MusifiedAudioHandler get audioHandler {
  final h = _audioHandlerInstance;
  if (h != null) return h;
  throw StateError('audioHandler not initialized yet');
}

bool get isAudioHandlerInitialized => _audioHandlerInstance != null;

final logger = Logger();
final appLinks = AppLinks();

class MusifiedApp extends StatefulWidget {
  const MusifiedApp({super.key});

  static Future<void> updateAppState(
    BuildContext context, {
    ThemeMode? newThemeMode,
    Locale? newLocale,
    Color? newAccentColor,
    bool? useSystemColor,
  }) async {
    context.findAncestorStateOfType<_MusifiedAppState>()?.changeSettings(
      newThemeMode: newThemeMode,
      newLocale: newLocale,
      newAccentColor: newAccentColor,
      systemColorStatus: useSystemColor,
    );
  }

  @override
  _MusifiedAppState createState() => _MusifiedAppState();
}

typedef Musify = MusifiedApp;

class _MusifiedAppState extends State<MusifiedApp> with WidgetsBindingObserver {
  void changeSettings({
    ThemeMode? newThemeMode,
    Locale? newLocale,
    Color? newAccentColor,
    bool? systemColorStatus,
  }) {
    setState(() {
      if (newThemeMode != null) {
        themeMode = newThemeMode;
        themeModeSetting.value = newThemeMode.index;
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

    logger.log('Musified started');

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    offlineMode.addListener(_onOfflineModeChanged);
    themeModeSetting.addListener(_onThemeChanged);
    usePureBlackColor.addListener(_onThemeChanged);

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
    if (state != AppLifecycleState.resumed) return;
    if (!isAudioHandlerInitialized) return;
    unawaited(audioHandler.resyncAfterForeground());
  }

  @override
  void didChangePlatformBrightness() {
    if (themeMode != ThemeMode.system) return;
    final next = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    if (brightness == next) return;
    setState(() {
      brightness = next;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    offlineMode.removeListener(_onOfflineModeChanged);
    themeModeSetting.removeListener(_onThemeChanged);
    usePureBlackColor.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onOfflineModeChanged() {
    setState(() {});
  }

  void _onThemeChanged() {
    syncThemeFromSettings();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final overlayBrightness = getBrightnessFromThemeMode(themeMode);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: const Color(0x00000000),
        systemNavigationBarColor: const Color(0x00000000),
        systemNavigationBarContrastEnforced: true,
        statusBarBrightness: overlayBrightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        statusBarIconBrightness: overlayBrightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarIconBrightness: overlayBrightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: CupertinoApp.router(
        theme: buildCupertinoTheme(brightness: overlayBrightness),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
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
  configureImageMemoryBudget();

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Container(
      color: const Color(0xFF121212),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_triangle,
                color: CupertinoColors.systemRed,
                size: 44,
              ),
              const SizedBox(height: 12),
              const Text(
                'Musified Notice',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${details.exception}\n\n${details.stack?.toString().split('\n').take(12).join('\n') ?? ''}',
                style: const TextStyle(
                  color: CupertinoColors.systemGrey,
                  fontSize: 11,
                  fontFamily: 'monospace',
                  decoration: TextDecoration.none,
                ),
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
    logger.log(
      'FlutterError',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  try {
    // NOTE: this used to be capped at 4 seconds. On a real iOS device
    // (especially cold-start / first launch / debug builds), opening the
    // Hive boxes + AudioService.init() (which does real native work: audio
    // session config, MPRemoteCommandCenter/MPNowPlayingInfoCenter setup)
    // can legitimately take longer than that. When the old 4s timeout fired,
    // runApp() was called while `_audioHandlerInstance` was still null, so
    // any UI built in that window (e.g. tapping play) would find the player
    // "not ready" - looking exactly like songs silently refusing to play
    // right after opening the app. The slow AudioService.init() call itself
    // is now bounded (see Phase 3 below) so 12s here is just a last-resort
    // safety net, not something we expect to actually hit.
    await initialisation().timeout(const Duration(seconds: 12));
    unawaited(cleanupOldCacheEntries());
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
      Hive.openBox('youtube_auth'),
    ]);
    // Restore persisted settings into ValueNotifiers + theme globals
    reloadSettingsFromStorage();
    syncThemeFromSettings();
    reloadSongLibraryStateFromStorage();
    reloadPlaylistsStateFromStorage();
    OfflinePlaylistService().reloadOfflinePlaylistsFromStorage();
    // Restore YouTube Music session if previously signed in
    YouTubeAuthService().restoreSession();
    unawaited(YouTubeMusicSyncService().initialize());
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
    // Bounded so a slow/stuck native AudioService setup can never stall the
    // whole app: if it doesn't finish in time we fall through to the plain
    // MusifyAudioHandler() below (no system media integration, but songs
    // still play), instead of leaving `_audioHandlerInstance` null forever.
    _audioHandlerInstance = await AudioService.init(
      builder: MusifiedAudioHandler.new,
      config: const AudioServiceConfig(
        artDownscaleWidth: 512,
        artDownscaleHeight: 512,
        preloadArtwork: true,
        fastForwardInterval: Duration(seconds: 15),
        rewindInterval: Duration(seconds: 15),
      ),
    ).timeout(const Duration(seconds: 9));
  } catch (e, stackTrace) {
    logger.log('AudioService init error', error: e, stackTrace: stackTrace);
    try {
      _audioHandlerInstance = MusifiedAudioHandler();
      logger.log('Created fallback MusifiedAudioHandler without AudioService');
    } catch (e2, st2) {
      logger.log('Fallback handler also failed', error: e2, stackTrace: st2);
    }
  }
  if (_audioHandlerInstance == null) {
    try {
      _audioHandlerInstance = MusifiedAudioHandler();
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
  if (uri == null || (uri.scheme != 'musified' && uri.scheme != 'musify') || uri.host != 'playlist') return;

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
