# Musified — README Index (readmes/)
*Generated: 2026-09-01 · Source: auditfinal.md + live code verification · No code edits in this folder — documentation only.*

This folder contains per-module READMEs that were requested alongside comment-stripping. `auditfinal.md:1` is kept free of this material on purpose (see its header).

## Map

| # | File | Covers |
|---|---|---|
| 01 | `01_main.md` | `lib/main.dart:1` entry, AppLinks, error widget |
| 02 | `02_audio.md` | `lib/services/audio/*` + `lib/services/audio_service.dart:1` shim + queue/preload/playback |
| 03 | `03_services_core.md` | `common_services`, `source_resolver`, `jiosaavn`, `data_manager`, `io_service` |
| 04 | `04_network_proxy_youtube.md` | `proxy_manager`, `proxy_fetch_service`, `youtube_auth`, `youtube_music_sync`, `ytdlp_sync`, `playlist_sharing` |
| 05 | `05_persistence.md` | `database/*`, Hive boxes, `playlists_manager`, `playlist_download_service` |
| 06 | `06_screens.md` | `lib/screens/*` 12 + `router_service` |
| 07 | `07_widgets.md` | `lib/widgets/*` 47 + `now_playing/` |
| 08 | `08_theme.md` | `lib/theme/*`, `app_colors`, `musified_style` |
| 09 | `09_utilities_models.md` | `lib/utilities/*`, `lib/models/*`, `lib/constants/*` |
| 10 | `10_ios_build.md` | `ios/Runner/*`, `Info.plist`, `pubspec.yaml`, `analysis_options.yaml` |
| 11 | `11_packages.md` | `packages/youtube_explode_dart`, `youtube_music_explode_dart` forks |

## How to use

- Each README lists: Purpose, Call graph (who calls / whom it calls), Public API, File-by-file table, Comments removed (verbatim), Known bugs still open (with `file:line`), Verification vs `auditfinal`.
- To actually strip comments, run `dart run tool/strip_comments.dart --dryRun lib/` (not executed here).
- Verification status as of `2026-09-01` cold read: see `01_main.md` header + summary below.

## Verification snapshot vs auditfinal ( P0/P1 )

| Fix | Status |
|---|---|
| `search_page.dart:19` import-time Hive crash → moved to `initState` | **FIXED** |
| `musified_audio_handler.dart:308` double dispose | **FIXED** (single `dispose`) |
| `proxy_manager.dart:324/620` pool poison via pooled IOClient close | **FIXED** via ` _youtubeFromDedicatedProxy:331` dedicated HttpClient |
| `audio_preload_service.dart:22` `activeCount--` in `cleanupStaleForYtids` | **FIXED** `32` |
| `io_service.dart:15` `sanitizeStorageSongId` traversal | **FIXED** `app_utils.dart:173` + usage `io_service.dart:18` |
| `data_manager.dart:72` atomic put via `putAll` for cache | **PARTIALLY FIXED** (cache cat only) |
| `musified_audio_handler.dart:670+698` interruption/becomingNoisy | **FIXED** |
| `main.dart:348` `AudioService.stop()` before fallback | **FIXED** |
| `main.dart:375` `getInitialLink` + size limit `399` + safe `navContext:429` | **FIXED** |
| `Info.plist:33` `UIFileSharingEnabled false` + `flutter_secure_storage` | **NOT FIXED** (still `true`, no dep) |
| `proxy_manager.dart:338/429` `badCertificateCallback=>true` MITM | **NOT FIXED** |
| `router_service.dart:119` `refreshRouter` wired to `offlineMode` | **NOT FIXED** |
| Single DPR-aware image cache | **NOT FIXED** (still 4 layers, but `configureImageMemoryBudget:62` 48MB) |
| Debounce search `Future.wait` | **PARTIALLY FIXED** (suggestions 300ms, main search still no debounce) |

See each README § Notes for file-level verification.
