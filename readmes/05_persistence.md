# 05 — Persistence (`database/*`, Hive, playlists)

## Purpose

* **`database/playlists.db.dart:1` 465L + `albums.db.dart:1` 876L** — Static seeded `List<Map>` 96+130 YouTube playlists/albums `{ytid,title,image,list:[]}` merged into global `playlists` `playlists_manager.dart:22`.
* **Hive boxes:** `settings`, `user`, `userNoBackup`, `cache`, `youtube_auth`, `saavn_match_cache` — managed via `data_manager.dart:1`.
* **`playlists_manager.dart:1` (1562L)** — CRUD for `userPlaylists List<String>`, `userCustomPlaylists/userLikedPlaylists/userPlaylistFolders List<Map>`, discovery `getPlaylists(query)` + YT search fallback, `getPlaylistInfoForWidget` 5-step resolve, `getSongsFromPlaylist`, `renameSongInPlaylist`, `togglePinnedPlaylist`.
* **`playlist_download_service.dart:1` (602L)** — `OfflinePlaylistService` 3-worker `makeSongOffline` queue, `offlinePlaylists ValueNotifier` `userNoBackup` box, `downloadProgressNotifiers Map` per playlist.

## Call graph

* `playlists.db + albums.db` → `playlists_manager` global `playlists` (lazy `list:[]` filled via `getSongsFromPlaylist`).
* `playlists_manager` ← UI `library`, `playlist_page`, `artist_page`, `home` → `ytClient.playlists.get` (via ProxyManager) + `YouTubeMusicSyncService.fetchPlaylistTracks` + `data_manager getData('cache','playlistSongs$Id')` 5h.
* `playlist_download_service` ← `playlist_page download` → `common_services.makeSongOffline` → `io_service FilePaths`.

## Comments removed

```
 // Sorting / Search / Search root list first, then inside folders. — playlist_page.dart:63/434/451
// Update offline playlist if it exists — 476
// Neither an artist nor a release ... refreshed by dropping cache entry — 518
// Restore original order from backup — 607
```

(No `//` in `playlists.db`/`albums.db` beyond data.)

## Verification vs auditfinal

* **FIXED** `addOrUpdateData:72` cache `putAll` atomic for `cache` category (date+value same tx); non-cache still single `put`.
* **FIXED** deep-link size guard `PlaylistSharingService` now `65536` limit (via `main.dart:399`) covers `playlist_sharing` encode overflow.
* **NOT FIXED** global `playlists` `contains` identity add duplicate unbounded `playlists_manager.dart:22` `_loadSongsForPlaylist:1241`.
* **NOT FIXED** `offlinePlaylists` initializer `playlist_download_service.dart:30` `Hive.box('userNoBackup').get` at field init before Hive open (returns `[]` forever until `reloadOfflinePlaylistsFromStorage` — called now in `main.dart:301` so mitigated but still fragile).
* **NOT FIXED** `downloadProgressNotifiers` never `remove`+`dispose` `playlist_download_service.dart:509` leak; `activeDownloads List` not Set duplicate `524`.
* **PARTIALLY FIXED** `cleanupOldCacheEntries:174` still `DateTime.now()` per key but `2 days` sweep ok; `saavn_match_cache` trim `217` still sequential `delete` per key.

## Storage

* Audio `tracks/*.m4a` + `artworks/*.jpg` in `applicationDirPath` (`Documents`) — visible via `UIFileSharingEnabled` (`Info.plist:33`).
* `userNoBackup` correctly non-backed but audio files still in `Documents` → iCloud/backup leak.
