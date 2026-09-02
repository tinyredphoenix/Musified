# Postbaseline — Linkage Map (imports → callers, fresh, 2026-09-02)

*Generated via `parse import 'package:musified/*'` over `lib/**` (166 files) — prior audits ignored.*

## Hub modules (most imported — central infrastructure)

| Module | Callers | Example callers |
|---|---|---|
| `theme/app_themes.dart` | 42 | `lib/main.dart`, `lib/screens/home_page.dart`, `lib/screens/artist_page.dart`, `lib/screens/bottom_navigation_page.dart`, `lib/screens/library_page.dart`, `lib/widgets/mini_player.dart` … |
| `main.dart` | 39 | `lib/screens/artist_page.dart`, `lib/screens/home_page.dart`, `lib/screens/search_page.dart`, `lib/widgets/mini_player.dart`, `lib/widgets/song_tile.dart` … (global `audioHandler`, `logger`, `appLinks`) |
| `theme/musified_style.dart` | 35 | `lib/main.dart`, `lib/screens/home_page.dart`, `lib/widgets/playlist_cube.dart`, `lib/widgets/song_tile.dart` … |
| `services/settings_manager.dart` | 24 | `lib/main.dart`, `lib/screens/settings_page.dart`, `lib/services/common_services.dart`, `lib/services/source_resolver.dart`, every playback/artwork widget |
| `services/common_services.dart` | 23 | `lib/main.dart`, `lib/screens/search_page.dart`, `lib/services/audio/*`, `lib/widgets/download_picker_sheet.dart` |
| `utilities/flutter_toast.dart` | 21 | `lib/main.dart`, `lib/screens/playlist_page.dart`, `lib/services/playlists_manager.dart` |
| `utilities/app_utils.dart` | 14 | `lib/services/artist_service.dart`, `lib/services/audio/audio_playback_coordinator.dart`, `lib/services/io_service.dart`, `lib/widgets/song_artwork.dart` |
| `services/playlists_manager.dart` | 12 | `lib/screens/library_page.dart`, `lib/screens/playlist_page.dart`, `lib/widgets/playlist_bar.dart` |
| `services/data_manager.dart` | 11 | `lib/screens/settings_page.dart`, `lib/services/artist_service.dart`, `lib/services/playlists_manager.dart` |
| `utilities/mediaitem.dart` | 9 | `lib/services/audio/audio_browse_catalog.dart`, `lib/services/audio/musified_audio_handler.dart`, `lib/widgets/mini_player.dart` |
| `services/router_service.dart` | 8 | `lib/main.dart`, `lib/screens/search_page.dart`, `lib/widgets/playlist_bar.dart` |

*Interpretation:* App has no repository — hub is global `ValueNotifier` soup. Centrality of `main.dart` (39 callers) is DI via globals (`audioHandler`, `logger`). `app_themes` 42 callers shows theming permeates every screen.

## Per-group linkage

### Entry → everyone

* **`lib/main.dart:467`** exports `logger, Logger` and `audioHandler`. Imports 18 app modules (see `directory_map`). Called by ~40 files. Downstream of `Hive` + `AudioService`. Owns `initialisation()` 5 phases: `Hive 5 boxes` → `applicationDirPath` → `SourceResolver`/`AudioService(9s)` → `NavigationManager` → `AppLinks`.

### Services (audio hub)

```
lib/services/audio/musified_audio_handler.dart:2698
  → imports: audio_service (barrel), audio_session, hive, just_audio, main.dart(logger/audioHandler),
           models/full_player_state/position_data, audio/audio_browse_catalog, audio_completion_coordinator,
           audio_handler_hub, audio_playback_coordinator/playback_install/preload_*, audio_queue_*, settings_manager,
           app_utils/mediaitem, rxdart
  ← called by: lib/main.dart (+ audio_service shim) only as singleton global

lib/services/audio/audio_handler_hub.dart:49
  → audio_queue_state, audio_preload_cache/service, audio_queue_controller
  ← called by: musified_audio_handler only (composition root)

lib/services/audio/audio_playback_coordinator.dart:574
  → audio_playback_install, playback_source, common_services, app_utils
  ← called by: musified_audio_handler

lib/services/audio/audio_preload_service.dart:210
  → common_services/fetchSongStreamUrl, app_utils/isUsable, audio_preload_cache
  ← called by: audio_handler_hub
```

### Core domain

* **`lib/services/common_services.dart:1545`** → `data_manager`, `io_service`, `artist_service`, `youtube_client`, `source_resolver`, `ytdlp_sync`, `youtube_auth/music_sync`, `app_utils`, `formatter`. ← called by 23 (screens, handler, widgets).
* **`lib/services/source_resolver.dart:186`** → `jiosaavn_service`, `track_matcher`, `settings_manager`, `hive saavn_match_cache`. ← called by `common_services`, `download_picker_sheet`.
* **`lib/services/jiosaavn_service.dart:147`** → `dart_des` + `http`. ← called by `source_resolver` only.
* **`lib/services/data_manager.dart:274`** → `hive`, `painting`, `artwork_provider`. ← called by 11 (settings, playlists_manager, artist_service).
* **`lib/services/io_service.dart:40`** → `app_utils/sanitizeStorageSongId`. ← called by `common_services`, `playlist_download_service`, widgets.

### Playlists / offline

* **`lib/services/playlists_manager.dart:1609`** → `albums.db/playlists.db`, `artist_service`, `youtube_client`, `data_manager`, `youtube_auth/music_sync`, `app_utils/playlist_utils`. ← called by `library_page`, `playlist_page`, `home_page`, `playlist_bar`.
* **`lib/services/playlist_download_service.dart:602`** → `common_services/makeSongOffline`, `io_service`, `data_manager`. ← called by `library_page`, `playlist_page`, `router_service`.
* **`lib/services/playlist_sharing.dart:93`** → `youtube_client`, `formatter`. ← called by `playlist_page`, `main.dart` deeplink.

### Network / YouTube

* **`lib/services/youtube_client.dart:4`** (`YoutubeExplode()`) ← no app imports, → `youtube_explode_dart`. ← called by `common_services`, `playlists_manager`, `playlist_sharing`, `artist_service`.
* **`lib/services/youtube_auth_service.dart:191`** → `hive youtube_auth`, `crypto/sha1`, `http`. ← called by 9 (settings, youtube_music_sync, playlists_manager).
* **`lib/services/youtube_music_sync_service.dart:774`** → `youtube_auth`, `http`, `hive`. ← called by `playlists_manager`, `common_services`, settings.
* **`lib/services/ytdlp_client_sync_service.dart:395`** → `http`, `hive settings:youtubeVisionOsClient`. ← called by `clients.dart`, `settings_page`, `main.dart`.
* **`lib/constants/clients.dart`** → `ytdlp_sync` → `YoutubeApiClient.visionOs` (sole `VISIONOS`).

### Screens ↔ Router ↔ Widgets

* **`lib/services/router_service.dart:377`** → every `screens/*` + `playlist_download_service`, `settings_manager`. ← called by `main.dart`, `bottom_navigation_page`, `search_page`, `playlist_bar`. Exposes `NavigationManager.router` + `artistPath/albumPath/basePathFor`.
* **`lib/screens/bottom_navigation_page.dart:230`** → `router_service`, `main.dart audioHandlerReady/mediaItem`, `settings_manager offlineMode`, `mini_player`. Owns `StatefulNavigationShell`.
* **`lib/screens/search_page.dart:391`** → `common_services fetchSongsList/searchArtists/getPlaylists`, `playlists_manager`, `data_manager`, `song_tile/artist_bar/playlist_bar`.
* **`lib/screens/playlist_page.dart:665`** → `playlists_manager`, `artist_service`, `playlist_download_service`, `playlist_sharing`, `song_tile/playlist_cube`.
* **`lib/screens/artist_page.dart:482`** → `artist_service` (`getArtistProfile/catalog`), `playlists_manager`, `artist_shelf/song_tile`.

### Theme

* **`lib/theme/app_themes.dart:129`** → `settings_manager themeMode`, `musified_style`. ← 42 callers.
* **`lib/theme/musified_style.dart:135`** → none. ← 35 callers (tokens).

### Utilities

* **`lib/utilities/app_utils.dart:285`** ← `constants/app_constants`, `settings_manager`, `youtube_explode_dart` — called by 14 (artist_service, audio/*, io_service).
* **`lib/utilities/mediaitem.dart:193`** → `app_utils`, `io_service`. ← 9 callers (audio_browse_catalog, musified_audio_handler).
* **`lib/utilities/artwork_provider.dart:55`** LRU 80 — called by `playlist_artwork`, `song_tile`, `artist_bar`.
* **`lib/utilities/track_matcher.dart:159`** ← `source_resolver` only.

### Packages (vendored, not counted above)

* `packages/youtube_explode_dart/lib/src/reverse_engineering/youtube_http_client.dart:384` ← called by every RE client/page (`WatchPage`, `StreamClient`, `SearchPage`). → `http`, `retry`, `hls_manifest`.
* `packages/youtube_music_explode_dart/lib/src/music_client.dart` ← called by `services/youtube_music_sync_service` (via `youtube_explode` internals).

## Anti-patterns visible

* `main.dart` 39 callers = global DI.
* `isolated` 143 files with no Musified callers include `lib/constants/*`, `lib/database/*`, `lib/localization/*` — leaf data / generated. Not a bug.
* `services/audio/*` narrowly 2-3 callers each = good hub isolation; rest of app overly coupled via `settings_manager`/`main.dart`.

## How produced

* `python import regex ^import 'package:musified/(.+)'` over `lib/**/*.dart` → edges caller→callee, invert to callee callers. Counts `wc -l` verified. Full raw edges at `/tmp/audit_report.md` (if generated) — not omitted here.

