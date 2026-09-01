# 02 — Audio Subsystem (`lib/services/audio/*` + shim)

## Purpose
Single `MusifiedAudioHandler` `lib/services/audio/musified_audio_handler.dart:29` (2545L) — `BaseAudioHandler` → `AudioPlayer` (just_audio/AVPlayer). Queue, playback, preload, browse/CarPlay, shuffle/repeat/sleep, gapless concat, source switch, interruption.

`lib/services/audio_service.dart:1` is a re-export shim: `export 'audio/musified_audio_handler.dart';`

## Sub-modules

| File | Purpose | Who calls | Whom it calls |
|---|---|---|---|
| `audio.dart:1` | Barrel `library;` 10 exports | UI/test | — |
| `playback_source.dart:1` | Value ` {songUrl,isOffline}` | `AudioPlaybackCoordinator:209` `MusifiedAudioHandler:1954` | — |
| `audio_queue_state.dart:3` | Mutable `items/originalItems/history 50/currentIndex/loadingIndex/Key` | `AudioHandlerHub`, `AudioQueueController`, `MusifiedAudioHandler` | `queue_entry_utils` |
| `audio_queue_controller.dart:5` | Pure list mutations | Handler via `AudioHandlerHub` | `AudioQueueState` |
| `audio_preload_cache.dart:1` | `activeCount, preloadingYtIds, preloadedYtIds, streamUrls` | `AudioPreloadService` | — |
| `audio_preload_service.dart:7` | Pre-resolve next 1 URL via `fetchSongStreamUrl` | `AudioHandlerHub` via `_preloadUpcomingSongs:1444` | `common_services`, `app_utils isUsableYoutubePlaybackUrl` |
| `audio_browse_catalog.dart:5` | Lock-screen/CarPlay browse IDs + song lookup | `MusifiedAudioHandler` `_findSong*` | `mapToMediaItem` |
| `audio_playback_coordinator.dart:39` | Offline vs online URL, `AudioSource` build, `just_audio` install, gapless retry | `MusifiedAudioHandler` | `AudioPlaybackInstall`, `common_services` |
| `audio_playback_install.dart:9` | Builds `AudioSource` (Clipping for HE-AAC) | Coordinator | `just_audio` |
| `audio_handler_hub.dart:6` | Composition root `AudioQueueState + AudioPreloadCache + lookahead=1` | `MusifiedAudioHandler` | — |
| `musified_audio_handler.dart:29` | Central handler (see §) | `main.dart`, UI via `audioHandler` global | All above + `AudioSession`, `Hive`, `RxDart` |
| `audio_completion_coordinator.dart:124` | `ProcessingState.completed` + near-end 450ms + error retry | Handler | — |

## Comments removed (verbatim sample)

```
/// Musified audio playback module. — audio.dart:1
/// Resolved playback target for a queue item (local file or remote URL). — playback_source.dart:1
/// Mutable queue/history state for [MusifiedAudioHandler]. — audio_queue_state.dart:3
/// Identifies the track currently loading ... — audio_queue_state.dart:24
/// Pure queue list mutations — no playback, no streams. — audio_queue_controller.dart:5
/// Replace queue with a single track (search / tile tap). — 45
/// Clear queue but keep the currently playing row ... — 64
/// Pre-resolved stream URLs for upcoming queue items. — audio_preload_cache.dart:1
/// Stream URL preloading. Only talks to [AudioPreloadCache] ... — audio_preload_service.dart:7
/// Lock-screen / CarPlay browse IDs and song lookup helpers. — audio_browse_catalog.dart:5
/// Gapless install inputs ... — audio_playback_coordinator.dart:16
/// Resolves URLs, builds sources, and installs them ... — 39
// iOS AVPlayer returns -1004 if we load a new googlevideo URL while the previous item is still attached. Stop first unless gapless concat. — 355
/// Track completion, near-end advance, and playback error recovery. — audio_completion_coordinator.dart:124
// Resolve only the next item, and never compete with the foreground load. — musified_audio_handler.dart:69
/// Single cached combine so mini-player rebuilds do not recreate subscriptions. — 133
// Detect iOS CoreAudio / AVPlayer HE-AAC SBR timescale doubling — 358
// A duration event from the previous AVPlayer item must never restore that item's title ... — 604
// Phone call / Siri — not lock screen. Locking must not pause. — 679
// Fresh-track load: the player still holds the previous song's position ... — 743
// A brand-new track resets to 0 ... — 1204
// Drop in-flight YouTube preloads so a skip does not compete with them. — 1361
// Do NOT await play(): its future only completes when playback pauses/... — 1676
```

Full list 80+ comment lines; all `///` + `//` above would be stripped.

## Verification vs auditfinal

* **FIXED** `queueItemCount.dispose()` double → single `dispose:328`.
* **FIXED** `cleanupStaleForYtids:32` now `if (activeCount>0) activeCount--`; leak that caused `while(activeCount>=max) 100ms` infinite loop resolved.
* **FIXED** `isUsableYoutubePlaybackUrl` now checked in `preloadSingle:123` + `resolveNextStreamUrl:155/165/187` — gapless won't install expired URL.
* **FIXED** `AudioSession` listeners `interruptionEventStream:670` (duck/pause) + `becomingNoisy:698` pause.
* **PARTIALLY FIXED** `put-pair` atomic: cache category via `putAll` in `data_manager.dart:72` (see `05_persistence.md`); gapless `ClippingAudioSource` still for every YouTube URI `musified_audio_handler.dart:2688` — pipeline reset gap remains (P1).
* **NOT FIXED** `reorder:122` off-by-one still in controller, `originalItems` desync `adjustIndicesAfter*`, `Stack` `AVAudioSession` double config with Swift (needs delete Swift `setCategory`).

## Open P1s still

* Near-end window `0..450ms` `audio_completion_coordinator.dart:244` vs throttle 100ms still can miss on 250ms `distinct`.
* `consecutiveErrors` no sliding window `audio_completion_coordinator.dart:291`.
