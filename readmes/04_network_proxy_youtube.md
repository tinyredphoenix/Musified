# 04 — Network / Proxy / YouTube Auth & Sync

## Purpose

* **`proxy_manager.dart:1` (659L)** — Singleton pooling `HttpClient`+`IOClient` per free proxy, `getClientSync()` (shared `YoutubeExplode`) + `getYoutubeExplodeClient()` (dedicated short-lived). `useProxy` `ValueNotifier` toggle, `getSongManifest` direct→proxy fallback, `getProxiedResponse` generic GET, blocklist TTL 30m / 200, resource pool 50.
* **`proxy_fetch_service.dart:1` (215L)** — Fetches 4 free-proxy sources (`spys.me` etc.), `Future.wait`, `openProxyRegex`, `geonode` json.
* **`youtube_auth_service.dart:1` (183L)** — `Hive youtube_auth` raw `Set-Cookie` dict, `SAPISIDHASH sha1(timestamp sapisid origin)` `getAuthHeaders:22`, `saveCookies:56`, `fetchUserProfile` `account_menu` parse.
* **`youtube_music_sync_service.dart:1` (724L)** — `WEB_REMIX 1.20240101` browse `FEmusic_*`, `_authenticatedPost`→`_publicPost` fallback, `reportSongPlayed` `videostatsPlaybackUrl` `cpn` 16-char, `trendingSongs`/`ytMusicPlaylists` ValueNotifiers.
* **`ytdlp_client_sync_service.dart:1` (387L)** — Fetches `yt_dlp/.../_base.py` raw, `parseVisionOsFromYtdlp` `indexOf("    'visionos': {")`, `VisionOsClientConfig` `VISIONOS 1.02` sole client.
* **`playlist_sharing.dart:1` (77L)** — Compact base64-url encode `ytid` list + `Future.wait(videos.get)` expand.

## Call graph

* `ProxyManager` ← `proxy_fetch_service`, `playlists_manager.getPlaylists` fallback, `playlist_sharing.expand`, `data_manager` indirectly via `ytClient` global `proxy_manager.dart:659` (every YT call when `useProxy`). → `YoutubeHttpClient(IOClient)`, `http`.
* `ProxyFetchService` → `ProxyManager.onCandidate` + `isBlocked`.
* `YouTubeAuthService` → `Hive`, `http.post` `account_menu`, called by `youtube_music_sync` + `ytdlp`? + `main.dart restoreSession`.
* `YouTubeMusicSyncService` → `YouTubeAuthService`, `http.post` direct, `Hive user`, called by `playlists_manager` + UI `fullSync`.
* `YtdlpClientSyncService` → `http.get` raw GitHub, called by `proxy_manager youtubeStreamClients()` + `main.dart ensureLoaded`.
* `PlaylistSharingService` → `ProxyManager` `getYoutubeExplodeClient` vs `getClientSync`.

## Comments removed

```
/// Default non-proxy YoutubeExplode instance (long-lived) — proxy_manager.dart:64
/// Currently active shared YoutubeExplode - either [_defaultYt] or a proxy-backed client. — 67
/// Initialize a shared YoutubeExplode client that uses a working proxy. — 216
/// Periodically clean up old proxies to prevent memory bloat — 343
// Skip the entry that backs _sharedYt to avoid closing its IOClient. — 435
// Let timed-out validation requests unwind before closing the client. — 514
/// Performs an HTTP GET request that respects current proxy settings. — 578
/// Returns a dedicated short-lived [YoutubeExplode] routed through a proxy. — 617
```

## Verification vs auditfinal

* **FIXED** Validation pool poison: now `_youtubeFromDedicatedProxy:331` creates dedicated `HttpClient`+`IOClient` not pooled; `_validateProxy:304` uses it and closes safely `322`. Dedicated client path `getYoutubeExplodeClient:633` likewise.
* **FIXED** shared `findProxy` race via generation guard `92-99` double call intentional but guarded by `Completer:221`.
* **NOT FIXED** `badCertificateCallback=>true` `338/429` still MITM for all proxied googlevideo+InnerTube.
* **NOT FIXED** `UIFileSharingEnabled` + plaintext `youtube_auth` cookies (see `05_persistence.md`, `10_ios_build.md`).
* **NOT FIXED** `ytdlp` single `VISIONOS` pin `visionos` parse brittle `309` `"'visionos': {"` 4-space single-quote; fallback `INNERTUBE_HOST` always `www.youtube.com`.
* **NOT FIXED** `playlist_sharing:31` unbounded `Future.wait` N=100 conc `videos.get` (needs semaphore).
* **PARTIALLY FIXED** `_maybeCleanupProxies` `344` prune still oldest not LRU via `keys.firstWhere`.

## DMCA note

* `getSongManifest` proxy rotation to dodge `RequestLimitExceeded` `youtube_http_client:47` + `ytdlp` auto-sync are willful evasion `1201(a)` — see `auditfinal.md:8`.
