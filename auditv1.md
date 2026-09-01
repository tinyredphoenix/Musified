# Musified v6 — Complete Static Audit (auditv1)
*Personal-use Flutter iOS music player — JioSaavn + YouTube InnerTube + just_audio/AVPlayer*
*Date: 2026-08-26 · Commit: 802b694 + local fixes · Scope: 129 Dart files, ios/, packages/youtube_explode_dart fork*

> **Context:** Prompt assumed native Swift/SwiftUI port — actual repo is **Flutter 3.44 Android-origin run on iOS**. Audited as Flutter-on-iOS.

---

## Overall Engineering Score: **4.8 / 10 — Functional but fragile personal fork**
Playback happy-path works; queue shuffles; Saavn fallback masks YouTube 403s. Under stress (rapid skip, airplane toggle, proxy on, background download, large artist) races/leaks/cache staleness surface.

| Area | /10 | Why |
|---|---|---|
| Overall arch | 5.0 | ValueNotifier soup, no repository |
| Porting | 6.0 | CupertinoTabBar ok, locale/BG/ATS gaps |
| Flutter/Dart | 5.5 | 3 god files, 5 caches |
| Playback | 6.5 | Stale guards solid, missing interruption |
| Queue | 5.0 | Duplicate id, reorder off-by-one |
| JioSaavn | 5.0 | DES solid, fragile JSON, nested timeouts, over-permissive matcher |
| YouTube | 5.5 | Fork + HEAD fixed, 403 tag + quality invert fixed, sequential manifest |
| Networking | 4.5 | Proxy 842L overkill, leaks, parallel YouTube leak |
| Concurrency | 5.0 | 9 timers, poll loop, 40× unawaited |
| Caching | 4.0 | 4 image caches, put-pair non-atomic, TTL mismatch |
| Artwork | 4.5 | Always w800 decode, 4 caches, casing bug |
| Persistence | 5.0 | Hive untyped Map, late path race |
| Error handling | 4.5 | Log-and-swallow empty==fail |
| Performance | 5.0 | 10 pos events/sec, 300 popups per scroll |
| Memory | 5.0 | BehaviorSubject never closed, HttpClient pool 50 |
| Simplicity | 4.0 | 2625+1583+1004L gods |
| Maintainability | 4.5 | Needs split |
| Testing | 1.5 | 1 test |
| Security | 3.0 | ATS global, bad cert, auth over proxy |

---

## 1. Repository Inventory

| Layer | Exists | Location |
|---|---|---|
| Xcode project | Runner + RunnerTests (empty) 15.1 | `ios/` |
| Swift | AppDelegate 20L + SceneDelegate 12L | `ios/Runner/` |
| Dart entry | Musify → MaterialApp.router → BottomNavigationPage | `lib/main.dart` |
| Navigation | go_router 17.5 StatefulShell 4 tabs | `router_service.dart:51` |
| State | ~25 global ValueNotifiers + 3 BehaviorSubjects | `services/*` |
| Playback | just_audio 0.10.6 + audio_service 0.18.19 + audio_session | `audio_service.dart` 2625L |
| API | youtube_explode_dart fork 3.1.0 + youtube_music_explode_dart vendored + JioSaavn dart_des | `packages/`, `jiosaavn_service.dart` |
| Artwork | CachedNetworkImage 3.4.1 + ArtworkProvider 80 + DefaultCacheManager + ImageCache 48MB | `artwork_provider.dart` |
| Persistence | Hive boxes settings/user/userNoBackup/cache/youtube_auth/saavn_match_cache + tracks/*.m4a | `data_manager.dart` `io_service.dart:24` |
| Tests | widget_test 1 test TrackMatcher, RunnerTests empty | `test/` |

Inherited vs iOS vs New vs AI-debt: see §21 below.

---

## 2. Architecture

```
main() → Hive.init 5 boxes → getApplicationDocumentsDirectory → SourceResolver → AudioService(MusifyAudioHandler→AudioPlayer) → NavigationManager GoRouter → BottomNavigationPage(Home/Search/Library/Settings)

Search UI (SearchPage debounce 300ms suggestions) → Future.wait[fetchSongsList,searchArtists,getPlaylists×2] → SongBar → audioHandler.addPlaylistToQueue → _playFromQueue → playSong
Song {ytid,title,artist,duration,highResImage} → mapToMediaItem(upgradeArtworkUrl w→h, maxres) → _resolvePlaybackSource → fetchSongStreamUrl → cache 45m+50 mem → SourceResolver (search→TrackMatcher→DES→_96→_320) timeout 3s // parallel fetchBestAudioStream → selectAudioOnlyStreamForQuality (M4A/AAC filter, HE-AAC drop) → _cacheSelectedAudioStream → buildAudioSource (headers) → _setAudioSourceAndPlay (setAudioSources preload:false timeout 6s → seek resumeAt → play)
Queue: _queueList (queueEntryId) + _originalQueueList + _history 50 + _currentQueueIndex + loadingId/counter + completion flags → BehaviorSubject queue + mediaItem + playbackState → StreamBuilder mini/track/slider
Persistence: Hive put unawaited + files tracks/artworks
```

DI = global imports, no repository/VM.

---

## 3. Music Pipeline (end-to-end)

**Discovery** ytMusicClient.music.searchSongs → fallback ytClient.search.search("$q audio"), searchArtists via ytClient.search.searchContent, getPlaylists album/playlist, 5× recentlyPlayed videos.get+getRelatedVideos 40 songs, JioSaavn search.getResults n=5.

**API→Norm** returnSongLayout Video→{id:index(!!),ytid,title,artist,image,duration}, JioSaavn _formatTrack title &quot;, artist primary_artists String|List else subtitle, image 150→500, duration parse.

**Resolution** fetchSongStreamUrl forceSource→preference auto→youtube, cache source-specific 45m meta {source,itag,userAgent}, jiosaavnEnabled&&jiosaavn → SourceResolver 2 queries TrackMatcher isExactMatch → DES decrypt → _96→_320, parallel fetchBestAudioStream, else YouTube manifest _fetchStreamManifest [visionOs,androidVr] HEAD validate, sortByBitrate desc bug (now fixed low→last), _cache.

**Playback** optimistic mediaItem+playbackState loading → pause? → resolve → buildAudioSource (headers, ClippingAudioSource end:catalogDuration for every YouTube) → setAudioSources([single],preload:false) timeout 6s → seek resumeAt → unawaited play().

**State** playbackState {playing,processingState idle/loading/buffering/ready/completed, queueIndex, position, buffered, speed} + PositionData {position,buffered,duration} + queue + mediaItem + currentQueueIndex.

**Queue** _queueList sole owner, shuffle clones to _original, history 50, skipToNext/Previous via _playFromQueue, shuffle clones, repeat via _handleSongCompletion repeatOne→playAgain else skipToNext.

**UI** MiniPlayer outer mediaItem + inner fullPlayerStateStream combineLatest playback+queue+position throttle 120ms → 1 frame desync. QueueList queueAsMapStream BehaviorSubject.

**Persistence** Hive + files.

**Background** AVAudioSession .playback allowAirPlay/BT allowBluetoothA2DP in AppDelegate+AudioSession.music(), no interruption/becomingNoisy subscription, no remoteCommandCenter, background fetch only audio, bg download suspended 30s.

---

## 4. JioSaavn Audit

Endpoint: `GET https://www.jiosaavn.com/api.php?__call=search.getResults&_format=json&_marker=0&api_version=4&ctx=web6dot0&n=5&q=` 5s, then `*.saavncdn.com/..._96.mp4` DES ECB 38346591.

Issues:
- JS-01 catch→[] indistinguishable from no results, no logger (high)
- JS-02 body.indexOf('{') fragile HTML (high)
- JS-03 main filters encrypted empty, fallback not (high)
- JS-04 DES FormatException/ArgumentError silent, stale cache never evicted (high)
- JS-05 quality 128→96 mapped but regex replaceAll replaces all _(\d+).mp4 (high)
- JS-06 no HEAD validation for saavncdn expiry (high)
- JS-07 artistMap array shape missed (medium)
- JS-08 image 150/50 only (low)
- JS-09 nested 5/4/1.5s timeouts race, no CancelToken (medium)
- JS-10 n not validated (low)

---

## 5. YouTube InnerTube Audit

**Stack:** youtube_explode_dart fork StreamClient retry 5×500ms, WatchPage GET, Player POST, HEAD stream 403 check.

**Clients:** customClients [androidVr,ios,androidMusic] missing visionOs tokenless first, deprecated androidMusic.

- YT-02 P0 client-tag mismatch manifest tagged androidVr always → googlevideo 403 (fixed but fragile, needs propagated client)
- YT-03 P0 _validateCachedUrl dead, 3h cache serves expired 6h URL → first play fails
- YT-04 Hive vs mem cache duplication TTL 3h vs 1h, FIFO 50 vs 200 not LRU
- YT-05 P0 sortByBitrate descending but low→first (now fixed low→last)
- YT-06 isMp4Family overly broad, webm/opus leak, heAac fallback
- YT-08 useProxy race findProxy='PROXY x; DIRECT' defeats proxy
- YT-09 5 proxies×5s vs outer 8s → starvation
- YT traverses 7-level as Map chain → layout change empty playlist silent
- version skew 1.20240101 vs 1.20230508 vs 2.20220921

---

## 6. Cross-Source Matching

`TrackMatcher.cleanText` brackets +15 noise (hd,hq,full,prod,feat,ft) misses remix/nightcore, asymmetric with formatter. `getTitleCandidates` split only ` - `. `titlesMatch` substring contains length≥3 → "Love" matches "Beloved" false positive. `isExactMatch` empty artist→true, combinedA.contains(cleanArtB) over-permissive, duration >8s reject misses live.

Risk: auto returns wrong cover/remix as exact.

---

## 7. Audio Playback (highest priority)

Tech: just_audio AudioPlayer single, audio_service LoopMode.off manual repeat, ConcatenatingAudioSource for SponsorBlock only, AVPlayer.

- P0 no AudioSession interruption/becomingNoisy listeners, no setActive(true) in play()
- P0 stop cancels debounce not sleep timer → timer fires after pause
- P0 sleep state machine sleepTimerEndOfSong not cleared on setSleepTimer duration, sleepTimerExpired cleared only on ready (not on buffering recovery) → spurious stop
- P1 pause-before-setAudioSource no timeout → AVPlayer hang wedges
- P1 seek coalesce _isSeeking but playAgain bypasses → race, wasPlaying&&!playing auto-resume
- P1 optimistic playing:true hardcoded flash paused→playing 120ms
- See §8/9 for more.

---

## 8. Audio Session / Background

AppDelegate .playback allowAirPlay/BT/BTA2DP before Dart AudioSession.music() double config. Info.plist UIBackgroundModes audio only, no fetch/processing → 3-worker download suspended 30s. No MPRemoteCommandCenter, no beginBackgroundTask, onTaskRemoved setActive(false) but timer armed.

---

## 9. Queue / Playlist State

- clearQueue clones currentSong same queueEntryId into both lists → duplicate id breaks reorder; history not cleared → skipToPrevious reinserts cleared
- addPlaylistToQueue replace:true offset off-by-one when targetQueueIndex null
- _playFromQueue double-guard _completion flags drops user tap
- ProcessingState.completed before debounce + sleepTimerEndOfSong preserved on buffering recovery → spurious stop
- Shuffle aliasing unplayedManualSongs refs mutated via ensureId
- Reorder off-by-one newIndex adjustment missing + key idx unstable
- hasNext ignores repeatAll → disabled incorrectly

---

## 10. Artwork Pipeline

Flow: yt thumbnails standard/low/max → upgradeArtworkUrl w800/maxres, Saavn 150→500, fallback ytimg maxres, artUri on MediaItem → 4 caches.

- C1 H oversized decode w800 always even 52dp mini → ImageCache 48MB thrash, 3 decodes
- C2 H triple cache keys diverge
- C3 M fallback /vi/0/maxres.jpg 404
- C4 M memCacheWidth 256 hardcoded, PlaylistBar none
- C5 M =w\d+-h\d+[^?]* greedy strips query → 403
- C6 M artWorkPath vs artworkPath casing

---

## 11. Music Metadata

Internal model untyped Map 12 keys, provider fields leak, id == index bug, duration int|String|null, artist comma-joined, album null→"null" string.

---

## 12. Caching

| What | Where | Key | TTL | Eviction |
|---|---|---|---|---|
| Song URL | Hive cache | song_<ytid>_<quality>_<source>_url 3h vs janitor 2d | FIFO 200 |
| StreamInfo | mem _selectedAudioStreams | ${ytid}_${quality} 1h | FIFO 50 |
| Saavn match | Hive saavn_match_cache | ytid 1500 FIFO | FIFO |
| Memory | data_manager _memoryCache | cache_$key | per-key 1.5h/5h | FIFO 200 |
| Image | 4 caches | URL/Provider | 200 disk/48MB mem/80 provider | varies |
| Artist search | Hive cache | search_music_artists_v4_$query 24h | FIFO |

Overlap: song key includes source but _selected excludes → wrong quality; saavn_match not cleared on invalidate; stale HEAD never re-validated.

---

## 13. Networking / Async

- search_page Future.wait 4× no debounce on search, typing "arijit" 24 requests, _latestSearchRequest guard drops results but requests already sent
- common_services parallel YouTube future leaked if Saavn wins
- getData loop await per source sequential, Hive openBox per call
- ProxyManager 4 scrapers Future.wait eagerError, 12s + timeout 5s starvation
- No CancelToken; playSong stale guard aborts after fetch but socket stays open
- Retry 5×500ms no jitter
- makeSongOffline http.Client not closed
- lyrics 5 serial endpoints 28s

---

## 14. UI State Management

~25 global ValueNotifiers + 3 BehaviorSubjects + StreamBuilders. Root Locale hardcoded const Locale('en') L10N dead, searchHistoryNotifier global Hive.box at import before init, locale hardcode, BottomNavigationPage offline detect via build+postFrameCallback anti-pattern, MiniPlayer nested StreamBuilders double subscription, PositionSlider mutates State fields during build, FlipCard dead enum.

No single source of truth: current song in mediaItem && queue[index] && recentlyPlayed[0] must sync.

---

## 15. Concurrency

9 magic durations 80/100/120/250/1s/2s/6s/8s/120s overlapping throttle/debounce/heartbeat. poll while(active) delay 100ms busy-wait, unawaited 40×, Completer tail map leak, proxy generation race 2 init overlapping, seek coalesce pending not cancelled.

---

## 16. Memory

BehaviorSubject never closed, audioPlayer never dispose, _queueList 200×2 + history 50 + preload Sets unbounded, _memoryCache 10MB, proxy pool 50 HttpClients 50 sockets, playlist global 180 DB resident, downloadProgressNotifiers ValueNotifier leak.

---

## 17. Error Handling

- JioSaavn: catch→[], DES silent, stale cache never evicted, JioSaavn 3s→YouTube fallback hidden
- YouTube: empty vs error [] same, deleted playlist null→blank, ghost signed-in, getSongManifest timeout→null indistinguishable
- Playback: consecutiveErrors counts stale aborts → 3 fast skips stop, _setAudioSourceAndPlay recursion no error state → loader stuck
- Artwork: base64 10MB sync decode, placeholder asset missing crash
- Persistence: addOrUpdateData two puts non-atomic value without date → data loss on crash, Future.wait 5 boxes fails fast bricks all storage

---

## 18. Performance

Per song start 2 Hive reads + 1-2 JioSaavn GET 5s + 1 YouTube POST+GET+HEAD 3 decodes w800. 10 pos events/sec, 300 popups per scroll, 180 DB always. Library _getRecommendations 5× videos.get no timeout, artist catalog 30 releases batch 5 serial.

---

## 19. Porting Correctness

| Verified | Status |
|---|---|
| Locale hardcode | Regression |
| UIBackgroundModes only audio → downloads suspend | Likely regression |
| AVAudioSession double config Swift+Dart | Verified |
| ProxyManager added after port (new) | New |
| flutter ^3.44.0 non-existent | Verified |
| Hive late applicationDirPath race | Verified |
| NSAllowsArbitraryLoads | Regression |

---

## 20. AI / Vibe-Code Debt

- God objects 2625+1583+1004L
- Multiple layers same job formatter vs TrackMatcher, ArtworkProvider vs CachedNetworkImage
- Unnecessary wrappers 5*Utils
- Speculative fallbacks "$q audio", 4 scrapers
- Arbitrary delays 9 durations, poll
- 5 caches FIFO not LRU
- Untyped Map dumping ground
- Over-defensive Hive.isBoxOpen 20×, stale comments

---

## 21. Dead Code / Duplication

Confirmed unused: encrypt+pointycastle 1.5MB, globalSongs [], _validateCachedUrl dead, listening_stats 28 l10n no service, announcement_box/auto_format_text/dialog_item 0 imports, scripts/checker never CI.
Duplicate: reloadPlaylists 2 funcs, 3 sheet builders, put-pair, artist clean helpers, version drift 3 clientVersions.
Duplicated services: playlists_manager vs playlist_download_service both mutate offlinePlaylists.

---

## 22. Security (secondary)

- Info.plist NSAllowsArbitraryLoads true global ATS off (H) — scope to exception domains
- proxy badCertificateCallback=>true (H)
- findProxy DIRECT leak (H)
- Auth cookies plaintext Hive Documents + UIFileSharingEnabled true → Files app exfiltration (H) — use flutter_secure_storage
- Logger _logs to clipboard no redaction (M)

---

## 23. Configuration / Build

- flutter ^3.44.0 non-existent, lints commented, analysis_options excludes packages/ios, vendored youtube_explode not linted
- build-ios.yml no analyze/test, caches Pods not Specs, tag v4.0 hard vs 6.0.0 drift
- project LastUpgradeCheck 1510 stale, IPHONEOS_DEPLOYMENT_TARGET not set

---

## 24. File-by-File (high-risk)

(see tables in full audit — 30 files sampled, health A-D)

Top risky: audio_service B-, common_services C, proxy_manager D, data_manager B, playlists_manager C, artist_service B, JioSaavn B-, source_resolver B.

---

## 25. Issue Classification (representative)

P0: Locale hardcode main:197 · BG download suspend Info.plist · client-tag 403 common:183 · quality inverted app_utils:152 · ATS global Info.plist:39
P1: interruption missing audio_service:395 · stale cache HEAD dead · TrackMatcher contains · clearQueue duplicate id · reorder off-by-one queue_list:290
P2: 4-layer image cache · put-pair non-atomic data_manager:87
P3: encrypt dead pubspec:22 · flip_card dead enum
P4: styled digit off-by-one

---

## 26. What Should NOT Be Refactored

- just_audio LoopMode.off manual repeat, HE-AAC 2× guard, AudioSession.music() single, go_router shell, formatter regex — leave.

---

## 27. Technical-Debt Map

| Area | Problem | Severity | Source | Consequence | Action |
|---|---|---|---|---|---|
| Playback | No interruption | P0 | Port | Call kills | Add listeners |
| Playback | 2625L god object | P1 | AI | Unmaintainable | Split Queue/Player/Preload |
| Queue | Duplicate id | P1 | Inherited | Wrong skip | Fix clone |
| JioSaavn | DES silent | P1 | New | Stale | Add HEAD |
| YouTube | tag mismatch | P0 | Port | 403 | Propagate client |
| Matching | substring | P1 | New | Wrong song | Jaccard |
| Artwork | 4 caches w800 | P1 | AI | OOM | Single cache |
| Caching | put-pair non-atomic | P1 | Inherited | Data loss | Atomic |
| Networking | 4 scrapers leak | P1 | AI | Battery | Cancel |
| Build | flutter ^3.44 | P0 | Port | pub get fail | Fix |

---

## 28. Scorecard

(overall 4.8 — see header)

---

## 29. Refactoring Roadmap

**Fix Now (P0/P1 Low):** locale, pubspec, client tag, quality last, HEAD, interruption, bad cert, clearQueue id, reorder, image pipeline single cache, data_manager atomic
**Fix Soon (P1 Med):** collapse caches, debounce search, offline verify, Box refs hold
**Clean Later:** split god files, delete proxy/feature-flag, consolidate sheets
**Leave Alone:** LoopMode.off, HE-AAC guard, go_router, formatter

---

## 30. Final Verdict (15 Q)

1. Fundamentally sound? Yes personal-use happy-path.
2. iOS port coherent? Partially Flutter-on-iOS not native Swift.
3. Playback reliable? 70% happy, 40% stress.
4. Biggest playback risks? Interruption, pause-timeout hang, optimistic flash, watchdog 36s.
5. Biggest queue risks? Duplicate id, reorder off-by-one, shuffle aliasing.
6. Biggest JioSaavn risks? Nested timeouts, DES silent stale.
7. Biggest YouTube risks? 403 tag, inverted quality, stale no HEAD.
8. Biggest concurrency risks? 5 streams+4 throttles, poll, unawaited 40×.
9. Biggest caching/artwork risks? w800 thrash, put-pair non-atomic.
10. Inherited? Hive Map, ValueNotifier soup, static DB.
11. Introduced port? Locale hardcode, ATS, late path race.
12. AI debt? God files, 5 caches FIFO, 842L proxy off-by-default.
13. Rewrite? No full rewrite; split god files; consider deleting ProxyManager.
14. 10 highest-value fixes: locale, pubspec+CI, tag+quality, HEAD, interruption, ATS/cert, clearQueue+reorder, single image cache+DPR, atomic cache, debounce search.
15. 10 things to stop worrying: LoopMode.off, go_router, HE-AAC guard, DynamicColor, Flutter vs Swift, fastlane metadata, paytone license try/catch, UA version skew, FF10 digit, Spotify DB fallback.

---

## 31. Static-Only Limitation

Requires compiling flutter build ios, running iPhone lock-screen/interruption/headphones/Bluetooth, real JioSaavn/YouTube InnerTube responses, Instruments Leaks/Allocations, AVPlayerItem duration override test, background download suspend, go_router deep link verification.

