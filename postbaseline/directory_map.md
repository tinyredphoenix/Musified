# Postbaseline — Directory Map (fresh, 2026-09-02)

*Root:* `/Users/naman/Documents/RANDOM/ytmusic/Musified` — *Repo:* Flutter `musified` (`pubspec.yaml:1` `2.3.0+35` `sdk >=3.12.0`) — *Filtered files:* 466 (excludes `.git/.dart_tool/build/pubspec.lock`)

```
Musified/
├── .gitignore                          # ignore dart_tool/build/iml
├── .metadata                           # flutter project metadata
├── analysis_options.yaml               # 125L lint (flutter_lints, 90+ rules)
├── l10n.yaml                           # gen-l10n config (arb-dir lib/localization)
├── pubspec.yaml                        # 57L deps: audio_service/just_audio/hive/go_router/webview_flutter + vendored explode
├── apps.json                           # AltStore source (24L)
├── README.md                           # v5.0 features (78L)
├── CODE_OF_CONDUCT.md / CONTRIBUTING.md / LICENSE / crowdin.yml / dart_test.yaml
├── auditv1.md / auditv2-youtube-ui.md / auditfinal.md   # prior audits — ignored here
├── postbaseline/                       # <-- this audit (fresh)
│   ├── audit.md                        # postbaseline audit (standalone)
│   ├── directory_map.md                # this file
│   ├── linkage_map.md                  # imports → callers per module
│   └── file_roles.md                   # every file: role/description (466 entries)
├── readmes/                            # prior per-module READMEs (12 files, ignored here)
├── assets/
│   ├── fonts/paytone/PaytoneOne-Regular.ttf
│   ├── icons/musify_icon.png
│   └── licenses/paytone.txt
├── fastlane/metadata/android/en-US/{title,short_description,full_description}.txt + changelogs/180.txt + images/{icon.png,phoneScreenshots/01-04.jpg}
├── ios/
│   ├── Podfile, Flutter/{AppFrameworkInfo.plist,Debug/Release.xcconfig,Generated.xcconfig,flutter_export_environment.sh,ephemeral/*}
│   ├── Runner/{AppDelegate.swift:18, SceneDelegate.swift:6, Info.plist:83, GeneratedPluginRegistrant.{h,m}, Assets.xcassets/AppIcon 14 + LaunchImage 5, Base.lproj/{Main,LaunchScreen}.storyboard, Runner-Bridging-Header.h}
│   ├── Runner.xcodeproj/{project.pbxproj, project.xcworkspace/*, xcshareddata/xcschemes/Runner.xcscheme}
│   ├── Runner.xcworkspace/*, RunnerTests/RunnerTests.swift
├── lib/                                # 166 files (core app)
│   ├── main.dart:467                   # entry, 5-phase init, error widget, deeplink
│   ├── constants/4                     # app_constants, artist_constants, clients, version
│   ├── database/2                       # albums.db.dart 876L, playlists.db.dart 465L (seed playlists)
│   ├── extensions/l10n.dart:1
│   ├── localization/44                 # 21 .arb + 22 generated dart + untranslated.json
│   ├── models/2                        # full_player_state, position_data (+ proxy_model via services)
│   ├── screens/12                      # home, search, library, playlist, playlist_folder, artist, now_playing, user_songs, logs, bottom_navigation, settings, youtube_auth_webview
│   ├── services/18                   # apple-level services (see lib/services/audio/ below)
│   │   ├── artist_service.dart:983, audio_service.dart:1, common_services.dart:1545, data_manager.dart:274, io_service.dart:40, jiosaavn_service.dart:147, logger_service.dart:74, lyrics_manager.dart:231, playlist_download_service.dart:602, playlist_sharing.dart:93, playlists_manager.dart:1609, router_service.dart:377, settings_manager.dart:216, source_resolver.dart:186, youtube_auth_service.dart:191, youtube_client.dart:4, youtube_music_sync_service.dart:774, ytdlp_client_sync_service.dart:395
│   │   └── audio/12                  # audio.dart barrel + audio_browse_catalog, audio_completion_coordinator, audio_handler_hub, audio_playback_coordinator, audio_playback_install, audio_preload_cache, audio_preload_service, audio_queue_controller, audio_queue_state, musified_audio_handler (~2698L), playback_source
│   ├── theme/3                         # app_themes 129L, app_colors 14L, musified_style 135L
│   ├── utilities/19                    # app_utils, artwork_provider, async_loader, flutter_bottom_sheet, flutter_toast, formatter, language_utils, map_utils, mediaitem, musified_picker_sheet, offline_playlist_dialogs, playlist_dialogs, playlist_image_picker, playlist_utils, queue_entry_utils, song_filtering, song_info_dialog, sort_utils, track_matcher
│   └── widgets/46                      # 26 root + 7 now_playing + 7 lyrics + 7 playlist_page
│       ├── widgets/*.dart (26)        # artist_bar/shelf, confirmation_dialog, custom_bar, download_picker_sheet, edit_playlist_dialog, flip_card, marquee, mini_player, mini_player_bottom_space, no_artwork_cube, offline_search_placeholder, playback_icon_button, playlist_artwork/bar/cube, position_slider, queue_list_view, rename_song_dialog, section_header/title, song_actions_sheet, song_artwork, song_tile, sort_chips, spinner
│       ├── widgets/now_playing/7       # bottom_actions_row, full_page_lyrics_modal, marquee_text_widget, now_playing_artwork, now_playing_controls, source_picker_sheet, synced_lyrics_view
│       ├── widgets/now_playing/lyrics/7 # compact_lyrics_panel, lrc_parser, lyrics_backdrop, lyrics_empty_state, lyrics_stage, lyrics_theme, plain_lyrics_reader
│       └── widgets/playlist_page/7     # add_to_playlist_button, download_button, empty_playlist_state, like_button, playlist_action_buttons, playlist_header, shuffle_play_button
├── packages/
│   ├── youtube_explode_dart/ (~184 files)  # vendored scraper: lib/src/reverse_engineering/* (cipher/ejs/clients/pages/player/models/dash/hls/heuristics/visitor_data/youtube_http_client), channels/*, common/*, exceptions/*, search/*, videos/{streams,mixins,models,types,closed_captions,comments}
│   └── youtube_music_explode_dart/ (3 files) # music_client, youtube_music_explode_base, barrel
├── test/12                             # app_boot, audio_browse_catalog, audio_queue_controller, play_from_queue_gate, queue_entry, song_should_resolve_youtube, widget, youtube_stream_duration/expiry/url, ytdlp_client_sync/live_sync
├── tool/probe_clients.dart:220        # InnerTube client viability probe
└── scripts/{checkdb.sh, checker.dart}  # Hive box checker helper
```

## Counts (filtered)

| Group | Files | Notes |
|---|---|---|
| `lib/` | 166 | 1 main + 4 const + 2 db + 1 ext + 44 l10n + 2 models + 12 screens + 30 services (18+12 audio) + 3 theme + 19 util + 46 widgets |
| `ios/` | ~38 | Runner + Flutter + Podfile + xcodeproj (+ ephemeral generated) |
| `packages/` | ~190 | 184 youtube_explode_dart + 3 music + root yaml/lock |
| `fastlane/` | 8 | metadata + changelogs + images |
| `test/` | 12 | |
| Root/filtered total | 466 | excludes `.git/.dart_tool/build` |

## Ignored
`.git/` (objects + logs), `.dart_tool/` (hooks, package_config), `build/`, `build_output/`, `.idea/`, `.DS_Store`.
