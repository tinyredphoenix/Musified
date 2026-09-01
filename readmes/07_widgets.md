# 07 — Widgets (`lib/widgets/*` 47 + `now_playing/`)

## Purpose
Reusable UI: `song_tile`, `playlist_bar/cube/artwork`, `artist_bar/shelf`, `mini_player` (Backdrop blur 20), `queue_list_view` (Reorderable), `position_slider` (`Rx.combineLatest`), `now_playing` controls/artwork/lyrics, `marquee`, `flip_card`, `download_picker_sheet`, etc.

## Call graph

* `MiniPlayer` ← `BottomNavigationPage` `Stack` → `audioHandler.mediaItem/playbackState/positionData` streams, `NavigationManager` push `NowPlayingPage`.
* `SongTile` ← `SearchPage`/`Home`/`PlaylistPage` → `CachedNetworkImage`, `currentPlayingYtid` ValueNotifier per tile.
* `NowPlayingControls` (`501L`) ← `NowPlayingPage` → `audioHandler` skip/play + `NowPlayingArtwork` `320L`.
* `SyncedLyricsView` (`481L`) ← `NowPlayingPage`/`FullPageLyricsModal` → `LyricsManager.getSongLyrics` 5 endpoints 28s.
* `PositionSlider` `166L` → `Rx.combineLatest2(mediaItem,positionData)` distinct 250ms.
* `QueueListView` `401L` → `audioHandler.queueAsMapStream` + `currentPlayingYtid`.

## Comments removed (sample)

```
// Kept for API compatibility; unused after dropping 3D rotate. — flip_card.dart:39
// Shares the complete catalog ... — artist_page sink via now-playing?
```

Most widgets have minimal `//` — ~80 lines total.

## Verification vs auditfinal

* **NOT FIXED** `SongTile:67` `CachedNetworkImage` without `memCacheWidth` full-res for 48px row (6×); `Library 230` same 640px for 140px thumb; `ArtworkProvider` still 80 LRU diverged keys `maxres` vs `w800`.
* **NOT FIXED** `Marquee wantKeepAlive true` `marquee.dart:33` retains controller loop; `FlipCard` `AnimatedSwitcher 280ms` key bool not mediaId flicker `auditv2 4.1`.
* **NOT FIXED** `PositionSlider` `Rx.combineLatest` holds `MediaItem` ref after stop prevents GC; mutates State during build anti-pattern.
* **NOT FIXED** `QueueListView` `estimatedItemHeight 60` offset error at index 100.
* **NOT FIXED** `DownloadPickerSheet 94` mutates `_selectedQuality` during `build` (setState during build).

## Risks

* `PlaylistBar 243` `ArtworkProvider.get(data:image;base64)` without try/catch crash for base64 playlists (try/catch only in `playlist_artwork:34`).
* `ArtistShelf 43` `textScaler` overflow beyond `cubeSize+labelsHeight`.
