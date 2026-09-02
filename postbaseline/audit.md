# Postbaseline Audit — Musified (fresh, 2026-09-02)

*Root* `/Users/naman/Documents/RANDOM/ytmusic/Musified` — *Version* `pubspec.yaml:1` `2.3.0+35` `sdk >=3.12.0` — *Scope* 469 filtered files (excludes `.git/.dart_tool/build/pubspec.lock/.DS_Store`; prior audits ignored) — *Method* fresh glob + Read per-file + import linkage parse — *Sub-agents* 3 parallel exhaustive scans (services/utils, screens/widgets, packages/iOS). *No prior audit files consulted.*

---

## 1. Executive Summary

Musified is a Flutter `musified` (`pubspec.yaml:1`) personal iOS streaming player (JioSaavn 320k + YouTube/InnerTube + `just_audio/AVPlayer`, `audio_service`, `hive`, `go_router 17.5`, `webview_flutter`). Single-tenant local app: Hive 5 boxes `settings/user/userNoBackup/cache/youtube_auth/saavn_match_cache`, offline `tracks/*.m4a` + `artworks/*.jpg` in `applicationDirPath` (`lib/services/io_service.dart:15`), YouTube Music sync via `WEB_REMIX 1.20240101`, sole InnerTube client `VISIONOS 1.02` synced from `yt-dlp`.

**Fresh verdict (no prior bias):** 4.6/10 — happy-path playback + home/playlist works; under stress (rapid skip, offline toggle, large catalog, background download) races, cache staleness, and pool/socket pressure surface. Security surface plaintext cookies/`UIFileSharingEnabled true`, MITM via `badCertificateCallback=>true` on proxied googlevideo.

---

## 2. Architecture (fresh trace)

```
main() `lib/main.dart:202` (467L)
  → Hive.initFlutter → await 5 boxes → reloadSettingsFromStorage() + reloadSongLibraryState + Ytdlp ensureLoaded + YouTubeAuth restore + MusicSync.initialize
  → applicationDirPath = getApplicationDocumentsDirectory → FilePaths.ensureDirectoriesExist
  → SourceResolver().init
  → AudioService.init(MusifiedAudioHandler.new, artDownscale 512, fastForward 15s) .timeout 9s → fallback plain MusifiedAudioHandler (still plays, no system media keys)
  → NavigationManager.instance (`lib/services/router_service.dart:27` 377L) StatefulShell 4 tabs
  → AppLinks getInitialLink().then(handleIncomingLink) + uriLinkStream.listen + _showPlaylistError

MusifiedApp `lib/main.dart:72` → CupertinoApp.router
  build: AnnotatedRegion(SystemUiOverlayStyle transparent) + CupertinoTheme `buildCupertinoTheme(brightness: overlayBrightness)` + AppLocalizations
  observers: offlineMode/themeModeSetting/usePureBlackColor → setState + syncThemeFromSettings + refreshRouter (manual)
  lifecycle: didChangeAppLifecycleState → audioHandler.resyncAfterForeground

audioHandler `lib/services/audio/musified_audio_handler.dart:29` (2698L) hub `lib/services/audio/audio_handler_hub.dart:49` (queue + preload)
  Streams: positionDataStream combineLatest4(position, buffered, duration?, mediaItem) → distinct threshold 250ms
           playbackStateStream distinct(bucket)×heartbeat 1s → PlaybackState {playing, processingState, queueIndex, buffered, speed}
           fullPlayerStateStream combineLatest4(playbackState, queue, positionData, mediaItem.distinct) throttle 120ms
  Session: AudioSession.music() + interruption (duck 0.5 / pause) + becomingNoisy pause
  Queue ops: via AudioQueueController (pure), indices + loadingKey `ytid/entryId`, history 50
  Playback: coordinator resolveOffline → getPlaybackUrl (pre-warmed→cached→fetch 36s) → AudioPlaybackInstall.buildSource (File vs URI + googlevideo UA + HE-AAC Clipping) → setAudioSources(preload: isOffline) 6s/12s → play()

Search: lib/screens/search_page.dart:391 debounce 300ms suggestions vs Future.wait[songs, artists, playlists] 8-cap

Theme: lib/theme/app_themes.dart:129 + musified_style.dart:135 OLED #000000 vs elevated #121214; surfaces musifiedCanvas/Card/Secondary hover; helpers branch on usePureBlackColor.

Router: `router_service.dart:27` parentNavigatorKey + 4 tab keys, StatefulShellRoute indexedStack home/search/library/settings, redirect offline blocks, transitions Fade 180 / Slide 0.06 220.
```

*DI:* global singletons/imports (`main.dart` re-exports `logger`, `audioHandler` 39 callers, `theme/app_themes` 42 callers) — no repository/VM.

---

## 3. Per-Module Notes (fresh)

### 3.1 Entry `lib/main.dart:467`
Role above. ErrorWidget OLED branch, `ValueNotifier<bool> audioHandlerReady`. Deeplink musified|musify://playlist/custom/<b64> length ≤65536 deduped via PlaylistUtils. Export `logger`.

### 3.2 Services `/audio/*` (12)
- `musified_audio_handler` central orchestrator: `_setupEventSubscriptions` 7 streams, `LoopMode.off`, `setShuffleModeEnabled`, gapless disabled (returns current), sleepTimer `expired/endOfSong` flags.
- Leaves: `audio_queue_state 57L` loadingKey race guard; `audio_queue_controller 161L` insert/reorder/remove index math; `audio_preload_*` lookahead 1 maxConcurrent 1 8s fetch, `activeCount` + sets, `isUsableYoutube*` validation; `audio_playback_coordinator 574L` 3s `isPlayableOfflineFile 8192 bytes`; `audio_playback_install 125L` File.exists + HE-AAC halving; `audio_completion_coordinator 338L` 450ms near-end window + 5-min error window 3 strikes.

### 3.3 Core domain
- `common_services 1545L`: `_cacheValidationDuration=songCacheDuration 1h30`, `_headRevalidateAge 30m`, HEAD 4s fallback Range `bytes=0-1` (mis-treats redirect 200 as alive), `_selectedAudioStreams` 50 LRU, cache keys `song_<id>_<quality>_<source>_url+_meta`, offline sets synced O(1), `makeSongOffline` pipe + artwork 15s, recents cap 100.
- `source_resolver 186L`: Hive `saavn_match_cache` 1500, `TrackMatcher` queries title+artist / title-only, JioSaavn 5s/10s.
- `jiosaavn_service 147L`: `search.getResults` 5s iPhone UA, `indexOf('{')` scan fragile, DES ECB key `38346591` replace `_(\d+).mp4`→`_q.mp4`.
- `data_manager 274L`: TTLs per prefix (`song→1h30`, `playlist→5h`, `search→1d` else 2d), `_memoryCache` 200 trim 50, image budget 48MB/120, `putAll` atomic for `cache` only, cleanup 2 days.
- `io_service 40L`: `sanitizeStorageSongId` `^[a-zA-Z0-9_-]{11}$` else `_` + cap64, used by `tracks/*.m4a`, `artworks/*.jpg`.
- `artist_service 983L`: verified fast-path + alias search `searchArtists`, profile `getArtistProfile`, catalog `getArtistCatalogFromProfile` batched 6, dedupe 2 passes, thumbnail `=w*-h*→=w544-h544`, timeouts 12/25s, caches `search_music_artists_v<ver>_l<limit>_<q>`, `artist_profile_v5`, `artist_catalog_v16`, serialize via Completer tails.
- `lyrics_manager 231L`: 20+ `replaceAll` title cleaners, `lrclib.net/api/get+search` 4s×2, `lyrics.ovh` 10s, `paroles.net` HTML parse `.song-text`, slug normalize.
- `playlists_manager 1609L`: `playlists = [...playlistsDB(+96), ...albumsDB(+130)]` merged, `userPlaylists/userCustomPlaylists/userLikedPlaylists/userPlaylistFolders/pinnedPlaylistIds/onlinePlaylists(200 cap)`, `getPlaylistInfoForWidget` routing (custom `customId-`, `MPRE` release, offline cache, YouTube `playlists.get`+`getVideos`).

### 3.4 Network/YouTube sync
- `youtube_client 4L`: `YoutubeExplode()` direct singleton.
- `youtube_auth_service 191L`: Hive `youtube_auth:cookies` requires SAPISID, `SAPISIDHASH <ts>_<sha1("$ts $sapisid https://music.youtube.com")>` via `crypto`, profile via `account_menu` `WEB_REMIX 1.20230508.01.00`.
- `youtube_music_sync_service 774L`: browse `FEmusic_charts/explore/liked_videos/playlists/home`, auth→public fallback, parse `musicResponsiveListItemRenderer`/`musicTwoRowItemRenderer` continuation, trending cap20, paginate 25, `reportSongPlayed` via `/player`→`playbackTracking.videostatsPlaybackUrl`+`cpn 16` fmt251, liked sync patches, endpoints `/browse/like/edit_playlist/create/player/next`.
- `ytdlp_client_sync 395L`: built-in `VISIONOS` payload, `syncFromYtdlp` GET `raw.githubusercontent.com/yt-dlp/.../_base.py` 25s, regex `visionos \{` + brace match `_quotedField`, persist `youtubeVisionOsClient/at/commit`, GitHub commits API 10s, usable check `VISIONOS+version+apiUrl`.
- `playlist_sharing 93L`: compact `{title,image,list:[ytid]}`→b64url, expand concurrency 5 `ytClient.videos.get`→`returnSongLayout`, max200.
- `clients.dart` → `ytdlp_sync` stream clients helper (visionOs only).

### 3.5 Screens (12)
- Home 487L: 5 shelves (ValueListenableBuilder each, 25 cap, horizontal 140, refresh `fullSync` if signedIn, haptics).
- BottomNavigation 230L: `PopScope` back, `AnimatedBuilder` merge offlineMode|usePureBlackColor, barBg `#B3`, blur25, `Stream<Map>.distinct()` for bottom padding 54 vs 70+padding, hides Search offline.
- Search 391L: `_debounce` 300ms suggestions 8, `Future.wait` 3 sources with `_latestSearchRequest` stale guard, history chips Wrap `musifiedElevatedSurface`, max20.
- Library 289L: `AnimatedBuilder` merge 9 listenables, top 3 bars (Downloaded/Favorite/Recents) + YouTube signedIn horizontal cubes 140 + custom lists.
- Playlist 665L: `PlaylistSortType` + `_originalPlaylistList` backup, `CupertinoNavigationBar`, `PlaylistHeader+PlaylistActionButtons`, search filter via `filterSongsByQuery`, ValueKey playlist…, share b64url clipboard, Edit updates `userCustomPlaylists`/`userPlaylistFolders` + `syncOfflinePlaylistMetadata`.
- Artist 482L: generation guard `_artistLoadGeneration`, `AsyncLoader` vaults Stale, `ValueNotifier _isLoadingCatalog`, deduped `_catalogFuture`, shelves Horizontal.
- NowPlaying 276L: `FlipCardController`, adaptive Desktop `Row` vs Mobile `Column` vs landscape, grabber 36×5, isLive hides controls, slide modal from MiniPlayer.
- UserSongs 358L: `OfflineSortType` + dateAdded desc, synthesized playlist `{source:user-created}`.
- Settings 892L: Stateless + ValueListenableBuilders: Appearance (System/Light/Dark AnimatedContainer), YouTube Sync (avatar letter, sign-in via WebView), Playback (preferredSource, VISIONOS revision/sync 1.20240101, JioSaavn switch), Storage (clear cache/history), About logs.
- Logs 81L: `ListenableBuilder(logger)` ListView split `\n`, Menlo 12.
- PlaylistFolder 315L: `ValueListenableBuilder(folders)`, offline filtering, ellipsis action sheet, picker sheet `movePlaylistToFolder`.
- YouTubeAuthWebView 115L: `WebViewController` accounts.google.com→music.youtube.com, cookie merge `youtube.com/music.youtube.com/google.com`, requires SAPISID.

### 3.6 Widgets (46)
MiniPlayer 259L blur20 progress 2h, SongTile 153L playing ValueListenableBuilder, PlaylistBar 311L card margin6 actionSheet pin/like/offline, PlaylistCube 68L, SongArtwork 101L DPR clamp64-800, CustomBar 101L, ArtistBar 125L circle, ArtistShelf 128L cubeSize 120-180, PlaylistArtwork 50L try/catch, NullArtwork 77L badge, Spinner 15L, FlipCard 112L crossfade 280ms, Marquee 106L loop linear 6s, Confirmation 47L, NowPlaying controls 501L + artwork 320L + bottomActions 388L + sourcePicker 247L + syncedLyrics 481L + lyrics/* 7, playlist_page 7 buttons/headers/empty.

### 3.7 Theme (3)
`app_themes` 129L caches `_themeModeCached/_brightnessCached`, helpers branch on `usePureBlackColor`; `musified_style` 135L spacing `4-32`, radii `8-28`, dark `#000000/#121214/#1C1C1E/#2C2C2E` vs light `#F2F2F7/...`, fonts `.SF Pro`, `hairlineBorder`; `app_colors` 14L list 10 Apple colors.

### 3.8 Utilities (19)
`app_utils` 285L `kHeAacItags {139,599,600}`, `parseSongDuration`, `isPlayableYoutubeStreamUrl`, `isUsableYoutubePlaybackUrl` expire+45s, `selectAudioOnlyStreamForQuality` AAC-LC → HE-AAC fallback, sanitize; `artwork_provider` 55L LRU80; `async_loader` 59L; `formatter` 85L; `mediaitem` 193L `mapToMediaItem` upgradeArtwork; `track_matcher` 159L Jaccard 0.75 inter≥2; `playlist_utils` 111L `customId-` ids; `queue_entry_utils`; `song_filtering`; `sort_utils`; etc.

### 3.9 Packages
- `youtube_explode_dart` vendored 184 files (`youtube_http_client 384L` defaultHeaders `CONSENT=YES+cb`, validate 429→RequestLimit, sendPost `key=AIzaSy…`, WEB `2.20220921`, throttled Range vs range, close flag; `retry` 5 500ms; `cipher` decipher reverse/splice/swap; `ejs` Deno isolate `ejs_modules.g`; `pages/watch/channel/playlist/search`; `player` response/source; `streams` manifest mixins/models/types hls; freezed `.g`).
- `youtube_music_explode_dart` 3 files stub `WEB_REMIX`.

### 3.10 iOS & Build
- `ios/Runner/AppDelegate.swift:18` `FlutterAppDelegate+FlutterImplicitEngineDelegate`, `GeneratedPluginRegistrant`, comment defers `AVAudioSession` to Dart to avoid fighting `MPRemoteCommandCenter`.
- `ios/Runner/Info.plist:83` ATS `NSAllowsArbitraryLoads false` (good), `UIBackgroundModes [audio]` only, `CADisableMinimumFrameDurationOnPhone true` 120Hz, orientations portrait/landscape.
- `pubspec.yaml:57` `cupertino_icons`, `cached_network_image 3.4.1`, `audio_service 0.18.19 + just_audio 0.10.6 + audio_session`, `hive 2.2.3`, `go_router 17.5.0`, `webview_flutter 4.12.0`, assets `assets/licenses/`, paytoneOne, `generate: true`.
- `analysis_options.yaml:125` flutter_lints strict, `build.yaml` freezed/json.
- `test/` 12 + `tool/probe_clients.dart` 220L client viability probe.

---

## 4. Defect Register (fresh)

**Architecture:** global ValueNotifier soup (42 callers `app_themes`/`main 39`), no repo; hub isolates audio leaves well but rest tightly coupled via `settings_manager`.

**Playback:** stall on load not awaited; optimism flicker; HE-AAC halving + clipping correct but `ClippingAudioSource` for every YouTube URI `musified_audio_handler.md:2688` analog adds gap.

**Race:** `handleIncomingLink` previously `async void` fire-forget; now bounded via `main.dart:375` but still `NavigationManager.context` throw if early.

**Cache:** putAll atomic only for `cache` cat; TTL mismatch `song 1h30` vs TTL used vs `headRevalidate 30m`; stale googlevideo redirect 200 treated alive.

**Network:** sole `VISIONOS` no fallback; ytdlp parse brittle `visionos` brace regex; proxy MITM via bad cert elsewhere (not in lib code) if enabled.

**Widget:** Spinner fallback placeholder fine; no fatal widget crash pattern fresh — MiniPlayer blur20 performer.

---

## 5. Cross-cutting

- Lints exclude `packages/**` so vendored RE not linted.
- `Fastlane metadata` titles/descriptions point to `Musify` (legacy fork naming vs `musified`).
- `probe_clients` determines fallback order — IP-dependent.

*End — no prior audit text consulted beyond raw file reads; maps at `directory_map.md`, `linkage_map.md`, `file_roles.md` are canonical inventories.*
