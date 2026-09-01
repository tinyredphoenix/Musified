# 10 — iOS + Build (`ios/Runner/*`, `pubspec.yaml`, `analysis_options.yaml`)

## iOS

* **`AppDelegate.swift:1` (36L)** — `AVAudioSession` `.playback` `.allowAirPlay/.allowBluetooth/.allowBluetoothA2DP` activate on `didFinishLaunching` + `didBecomeActive`. `FlutterImplicitEngineDelegate`.
* **`SceneDelegate.swift:1` (6L)** — Empty `FlutterSceneDelegate` subclass.
* **`Info.plist:1` (83L)** — `CADisableMinimumFrameDurationOnPhone true` 120Hz, `UIBackgroundModes audio` only, `UIFileSharingEnabled true` + `LSSupportsOpeningDocumentsInPlace true` → Documents exposed, `NSAppTransportSecurity NSAllowsArbitraryLoads false` (good), `UIScene` config `Main.storyboard`, `UISupportedInterfaceOrientations` portrait+landscape (iPhone + iPad).

## Call graph

* `AppDelegate` ↔ `AudioSession` (Dart `AudioSessionConfiguration.music()` in `musified_audio_handler.dart:667`) — double config risk.
* `Info.plist` → iOS background, file sharing, ATS, scenes.

## Build

* **`pubspec.yaml:1` (59L)** `musified 1.8.0+30` `sdk >=3.12.0` `flutter >=3.22.0`, deps `app_links audio_service just_audio audio_session cached_network_image flutter_cache_manager go_router hive_flutter http intl share_plus url_launcher webview_flutter` + local `youtube_explode_dart`/`youtube_music_explode_dart`.
* **`analysis_options.yaml:1` (125L)** 90+ lints (`always_declare_return_types`, `cancel_subscriptions`, `avoid_print`, `use_key...`) excludes `packages/**` `scripts/**` `test/**` `build/**`.
* **`fastlane/` `build-ios.yml`** no `analyze/test`, caches Pods not Specs.

## Comments removed

* None verbatim in `Info.plist`/`AppDelegate.swift` beyond license headers.

## Verification vs auditfinal

* **NOT FIXED** `UIFileSharingEnabled true` `Info.plist:33` still exposes `Hive` `user/youtube_auth` plaintext + `tracks` via Files; should be `false` + `ApplicationSupport` for sensitive boxes (`userNoBackup` already non-backed but audio still `Documents`).
* **NOT FIXED** `badCertificateCallback` MITM still (see `04_network_proxy_youtube.md`).
* **NOT FIXED** `AVAudioSession` double config Swift+Dart still deactivates `MPRemoteCommandCenter`; no `interruptionNotification`/`routeChangeNotification` in Swift (fixed only in Dart layer `670/698`).
* **PARTIALLY FIXED** `ATS false` correct, but `pubspec.yaml` missing `flutter_secure_storage` for auth tokens (still plaintext Hive).
* **NOT FIXED** `analysis_options.yaml` excludes not covering `lib/generated` l10n noise; `avoid_print` still Swift `print` only.
* **NOT FIXED** `120Hz` + `BackdropFilter blur 25+20` battery burn.

## Notes

* `CADisableMinimumFrameDurationOnPhone true` `Info.plist:5` increases power draw with `Blur 20-25` every frame; no `RepaintBoundary` around `ClipRRect`.
* `BackgroundModes audio` only → `playlist_download_service` 3-worker `makeSongOffline` 20s http without `BGTaskScheduler` suspended 30s, truncates offline file but Hive marks offline.
