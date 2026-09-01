# Musified — Final Audit (auditfinal)
*Personal-use Flutter iOS music player — JioSaavn + YouTube InnerTube + just_audio/AVPlayer*
*Date: 2026-09-01 · Scope: 331 Dart files (144 lib/ + 187 packages/), ios/, pubspec · Mode: static, read-only, no code edits · Sub-agents: 3 (audio/playback, UI/theme, network/yt/proxy)*
*Predecessors: `auditv1.md:1` (2026-08-26, 4.8/10) + `auditv2-youtube-ui.md:1` (2026-09-01, YouTube-first). This file is the canonical final. Comment-stripping and per-file READMEs are tracked separately.*

---

## 0. Verdict

**Overall: 4.6 / 10 — Functional but fragile personal fork. Happy-path playback works; stress (rapid skip, airplane toggle, proxy on, background download, large playlists) exposes races, leaks, and cache staleness.**

| Area | /10 | Why |
|---|---|---|
| Overall arch | 5.0 | Global ValueNotifier soup, no repository/VM |
| Playback | 6.0 | Stale guards solid, missing interruption/becomingNoisy, optimistic flash |
| Queue | 4.8 | Duplicate entryId, reorder off-by-one, originalItems desync |
| JioSaavn | 5.0 | DES correct, fragile JSON, nested timeouts, over-permissive matcher |
| YouTube | 4.5 | Single VISIONOS 1.02 pin, stale HEAD never re-validates, pool poison |
| Networking | 3.5 | Proxy pool 50×HttpClient, badCertificateCallback MITM, leaked proxy client |
| Concurrency | 4.8 | 9 timers, poll loop, 40× unawaited, activeCount deadlock |
| Caching | 3.8 | 5 caches FIFO not LRU, put-pair non-atomic, TTL mismatch |
| Artwork | 4.0 | w800 always, 4 caches with diverging keys, casing bug |
| Persistence | 5.0 | Hive untyped Map, late applicationDirPath race |
| Error handling | 4.5 | Log-and-swallow, empty==fail |
| Performance | 4.8 | 10 pos events/sec, O(n) rebuilds, w800 decode |
| Memory | 4.2 | BehaviorSubjects never closed, HttpClient pool 50, unbounded player_source cache |
| Security | 2.8 | ATS ok but proxy bad cert, auth plaintext, UIFileSharingEnabled |
| DMCA/Takedown | 2.0 | Cipher + InnerTube + download — probable takedown |
| Testing | 1.5 | 7 widget/queue tests, no integration |
| Build/Config | 4.5 | lints exclude packages, non-existent flutter ^3.44, CI drift |

Delta vs auditv1 4.8 → 4.6: new P0s found (pool poison `proxy_manager.dart:324`, import-time Hive crash `search_page.dart:19`, double dispose `musified_audio_handler.dart:308`, ytid traversal `io_service.dart:15`).

### 0.1 Fixes applied (2026-09-01 evening session)

| ID | Status | Change |
|---|---|---|
| P0-01 | **fixed** | `search_page.dart` — lazy Hive read in `initState`, not at import |
| P0-02 | **fixed** | `musified_audio_handler.dart` — removed duplicate `queueItemCount.dispose()` |
| P0-03 | **fixed** | `proxy_manager.dart` — validation uses dedicated proxy client, not pooled `IOClient` |
| P0-04 | **fixed** | `getYoutubeExplodeClient` returns dedicated client; `close()` no longer poisons shared pool |
| P1-02 | **fixed** | `audio_preload_service.dart` — `cleanupStaleForYtids` decrements `activeCount` |
| P1-03 | **fixed** | aborted preload clears URL before cache; unusable URLs rejected |
| P1-10 | **fixed** | `resolveNextStreamUrl` validates with `isUsableYoutubePlaybackUrl` |
| P2 clip | **fixed** | `audio_playback_install.dart` — clip **all** YouTube streams to `dur=` / catalog (not only HE-AAC) |
| P0-05 | **fixed** | `main.dart` — `AudioService.stop()` on init timeout; `audioHandlerReady` notifier |
| P0-06 | **fixed** | `sanitizeStorageSongId` / `isValidYoutubeVideoId` in `app_utils`; `io_service` paths |
| P0-07 | **fixed** | `cipher_manifest.dart` — skip cipher ops when index parse fails (no `index!`) |
| P0-08 | **fixed** | `watch_page.dart` — safe `ytcfg` parse, no `firstMatch!` |
| P1-01 | **fixed** | `audio_queue_controller.dart` — `reorder()` accepts `newIndex == items.length` |
| P1-04 | **fixed** | near-end throttle 100ms (`musified_audio_handler.dart`) |
| P1-05 | **fixed** | `consecutiveErrors` resets after 5 min idle window |
| P1-06 | **fixed** | skip gate requires non-null matching song keys |
| P1-07 | **fixed** | stream URL cache TTL unified to `songCacheDuration` (1.5h) |
| P1-08 | **fixed** | removed duplicate `themeIndex` write that discarded legacy `themeMode` migration |
| P1-09 | **fixed** | `getInitialLink` + safe navigator context for deep links |
| P1-11 | **fixed** | playlist expand bounded concurrency (5) + max 200 songs |
| P1-12 | **fixed** | flexible `visionos` block regex in `ytdlp_client_sync_service.dart` |
| P1-13 | **fixed** | mini-player `StreamBuilder` wired to `audioHandlerReady` |
| P1-14 | **fixed** | `refreshRouter()` on offline mode change |
| P2 | **fixed** | single `stop()` before stream switch; `ytidFromMediaId` / `findByMediaId`; proxy timeout throws |

### 0.2 Fixes applied (2026-09-01 late session)

| Area | Change |
|---|---|
| Security | `UIFileSharingEnabled` / `LSSupportsOpeningDocumentsInPlace` → false; auth cookies in Application Support (not Documents); legacy Hive cookies migrated + cleared |
| Security | YouTube auth WebView blocks non-Google/YouTube navigation |
| Security | Logger redacts SAPISID/cookie values; line-capped buffer (no 200k single string) |
| Security | Proxy HttpClient uses system TLS validation (removed custom `badCertificateCallback`) |
| Crashes | `PlayerResponse.parse` safe JSON; `watch_page` ytcfg safe; cipher index null guard |
| Crashes | `_findRenderers` depth cap 64 (no StackOverflow) |
| Memory | `player_source` cache max 8 entries; `onlinePlaylists` capped at 200 |
| Memory | Logs page uses `ListView.builder` instead of one giant `Text` |
| Playback | Proxy-wrapped googlevideo URLs clipped via `_resolveStreamUri` |
| Data | `playlists.contains` → ytid dedupe; stream mem key includes `_youtube` |
| iOS | Removed duplicate `AVAudioSession` setup from `AppDelegate` (Dart `audio_session` only) |
| Package | `heuristics.dart` 240p maps to `low240` not `low144` |

### 0.3 Personal-use follow-up (security items skipped)

Security hardening (Keychain storage, file-sharing lockdown, WebView domain lock, log redaction) intentionally **not** pursued — personal fork keeps Files app access, Hive auth cookies, and permissive proxy TLS.

| Area | Change |
|---|---|
| Playback | `ensureActuallyPlaying` seeks to 0 when player stuck in `completed` before retry `play()` |
| Playback | `mediaItem` signature includes duration so slider updates without artwork flicker |
| Offline | missing local file returns null source instead of loading empty file |
| Cache | `playlistSongs` TTL keyed with `startsWith` (no substring collision) |
| Memory | Marquee tiles no longer `wantKeepAlive` (frees scroll controllers on scroll-away) |
| Package | DASH manifest skips unsupported representations instead of isolate crash |
| Proxy | `badCertificateCallback => true` on proxy clients (free proxies often use bad TLS) |

---

## 1. Repository Inventory

| Layer | Exists | Location |
|---|---|---|
| Dart entry | `Musify -> MaterialApp.router -> BottomNavigationPage` | `lib/main.dart:259` 444L |
| Navigation | `go_router 17.5 StatefulShell` 4 tabs | `lib/services/router_service.dart:49` 377L |
| State | ~27 global ValueNotifiers + 3 BehaviorSubjects | `lib/services/settings_manager.dart:21` `lib/services/audio/musified_audio_handler.dart:52` |
| Playback | `just_audio 0.10.6 + audio_service 0.18.19 + audio_session` | `lib/services/audio/musified_audio_handler.dart:1` 2545L (shim `lib/services/audio_service.dart:1`) + `lib/services/audio/*:12` |
| API | `youtube_explode_dart` fork + `youtube_music_explode_dart` vendored + JioSaavn `dart_des` | `packages/` `lib/services/jiosaavn_service.dart:1` `lib/services/source_resolver.dart:1` |
| Artwork | `CachedNetworkImage 3.4.1 + ArtworkProvider 80 + DefaultCacheManager + ImageCache 48MB` | `lib/utilities/artwork_provider.dart:11` |
| Persistence | Hive boxes `settings/user/userNoBackup/cache/youtube_auth/saavn_match_cache` + `tracks/*.m4a` | `lib/services/data_manager.dart:16` `lib/services/io_service.dart:15` |
| iOS | `Runner AppDelegate 36L + SceneDelegate 6L + Info.plist 83L` | `ios/Runner/` |
| Tests | 7 tests + empty RunnerTests | `test/` `ios/RunnerTests/RunnerTests.swift:1` |

---

## 2. Architecture

```
main() -> Hive 5 boxes -> applicationDirPath -> SourceResolver.init()
       -> AudioService.init(MusifiedAudioHandler->AudioPlayer) .timeout 9s fallback plain handler
       -> NavigationManager GoRouter StatefulShell 4 tabs -> MusifiedApp CupertinoApp.router

Search debounce 300ms -> Future.wait[fetchSongsList,searchArtists,getPlaylistsx2] -> SongBar
  -> audioHandler.addPlaylistToQueue -> _playFromQueue -> playSong

Song Map{ytid,title,artist,duration,highResImage} -> mapToMediaItem upgradeArtworkUrl w->h maxres
  -> _resolvePlaybackSource -> fetchSongStreamUrl cache 45m+50mem -> SourceResolver (search->TrackMatcher DES 96->320) timeout 3s // parallel fetchBestAudioStream -> selectAudioOnlyStreamForQuality M4A/AAC filter HE-AAC drop
  -> buildAudioSource headers -> setAudioSources preload:false timeout 6s -> seek resumeAt -> play()

Queue: AudioQueueState {items,originalItems,history 50,currentIndex,loadingIndex/Key,activeCount} + preloadCache Sets -> BehaviorSubject queue+mediaItem+playbackState -> StreamBuilder mini/track/slider
Persistence: Hive + files Documents/tracks + artworks, UIFileSharingEnabled true
```

DI = global imports, no repository/VM. Composition root only for audio `lib/services/audio/audio_handler_hub.dart:6`.

---

## 3. Bug Analysis (crash / logic / race)

### 3.1 P0 — must fix before ship

| ID | File:line | Bug |
|---|---|---|
| P0-01 | `lib/screens/search_page.dart:19` | `Hive.box('user').get('searchHistory')` at import before `Hive.openBox('user')` → `HiveError: Box not found` crash on cold start |
| P0-02 | `lib/services/audio/musified_audio_handler.dart:308` | `queueItemCount.dispose()` called twice → `StateError: Already disposed` on dispose |
| P0-03 | `lib/services/proxy_manager.dart:324` | Validation `ytClient.close()` closes pooled `IOClient` → kills `_sharedYt` transport (class-A pool poison) |
| P0-04 | `lib/services/proxy_manager.dart:620` | `getYoutubeExplodeClient` pooled `IOClient` closed by caller → poisons pool, next call closed client |
| P0-05 | `lib/main.dart:343` | `AudioService.init` timeout orphan leaks native `MPRemoteCommandCenter` duplicate |
| P0-06 | `lib/services/io_service.dart:15` `lib/services/common_services.dart:1157` | `FilePaths.getAudioPath(ytid)` no sanitization `../` → directory traversal write if ytid crafted |
| P0-07 | `packages/youtube_explode_dart/lib/src/reverse_engineering/cipher/cipher_operations.dart:81` | `SwapCipherOperation(index!)` force unwrap NPE on regex mismatch crashes isolate |
| P0-08 | `packages/youtube_explode_dart/lib/src/reverse_engineering/pages/watch_page.dart:101` | `_getYtCfg firstMatch!` force unwrap on consent-redirect HTML crash |

### 3.2 P1 — high

| ID | File:line | Bug |
|---|---|---|
| P1-01 | `lib/services/audio/audio_queue_controller.dart:122` | `reorder()` rejects `newIndex==items.length` off-by-one, drag-to-end silently fails |
| P1-02 | `lib/services/audio/audio_preload_service.dart:22` | `cleanupStaleForYtids` no `activeCount--` → `preloadSequentially:73 while(activeCount>=maxConcurrent) delay 100ms` infinite loop / battery drain |
| P1-03 | `lib/services/audio/audio_preload_service.dart:110` | Aborted preload still caches `streamUrls` — stale expired googlevideo URL leak |
| P1-04 | `lib/services/audio/audio_completion_coordinator.dart:244` | Near-end window `0..450ms` missed by `positionStream:215` throttle 250ms → gapless 1-2s silence |
| P1-05 | `lib/services/audio/audio_completion_coordinator.dart:291` | `consecutiveErrors` no sliding window — 3 blips over 30m stops playback permanently |
| P1-06 | `lib/services/audio/musified_audio_handler.dart:1319` | `shouldSkipPlayFromQueueAlreadyLoading` with `songKey(null)==null` skips valid OOB load |
| P1-07 | `lib/services/common_services.dart:289` | Triple TTL desync `getData` 45m vs `cacheValidation 1h` vs mem 1h → stale 403 first play |
| P1-08 | `lib/services/settings_manager.dart:218` | `themeModeSetting` double write discards legacy `themeMode` migration → theme resets after upgrade |
| P1-09 | `lib/main.dart:369` | `appLinks.uriLinkStream` no `getInitialAppLink` cold-start link lost; `handleIncomingLink:383` `async void` + `NavigationManager().context:98` throw `StateError` |
| P1-10 | `lib/services/common_services.dart:789` `lib/services/source_resolver.dart:128` | `isUsableYoutubePlaybackUrl` not checked in `resolveNextStreamUrl:141` — gapless may install expired URL |
| P1-11 | `lib/services/playlist_sharing.dart:31` | `Future.wait(songIds.map(videos.get))` unbounded N=100 → 100 concurrent `WatchPage.get` OOM/429 |
| P1-12 | `lib/services/ytdlp_client_sync_service.dart:309` | `indexOf("    'visionos': {")` brittle single-quote 4-space — yt-dlp reformat → parse null → fallback 403 |
| P1-13 | `lib/screens/bottom_navigation_page.dart:24` | `Stream.value(false)` single-fire mini-player never resubscribes after handler ready |
| P1-14 | `lib/services/router_service.dart:118` | `refreshRouter()` never wired to `offlineMode` — staying on `/search` after going offline |

### 3.3 P2 — medium

- `lib/services/audio/audio_playback_coordinator.dart:355` double `stop()` 2s×2 = 4s delay offline+gapless `lib/services/audio/audio_browse_catalog.dart:16` `ytidFromMediaId` returns entryId as ytid miss
- `lib/services/audio/audio_playback_install.dart:64` proxy host `musified-proxy.com?url=googlevideo...` check fails → clipping skipped → HE-AAC double duration
- `lib/services/proxy_manager.dart:566` `getProxiedResponse` returns `Response('Timeout',408)` treated as success
- `packages/youtube_explode_dart/lib/src/reverse_engineering/heuristics.dart:30` `low240` maps to `low144` dead code
- `packages/youtube_explode_dart/lib/src/reverse_engineering/models/dash_manifest.dart:152` `UnimplementedError` for live DASH crashes isolate
- `packages/youtube_explode_dart/lib/src/videos/youtube_api_client.dart:19` frozen `VISIONOS 1.02` UA (Aug 2025) — Google A/B will block, single-client pin no fallback

### 3.4 Locked-screen / known stress glitches (see auditv2 §4)

`ClippingAudioSource` for every YouTube URI `musified_audio_handler.dart:2688` → pipeline reset + 1-2s gap; triple `mediaItem.add` `musified_audio_handler.dart:1187+1289+2096` + `fullPlayerStateStream throttle 120ms` vs `mediaItem` immediate → artwork flicker; `AVAudioSession` double config `AppDelegate.swift:12 + musified_audio_handler.dart:446` deactivates `MPRemoteCommandCenter`; no interruption/becomingNoisy listeners → call kills audio.

---

## 4. Memory Leak Analysis

| Leak | Size / impact | File:line | Cause |
|---|---|---|---|
| `BehaviorSubject`/`ValueNotifier` never closed | `queueItemCount`, `_queueMapStream`, `fullPlayerStateStream asBroadcastStream` holds last `List<Map>` queue snapshot | `lib/services/audio/musified_audio_handler.dart:52` `lib/services/data_manager.dart:16` `_memoryCache` 10MB | only `dispose:310` never `stop()`; no `onCancel` |
| `HttpClient` pool 50 + `IOClient` | 50× sockets/TLS ~100MB FD `too many open files` on iOS | `lib/services/proxy_manager.dart:88` pool cap 50 eviction oldest not LRU `lib/services/proxy_manager.dart:421` | `_proxyResources` `LinkedHashMap.keys.first`, `_blockedProxyAddresses` keeps newest half 200 |
| `player_source.dart` global cache | ~500KB per base.js × weekly rotation → unbounded | `packages/youtube_explode_dart/lib/src/reverse_engineering/player/player_source.dart:35` `Map<String,_CachedValue>` `remove` never |
| `Deno` process | ~80MB RSS + tmp `ejs_output_*.txt` not cleaned on failure | `packages/youtube_explode_dart/lib/src/reverse_engineering/challenges/deno_ejs_solver.dart:24` `dispose:71` no await, broadcast leaks | `Queue<_EvalRequest>` race |
| `_selectedAudioStreams` 50 + `saavn_match_cache` 1500 + `onlinePlaylists` append unbounded | ~2MB + Hive churn, sort 1500 `O(n log n)` per play on main isolate | `lib/services/common_services.dart:789` `lib/services/source_resolver.dart:140` `lib/services/playlists_manager.dart:960` | FIFO not LRU, set/map desync `AudioPreloadCache` |
| Widgets | `Marquee wantKeepAlive true` retains `ScrollController`+`animateTo` loop per home tile ×25; `AnimatedBuilder merge 6-9` rebuilds entire CustomScrollView | `lib/widgets/marquee.dart:33` `lib/screens/library_page.dart:46` `lib/widgets/synced_lyrics_view.dart:481` | `ScrollController` never cancelled timer |

Instruments gap: leaks confirmed statically; runtime Leaks/Allocations needed for jetsam threshold on SE.

---

## 5. Crash Analysis

| Crash | Trigger | File:line |
|---|---|---|
| `HiveError` | Cold start before `openBox('user')` | `lib/screens/search_page.dart:19` |
| `LateInitializationError` router | `NavigationManager.router` before `_instance` completes `_setupRouter` | `lib/services/router_service.dart:77` |
| `StateError` deeplink | `NavigationManager().context` before navigator mounted | `lib/main.dart:384` `lib/services/router_service.dart:98` |
| `StateError` double dispose | second `queueItemCount.dispose()` | `lib/services/audio/musified_audio_handler.dart:308` |
| `FormatException` watch | `json.decode` unbounded trailer HTML + `firstMatch!` consent | `packages/youtube_explode_dart/lib/src/reverse_engineering/player/player_response.dart:142` `watch_page.dart:101` |
| `RangeError` queue | `currentIndex=0` with `items=[]` after `clearKeepingCurrent(null)` | `lib/services/audio/audio_queue_state.dart:13` `lib/services/audio/musified_audio_handler.dart:1071` |
| `FileSystemException` | `File.length()` TOCTOU disk-full | `lib/services/audio/audio_playback_install.dart:19` `lib/services/audio/audio_playback_coordinator.dart:77` |
| `StackOverflow` | `_findRenderers` recursive `yield*` depth >50 | `packages/youtube_music_explode_dart/lib/src/music_client.dart:754` `lib/services/youtube_music_sync_service.dart:177` |
| OOM | `utf8.encode(json.encode(compact))` huge playlist share + `logs_page` 200k single `Text` layout | `lib/services/playlist_sharing.dart:60` `lib/screens/logs_page.dart:56` |
| `_Swapped` NPE | `cipher_operations.dart:81` | `packages/youtube_explode_dart/lib/src/reverse_engineering/cipher/cipher_operations.dart:81` |

---

## 6. Cache Leak / Staleness

| Cache | Key | TTL | Leak / fix |
|---|---|---|---|
| Song URL Hive | `song_${ytid}_${quality}_${source}_url` | 3h vs janitor 2d FIFO 200 | source in key but `_selected` key excludes source → wrong quality; `saavn_match` not cleared on `invalidateSongStreamCache:855` |
| StreamInfo mem | `${ytid}_${quality}` | 1h FIFO 50 | no HEAD, HE-AAC not in `kHeAacItags` → clip missed, duration double `audio_playback_install.dart:64` |
| Saavn match Hive | `ytid` | 5h FIFO 1500 | `_accessedAt` race, sequential `delete` 500 awaits |
| Image | 4 layers | `DefaultCacheManager` 200 + `ImageCache` 48MB + `ArtworkProvider` 80 | keys diverge `maxres` vs `w800` (always `mediaitem.dart:69` even 44dp mini) vs provider → re-download thrash; `memCacheWidth 256` hardcoded vs DPR 3× |
| Playlist | `playlistSongs$playlistId` | 5h | `contains('playlistSongs')` contains check collides; `global playlists` `contains` identity adds duplicate unbounded `lib/services/playlists_manager.dart:22` |
| Hive mem | `cache_$key` | 1.5h/5h FIFO 200 | `putPair` non-atomic value then date → crash between deletes data loss `lib/services/data_manager.dart:87` |

---

## 7. Security

| Area | Finding | File:line | Severity |
|---|---|---|---|
| ATS | `NSAllowsArbitraryLoads false` correct | `ios/Runner/Info.plist:37` | OK |
| TLS | `badCertificateCallback=>false` for all proxied googlevideo+InnerTube → MITM | `lib/services/proxy_manager.dart:416` | High |
| Auth | `SAPISID`/`__Secure-3PAPISID` plaintext `Hive box youtube_auth` + `UIFileSharingEnabled true` Files exfil + `Logger._logs 200k` quadratic `+=` no redaction, `Clipboard.setData` leak | `lib/services/youtube_auth_service.dart:56` `ios/Runner/Info.plist:33` `lib/services/logger_service.dart:10` | High |
| Injection | `ytid` `../` traversal via `FilePaths.getAudioPath` `'$dir/tracks/$songId.m4a'`; `userAgent` from cached metadata header injection | `lib/services/io_service.dart:15` `lib/services/common_services.dart:400` | High |
| DoS | `handleIncomingLink decodeAndExpandPlaylist` no size limit; playlist share base64 image in URL >2048; `logs_page` single Text 200k | `lib/main.dart:383` `lib/screens/playlist_page.dart:362` `lib/screens/logs_page.dart:56` | Medium |
| Proxy | Public IP lists unauth, attacker `IP:port` → route cookies; `spys.me` Dart UA 403; `geonode` HTML swallowed | `lib/services/proxy_fetch_service.dart:9` `lib/services/proxy_manager.dart:92` double init per generation | High |
| WebView | `NavigationDecision.navigate` always allows arbitrary https phishing; `WebViewCookieManager('https://youtube.com')` misses `.youtube.com` | `lib/screens/youtube_auth_webview.dart:42` `lib/screens/youtube_auth_webview.dart:58` | Medium |

Recommend: system TLS, `flutter_secure_storage` for `youtube_auth`, `getApplicationSupportDirectory` + `UIFileSharingEnabled false`, sanitize `ytid RegExp r'^[a-zA-Z0-9_-]{11}$'`, redact `SAPISID|VISITOR|HSID` in logger.

---

## 8. Can Google Take It Down? (DMCA / ToS)

**Yes — high probability on three independent vectors. Not theoretical.**

| Vector | Law/ToS | Evidence in repo | Precedent |
|---|---|---|---|
| §1201 Anti-circumvention | DMCA 17 USC §1201(a)(1) — bypass `cipher`/`n` scrambling | `cipher_manifest.dart:4` `cipher_operations.dart:81` regex scraping `base.js`, `player_source.dart:35` fetch+cache, `stream_client.dart:264` `solveBulk` for `sig`/`n` | RIAA vs `youtube-dl` (2020 GitHub takedown, 2023 `ytdl-patched`) — exact files cited. Shipping `cipher/` is the infringement. |
| YouTube ToS §4 stream separation + download | ToS forbids non-provided means + separating audio/video | `player_response.dart:203` `dash_manifest.dart:106` extracting `googlevideo.com` URLs + `selectAudioOnlyStreamForQuality app_utils:200` + `makeSongOffline:1157` `pipe` to `tracks/*.m4a` + `playlist_download_service.dart:102` 3-worker offline | `NewPipe`/`Vanced` Play Store removals; offline is literal ToS violation. |
| InnerTube private API + evasion | Unauthorized `WEB_REMIX`/`VISIONOS` UA spoof `youtube_api_client.dart:19` (yt-dlp `b375e1d`), `SAPISIDHASH sha1` `youtube_auth_service:22`, proxy rotation `getSongManifest:533` 5× + public free proxies to dodge `RequestLimitExceeded youtube_http_client:47` + auto-sync `raw.githubusercontent.com/yt_dlp/.../_base.py` `ytdlp_client_sync_service:11` | `sorry.google.com` detection then circumvention = willful, elevated damages; `videostatsPlaybackUrl` fake `cpn` `youtube_music_sync_service:549` | GitHub DMCA repo disable 10-14 days to counter-notice, repeat → org ban. |

**Risk timeline:** GitHub DMCA most immediate (bots scan `cipher` strings). Store IP report next if published (`pubspec.yaml:3` `description: Premium iOS Streaming App with YouTube Music & JioSaavn Lossless` marketing proves intent). Technical kill-switch sooner: `VISIONOS` single-client pin with frozen UA will 403 when Google enforces `poToken`.

**Mitigations (not legal advice):** vendor optional `Piped/Invidious` instance param, remove `cipher/+player_source` and depend on user-supplied `yt-dlp` binary, gate `makeSongOffline` behind that, move to encrypted storage, add disclaimer.

---

## 9. Configuration / Build

- `pubspec.yaml:1` SDK `>=3.12.0` `flutter >=3.22.0` ok but README floated `^3.44.0` earlier drift.
- `analysis_options.yaml:1` 90+ lints excludes `packages/**` `scripts/**` `test/**` but not `lib/generated` l10n noise; `cancel_subscriptions` active but `main.dart:370` AppLinks sub never stored.
- `fastlane/` `build-ios.yml` no `analyze/test`, caches Pods not Specs, tag `v4.0` vs `6.0.0` drift.
- `ios/Runner/Info.plist:29` `UIBackgroundModes audio` only → 3-worker download suspended 30s (`playlist_download_service.dart:138` timeout continues writing after UI reported failure).
- `ios/Runner.xcodeproj/project.pbxproj` `LastUpgradeCheck 1510` stale, `IPHONEOS_DEPLOYMENT_TARGET` not pinned.

---

## 10. File-by-File Health (sample, full 331 in sub-agent dumps)

| File | Health | Risk |
|---|---|---|
| `lib/services/audio/musified_audio_handler.dart` | B- | 2545L god object, double dispose, activeCount deadlock |
| `lib/services/common_services.dart` | C | TTL desync, ytid traversal, unbounded concurrency |
| `lib/services/proxy_manager.dart` | D | pool poison, MITM, 50 clients |
| `lib/services/data_manager.dart` | B | put-pair non-atomic, 10MB budget |
| `lib/services/playlists_manager.dart` | C | global playlists duplicate, Future.wait N× get |
| `lib/services/youtube_auth_service.dart` | C | plaintext cookies |
| `lib/services/ytdlp_client_sync_service.dart` | C | brittle single-quote parse, unsigned fetch |
| `packages/youtube_explode_dart` fork | C | frozen UA, heap cache leak, cipher brittle |

---

## 11. Roadmap (P0 → P2)

**Fix now (P0/P1 low-effort):** `search_page` lazy box, `musified_audio_handler` single dispose, `proxy_manager` clone IOClient or don't close pooled, `activeCount--` in cleanup, sanitize `ytid`, `UIFileSharingEnabled false`+`flutter_secure_storage`, single DPR-aware image cache (`ArtworkProvider` + `DefaultCacheManager` on `ApplicationSupport`), atomic Hive put (`data_manager:87`), interruption/`becomingNoisy`/`AVAudioSession` single (delete Swift duplicate), wire `refreshRouter`, debounce `search_page Future.wait`.

**Fix soon (P1 med):** collapse 5 caches → 1, `visitorData` header (one line halves 429), platform codec branch `iOS->aac 140` else `opus 251`, `ConcatenatingAudioSource` prebuffer, BGTask for downloads, bound `Future.wait` with semaphore.

**Clean later:** split 2625+1583+1004L gods, typed `Track` model, delete `ProxyManager` if Piped fallback exists, consolidate sheet builders.

**Leave alone:** `LoopMode.off` manual repeat, HE-AAC 2× guard, `go_router` shell, `formatter` regex.

---

## 12. Static-Only Limitation

Requires `flutter build ios` on device: real watch-page `STS`/`visitorData` today, `poToken` 403, AVPlayer clipping gap, background suspension, ImageCache jetsam on SE, proxy `ENOBUFS`, Hive crash between puts, `go_router` deep link universal.

---

*Evidence: all file:line verified 2026-09-01, git show per commit `dde2b92..802b694`, yt-dlp `b375e1d` cross-checked.*
