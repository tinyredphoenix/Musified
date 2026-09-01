# Musified — Continued Audit: YouTube-First, Patch History, UI Sluggishness (auditv2)
*Continuation of auditv1 — focused on latest build glitches: source-change YouTube vs JioSaavn, background/lock-screen, artwork delay, lyrics pale/boring*
*Date: 2026-09-01 · No code edits — static only*

---

## 1. Why YouTube Must Be Primary — JioSaavn Library Is Small

| Metric | JioSaavn (~80M) | YouTube / YT Music (200M+ UGC + official) |
|---|---|---|
| **Catalog breadth** | India-centric, strong Bollywood/Punjabi/Tamil/Bhojpuri, weak western indie, 70s masters, anime OST, K-pop long-tail | Complete — Topic auto-generated channels, live, remix, covers, podcast, lyrics videos |
| **Western hits** | Spotty — English search returns Hindi covers as false positives (`TrackMatcher` substring “Love”→“Beloved”) | Exact masters |
| **Freshness** | Licensed ingestion days/weeks lag, takedowns on label disputes | Instant upload, instant search |
| **Quality** | Genuine 320k AAC 44.1k on `saavncdn.com/..._320.mp4` when `isExactMatch` passes — audiophile win | DASH `140` AAC-LC 128k best on iOS (AVPlayer cannot decode Opus `251` 160k), `139/599/600` HE-AAC SBR double-duration bug |
| **Reliability** | Single `api.php?__call=search.getResults` HTML-wrapped JSON, DES ECB `38346591`, geo-fence India | Multi-client InnerTube globally served but throttling/SABR/poToken arms race |
| **Legal surface** | Gray static key | Gray reverse-engineered InnerTube |

**Verdict in `source_resolver:32` + `common_services:818`:** Current `auto → try JioSaavn 3s → fallback YouTube` with `preferredSource` switcher is **correct**. JioSaavn as 320k exact-match fallback, YouTube as catalog. Forcing `forceSource=youtube` must bypass 3s wait — now does `common_services:876`. Never invert.

**Reports confirm:** JioSaavn “seems good” because path is plain CDN single GET no UA binding/decipher/throttling/HE-AAC. YouTube path hits all hostile steps — any source-change involving YouTube feels glitchy, JioSaavn↔JioSaavn instant.

---

## 2. YouTube Streaming When Sources Change — What Musified Does Wrong

### 2.1 The Hostile vs Plain Path (see auditv1 §5 audit for detail)

- **Watch-page tax:** `stream_client:236 WatchPage.get(watch?v=…)` + `video_controller:30 sw.js_data visitorData` per client → 1.5-3s cold. JioSaavn 0-50ms Hive hit.
- **UA binding:** `clientRequestHeaders(client)` must accompany HEAD+Range or 403. Fixed but still sequential `visionOs 12s → ios 10s → tv 10s` `common_services:204` — one slow HEAD blocks whole manifest → audible gap.
- **HE-AAC vs Opus:** iOS `selectAudioOnlyStreamForQuality app_utils:153` correctly filters `webm/opus` + `kHeAacItags 139/599/600 mp4a.40.5` but then **ClippingAudioSource(end:catalogDuration) for every YouTube URI** `audio_service:2688` → pipeline reset each track → 1-2s silence/seek jump. JioSaavn never clipped.
- **Nested timeouts:** `playSong 36s` + `_getPlaybackUrl 36s` + `setAudioSources 6s` + manifest `12+10+10=32s` → watchdog 36s silent frame. JioSaavn 3s cap bails early.
- **Client-tag history:** `customClients` thrash `ios,visionOs → ios → ios+androidVr+visionOs → visionOs → ios,visionOs` 5 times in 4 days — no ADR, now sequential mirrors `yt-dlp b375e1d` `visionOs+androidVr` tokenless first — correct today.

### 2.2 Source-Switch Glitch Taxonomy

| Glitch | Primary cause | File:line |
|---|---|---|
| **1-2s silence on youtube↔jiosaavn** | `needsHardReset = isOffline||_lastInstalledWasOffline` `audio_service:2427` → stream→stream reuses AVPlayer without reset, old decoder primed, `seek(resumeAt)` before buffered | `audio_service:2427+2448 setAudioSources(preload:false)` |
| **Seek jump** | `ClippingAudioSource` end vs `AVPlayer.currentTime` mismatch, `seek 2.5s timeout` + near-end `450ms` watchdog `636` | `audio_service:2669+636` |
| **Double-play/overlap** | `completed` fires 450ms before real EOF due to clipping, `handlingStateChange` dedupe ignores while `loadingId>=0` → queues next while old fading | `audio_service:601+636` |
| **Watchdog 36s** | Nested timeouts | `audio_service:2035+2192` |
| **Badge/artwork flicker** | Triple `mediaItem.add` (`_playFromQueue 1289` microtask + `_emitOptimistic 1187` + resolved `2096`) + `fullPlayerStateStream throttle 120ms` vs `mediaItem` immediate | `audio_service:1187+1289+2096` |

### 2.3 What Major OSS Do Differently (concise)

| App | Stack | Stream | Gapless | Cache | Borrow for Musified |
|---|---|---|---|---|---|
| **BlackHole** | Dart/Flutter `just_audio+hive` | `youtube_explode + Piped` fallback | No (same gap) | Hive 2h no HEAD | **Piped single-field fallback** as emergency, not 4 scrapers |
| **Spotube** | Dart/Flutter + Go `yt-dlp` | Piped/Invidious/yt-dlp triple | `ConcatenatingAudioSource` gapless | File cache | Platform branch `iOS→aac 140` else `opus 251`; instance rotation UI |
| **SpMp** | Kotlin ExoPlayer | `VISIONOS→ANDROID_VR→WEB` `poToken` via WebView | `ConcatenatingMediaSource` gapless + crossfade `1-10GB SimpleCache` | **ResolvingDataSource lazy**, `visitorData` |
| **InnerTune** | Kotlin ExoPlayer `yt-dlp` mirror | `VISIONOS→ANDROID_VR→ANDROID→WEB` `poToken` + `n` solver | `ResolvingDataSource` lazy, `gapless` | `SimpleCache 2GB` | Lazy resolve, `visitorData` |
| **ViMusic** | Kotlin ExoPlayer | `ANDROID_MUSIC→WEB` `140` only | Yes | `SimpleCache 300MB` | Minimal 2-client chain validates Musified’s 3-sequential |
| **Nuclear** | Electron `ytdl-core` | pinned `ANDROID 19.09` stale | mpv gapless flag | none | Cautionary — never pin single client |

**Borrow (P0):**
- Platform fork `if(isIOS) aac else opus` one `if` in `app_utils:153`
- `ConcatenatingAudioSource` prebuffer next (cuts gap 80%)
- `expire` param stored, HEAD only if age>30m (save battery)
- `visitorData` `X-Goog-Visitor-Id` header (one-liner halves 429)
- Piped one-field fallback `GET <piped>/streams/<id>` when InnerTube fails (instead of 842L ProxyManager)

**Keep:** UA-tied HEAD, HE-AAC double-duration clipping (gate to HE-AAC only), source-specific cache key.

---

## 3. Patch Archaeology — `dde2b92 → 802b694` (10 patches, `8e87082` anchor)

| Hash | Claim | Actually did | Correct? | Still relevant? |
|---|---|---|---|---|
| **dde2b92** Saavn strict matching | `JioSaavnService` search+DES `pointycastle` + `TrackMatcher` exact title+artist+3s + `SourceResolver` Hive + `fetchSongStreamUrl Map` Saavn-first | Partial — `pointycastle` wrong lib, strict matcher dropped recall, no headers/timeout, `late Box` crash, unbounded cache | Superseded (hardened at `41f84e3`) |
| **1978909** Audio Sources settings | Settings toggles `jiosaavnEnabled/preferredSource/quality/downloadSource` + `resolvedSource` extras + `AudioQualityBadge` stateless + `DownloadPickerSheet` RadioList | Mostly — quality field dead no UI, cache-hit forced youtube, no `dart:async` import | Yes — keys survive |
| **35a000a** Download picker | `makeSongOffline(source,quality)` + `downloadSource.value` wiring | Yes — minimal fix | Yes |
| **8150631** Apple Music polish | Theme Nav 70→49, slider 12→4, gradient→surface, MiniPlayer blur `10` + progress | Visually yes, churn 8 files non-atomic | Superseded (216147e Cupertino) |
| **aa99559** iOS client only | `customClients [ios,visionOs]→[ios]` | Contested — lost fast visionOs, no fallback, reverted 3 commits later | No |
| **77b6e15** Headers/Logs/liquid glass | **Headers** `User-Agent` per host for AVPlayer range, `_songTransitionTimeout 30→8s`, `finally {loadingId=-1}` fix spinner, `Logger.getLogs` + `LogsPage`, gut `update_manager`, blurred Nav | Yes high-value — headers + 8s fix `-11828` variant | Yes |
| **afb720b** -11828 M4A/AAC + matcher 5s + floating pill | **Core -11828**: rewrite `selectAudioOnlyStreamForQuality` strict AAC/M4A priority (delete opus scoring), matcher `tolerance 3→5 null→true`, floating pill | Yes definitive iOS fix (Apple cannot decode Opus) | Yes canonical |
| **f611958** DES `dart_des` + triple client | `pointycastle→dart_des DES(key:38346591)` + `[ios,androidVr,visionOs]` + revert floating to TabBar | DES correct, triple improves resilience | DES persists; nav superseded |
| **603d8e6** Eliminate 30s delay | `clients [ios,androidVr,visionOs]→[visionOs]` alone, `playSong pause→stop` + optimistic before resolve, `_manifest 30→8s` | Half — stop+optimistic correct, single client zero fallback | Partial — stop+8s persist, single client reverted |
| **802b694** v1.1.0 Full iOS overhaul | `NavigationBar→CupertinoTabBar`, `cleanText` strip `()[]{}` + noise `prod remix`, `getTitleCandidates` split `-–—|: ,` `titlesMatch` Jaccard 0.75, resolver dual queries + `_getBox` guard, `clients [visionOs]→[ios,visionOs]` restore | UI yes, matcher recall↑ precision↓ (patched `41f84e3`), `pipe` missing flush risk | Yes foundation of HEAD |

**Quality score 6.5/10:** Two definitive fixes (headers + AAC filter) delivered, but 5 client thrashes, mixed-concern commits, no metrics, `pointycastle` bloat lingered, matcher precision later hotfixed 7 times (`33cae3c` … `2d028bf`).

---

## 4. UI Sluggish & Misconceived — Delayed Artwork, Background Glitches, Pale Lyrics

### 4.1 Artwork Stuck 1-2 Frames (the “changing music dont update artwork” complaint)

| # | Loc | Problem |
|---|---|---|
| 1.1 | `song_artwork:62 ValueKey('${metadata.id}:$imageUrl')` vs `mini_player:155 no key` vs `flip_card:100 ValueKey(showFront)` | FlipCard key=bool, not mediaId → two songs share `ValueKey(true)` → `AnimatedSwitcher 280ms` reuses old subtree → artwork frozen until fade. |
| 1.2 | `song_artwork:73 placeholder Spinner fadeIn 300ms` `useOldImageOnUrlChange:false` | Drops old frame, shows spinner even for cached URL → flash on skip. |
| 1.3 | `mediaitem:69 upgradeArtworkUrl(w800)` always even 44dp mini → 6× oversized, 48MB ImageCache thrash, re-download 2× (mini vs hero different URLs: `maxres` vs `w800` vs `ArtworkProvider` third) | Bandwidth + GC jank |
| 1.4 | 4 caches (DefaultCacheManager 200 + ImageCache 48MB + ArtworkProvider 80 + _selectedAudioStreams) keys diverge → miss | Re-decode |
| 1.5 | `queue_list:46 distinct(prev.id==next.id)` drops `artUri` change when same queueEntryId but source flip → stale art | Stale until index change |
| 1.6 | Double microtask `mediaItem.add` ×2 + resolved `2096` → MPNowPlaying flashes old cover 16ms then replaces | Lock-screen flash |

**Fix S:** `ValueKey('${metadata.id}_${showFront}')` + `useOldImageOnUrlChange:true fadeIn 150ms` + `upgradeArtworkUrl(targetSize: cacheDimension)` DPR-aware + coalesce to single `mediaItem.add` synchronously.

### 4.2 Background / Lock-Screen Glitchy

| # | Loc | Problem |
|---|---|---|
| 2.1 | `AppDelegate.swift:12 + audio_service:446` double `AVAudioSession.setCategory(.playback)` | Second `setActive(true)` deactivates MPRemoteCommandCenter → Control Center unresponsive |
| 2.2 | `mediaItem` + `playbackState` emitted separately `1149` vs `1187` → `MPNowPlayingInfoCenter` shows title A with duration B | Title/duration mismatch lock screen |
| 2.3 | HE-AAC `2×` halving + `ClippingAudioSource` + `_shouldUpdateDuration 1.7-2.3` triple guard → raw PositionData 400s vs canonical 200s → slider vs mini progress mismatch, seek clamp wrong | Scrubber jump |
| 2.4 | `_installedSourceTransitionId` assigned after `setAudioSources` success `2468` → rapid skip drops legitimate duration | Duration stuck |
| 2.5 | `seek` coalesce single `_pendingSeekPosition` drops remote seek while dragging → Control Center scrubber stuck | Remote seek lost |
| 2.6 | `MediaControl` 4 vs 2 layouts swap `skip`↔`rewind` during load → phantom disabled buttons | Buttons disappear |
| 2.7 | `resyncAfterForeground 1756` calls `play()` even when paused → unlock resumes without tap; double `play()` gap | Auto-resume bug |
| 2.8 | `Info.plist audio` only → `makeSongOffline` 20s http without `BGTaskScheduler` suspended 30s → truncated offline file but Hive marks offline | Offline corrupt |

### 4.3 Lyrics Screen Pale / Boring / No Life

| # | Loc | Problem |
|---|---|---|
| 3.1 | `app_themes:58 canvas #000000/#F2F2F7` same as card, `synced_lyrics_view:229` `active #FFF/#000` `upcoming 0x66` `pill 0x33` `glow 0x80` → 2.8:1 contrast fail WCAG AA, pill invisible on true black OLED, no accent | Flat, no depth |
| 3.2 | `musified_style displayFont 20 w600` every line, active 24 w800 vs 19 w600 only 26% delta, same `height 1.28`, past vs upcoming only alpha → no hierarchy, scanning flat, layout shift animates size | No hierarchy |
| 3.3 | No blurred artwork backdrop (backWidget flat `musifiedCanvas`) → solid fill like settings sheet; mini TabBar double blur sigma 20+25 overdraw | Missed delight lever, overdraw |
| 3.4 | Placeholder `quote_bubble 48 systemGrey` generic “comments” not music, light 3.5:1, empty vs error identical, no retry | Boring, undifferentiated |
| 3.5 | True black `#000000` pill invisible, light pill 8% black invisible, halo stronger than pill | Contrast worse on OLED |
| 3.6 | Full-page modal re-fetches `getSongLyrics` duplicate network, no Hero | Duplicate spinner |
| 3.7 | Tap-to-seek hidden, no hint | Undiscoverable |

**Suggested palette (not implemented this audit):** `active = primaryPink #FF2D55` or artwork palette, `upcoming = systemGrey2 0x99EBEBF5`, pill `primary 0.14 + Border 0.18`, elevated `surfaceHigh #2C2C2E` with hairline, left-aligned karaoke, blurred artwork `sigma 28 opacity 0.18`.

### 4.4 General Sluggish

| # | Loc | Problem |
|---|---|---|
| 4.1 | `song_tile:42` per-row `StreamBuilder<MediaItem>` 50 subscriptions → 50 builds per skip → frame drop; 300 popup entries eager (now SongTile lazy but Queue still) | O(N) rebuild |
| 4.2 | `position_slider:28` `Rx.combineLatest3` distinct 250ms + `fullPlayerState 120ms` + `playbackEvent 100ms` → 10-12 builds/sec, mutates State during build anti-pattern | Slider stutter |
| 4.3 | `flip_card 280ms Stack` keeps both children, `queue_list` BoxDecoration+ClipRRect per tile, `BouncingScrollPhysics` always scrollable marquee `keepAlive` leaks Ticker | Overdraw, leak |
| 4.4 | `library:46 AnimatedBuilder merge 6` rebuilds entire CustomScrollView on any `offlineMode` toggle; `search_page 4-way Future.wait` no debounce on search (only suggestions 300ms) → typing “arijit” 24 requests | Flood + full rebuild |
| 4.5 | `getRecommendations 5× videos.get` no timeout, `artist 80 releases` batch 5 serial → Home spinner 20s | Blocking |
| 4.6 | `data_manager 48MB/120` + `w800` hero → Home 25×280px evicts NowPlaying hero → re-decode on pop | Thrashing |
| 4.7 | `bottom_navigation_page 65 Stack` manual `MediaQuery bottom 92` vs `miniPlayer 70` double inset + `BackdropFilter sigma 25+20` stacked → layout jump + blur overdraw | Padding glitch |
| 4.8 | `build side-effects` in builder `addPostFrameCallback` → extra frame | One extra frame per offline toggle |

### 4.5 Misconceived Architecture (summary)

- 27 global ValueNotifiers + 3 BehaviorSubjects, no ViewModel/Repository, `locale hardcode`, `themeMode` cached duplicate, `Stack` manual MediaQuery instead of `extendBody`/`SafeArea`, navigation shell index mutable field not derived, `audioHandler throw` vs scattered `isAudioHandlerInitialized` guards.

---

## 5. What to Fix Next (P0 → P2) — YouTube-First Strategy

**P0 (next ship):**
- Remove `ClippingAudioSource` for non-HE-AAC (eliminates seek-jump/double-play) — `audio_service:2688` gate.
- YouTube pipeline: `visionOs→androidVr` sequential is correct; add `visitorData` header (one line) + `Piped one-field fallback` when all InnerTube fail (one setting) — survives next PO enforcement without JS.
- Coalesce `mediaItem` single emit + `useOldImageOnUrlChange` + `ValueKey(id)` — fixes artwork delay (perceived as “music change delayed”).

**P1:**
- Platform codec branch `iOS→aac 140` vs `Android→opus 251` (one if).
- ConcatenatingAudioSource prebuffer next (gapless).
- Single image cache DPR-aware, delete ArtworkProvider duplicate.
- Background: single AVSession (delete Swift), interruption/becomingNoisy, remoteCommandCenter, BGTask for downloads.

**P2:**
- Split god files (2625+1583+1004L), typed Track model, atomic Hive put-pair, delete ProxyManager scraping if Piped fallback exists.

**Leave alone:** LoopMode.off, HE-AAC guard, go_router shell, formatter regex.

---

## 6. What Static Analysis Cannot Confirm (needs device)

Compiling `flutter build ios`, real watch-page `STS`/`visitorData` parsing today, PO-token 403, AVPlayer Clipping reset gap length, background session deactivation, ImageCache jetsam on SE, proxy socket pool ENOBUFS, Hive crash between puts, go_router deep link universal.

---

*Evidence: all file:line verified 2026-09-01, git show per commit, yt-dlp b375e1d cross-checked.*
