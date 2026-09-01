# 11 — Packages (`packages/youtube_explode_dart`, `youtube_music_explode_dart`)

## Purpose

* **`youtube_explode_dart/lib/src/reverse_engineering/**/*`** — Fork of `youtube_explode`. `YoutubeHttpClient:15` central `http.BaseClient` retry 5×500ms `consent YES+cb`, `WatchPage:138` `watch?v=` + `ytCfg STS`, `PlayerResponse:142` `json.decode` → stream/cipher, `PlayerSource:35` `base.js` cache, `cipher_manifest`/`cipher_operations` `s=` regex `base.js` decipher, `challenges/js_challenge` `DenoEJSSolver` `n`/`sig` `base.js` eval via `deno repl` tmp files, `DashManifest/HlsManifest` 20% HLS `itag` parse, `heuristics:30` `low240→low144` bug.
* **`youtube_explode_dart/lib/src/**` non-RE — `youtube_explode_base:9` facade, `retry:11` cost model, `youtube_api_client:19` 11 spoofed clients (`VISIONOS 1.02` sole via `youtubeStreamClients()`), `video_controller:30` `STS`+`visitorData` `sw.js_data data[0][2][0][0][13]`, `stream_client:89` manifest+`solveBulk`+HEAD per adaptive `validate:false`.
* **`youtube_music_explode_dart/lib/src/**` — `music_client:146` `WEB_REMIX 1.20240101` browse/search, `youtube_music_explode_base` re-export.

## Call graph

* `YoutubeHttpClient` ← `YoutubeExplode`, `VideoController`, `StreamClient`, `WatchPage`, `ProxyManager(IOClient)` → `http.Client.send`.
* `VideoController`/`StreamClient` → `PlayerResponse` → `CipherManifest` → `DenoEJSSolver`.
* `SearchPage`/`PlaylistPage`/`ChannelClient` → `YoutubeHttpClient`.
* `MusicClient` ← `playlists_manager.getArtistCatalog`/`resolveArtist` indirectly, `YouTubeMusicSyncService` directly.

## Comments removed (sample 60+ lines)

```
// DASH(fragmented) stream / Normal stream / This is the base url — youtube_http_client:150-180
// NOTE: `headers` was previously accepted but never applied here ... — 218
/// Sends a call to the youtube api endpoint. — 298
// This was used in old youtube versions. — comments_client:61
// Guard against infinite loops with a stuck token. — playlist_page:40
// TODO: Implement player response extraction ... — watch_page:122
```

## Verification vs auditfinal

* **NOT FIXED** `player_source:35` unbounded `Map<String,_CachedValue>` leak; `deno_ejs_solver:24` tmp not cleaned on failure, `dispose:71` no await, broadcast leaks.
* **NOT FIXED** `heuristics:30` `240p→low144` bug; `DashManifest:152` `UnimplementedError` live; `cipher` `\d{5}` brittle now 6 digits.
* **NOT FIXED** `youtube_api_client:19` frozen `VISIONOS 1.02 26.0` Aug 2025 — single pin no fallback, will 403 on `poToken` enforcement.
* **NOT FIXED** `watch_page:101` `firstMatch!` crash on consent HTML; `youtube_http_client:243` new manifest resume mismatched `ytClient`.
* **NOT FIXED** `music_client:146` `WEB_REMIX 1.20240101` pinned Jan 2024 + recursive `_findRenderers:754` StackOverflow.
* **DMCA** exact `cipher/` + `player_source` + `StreamClient` extraction are `1201` anti-circumvention cited in `auditfinal.md:8` — repo takedown vector.

## Notes

* `hls_manifest:30` `RegExp('([^,]+)=("[^"]*"|[^,]*)')` mis-parses `CODECS` commas inside quotes.
* `ytdlp_client_sync` single `visionos` now correctly fetched but brittle `"'visionos': {"` parse `04_network_proxy_youtube.md` still.
