import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:musified/constants/version.dart';
import 'package:musified/screens/youtube_auth_webview.dart';
import 'package:musified/services/common_services.dart';
import 'package:musified/services/data_manager.dart';
import 'package:musified/services/settings_manager.dart';
import 'package:musified/services/youtube_auth_service.dart';
import 'package:musified/services/youtube_music_sync_service.dart';
import 'package:musified/theme/musified_style.dart';
import 'package:musified/utilities/flutter_toast.dart';
import 'package:musified/widgets/mini_player_bottom_space.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final navBarColor = isDark ? const Color(0xB3121214) : const Color(0xB3FFFFFF);

    return CupertinoPageScaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text(
              'Settings',
              style: TextStyle(
                fontFamily: MusifiedStyle.displayFont,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            backgroundColor: navBarColor,
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0x26FFFFFF) : const Color(0x1F000000),
                width: 0.5,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildYouTubeAccountSection(context, isDark),
                _buildAudioSettingsSection(context, isDark),
                _buildStorageSection(context, isDark),
                _buildAboutSection(context, isDark),
                const MiniPlayerBottomSpace(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYouTubeAccountSection(BuildContext context, bool isDark) {
    return ValueListenableBuilder<bool>(
      valueListenable: YouTubeAuthService().isSignedIn,
      builder: (context, isSignedIn, _) {
        return CupertinoListSection.insetGrouped(
          header: const Text('YOUTUBE MUSIC ACCOUNT'),
          children: [
            if (!isSignedIn)
              CupertinoListTile(
                leading: const Icon(CupertinoIcons.play_circle_fill, color: Color(0xFFFF0033)),
                title: const Text('Sign in to YouTube Music'),
                subtitle: const Text('Sync liked songs, playlists, and mixes'),
                trailing: const CupertinoListTileChevron(),
                onTap: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (context) => const YouTubeAuthWebView()),
                  );
                },
              )
            else ...[
              CupertinoListTile(
                leading: const Icon(CupertinoIcons.person_crop_circle_fill, color: CupertinoColors.activeBlue),
                title: Text(YouTubeAuthService().userName.value ?? 'YouTube User'),
                subtitle: Text(YouTubeAuthService().userEmail.value ?? 'Connected'),
                trailing: CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Text('Sign Out', style: TextStyle(color: CupertinoColors.destructiveRed, fontSize: 14)),
                  onPressed: () {
                    YouTubeAuthService().signOut();
                    showToast(context, 'Signed out');
                  },
                ),
              ),
              CupertinoListTile(
                leading: const Icon(CupertinoIcons.refresh_circled_solid, color: CupertinoColors.systemGreen),
                title: const Text('Sync with YouTube'),
                trailing: const CupertinoListTileChevron(),
                onTap: () {
                  unawaited(YouTubeMusicSyncService().fullSync());
                  showToast(context, 'Syncing libraries...');
                },
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildAudioSettingsSection(BuildContext context, bool isDark) {
    return CupertinoListSection.insetGrouped(
      header: const Text('PLAYBACK & QUALITY'),
      children: [
        ValueListenableBuilder<String>(
          valueListenable: preferredSource,
          builder: (context, source, _) {
            final isJio = source == 'saavn' || source == 'jiosaavn';
            return CupertinoListTile(
              leading: const Icon(CupertinoIcons.music_note_2, color: CupertinoColors.systemGreen),
              title: const Text('Default Audio Provider'),
              trailing: Text(
                isJio ? 'JioSaavn 320k' : 'YouTube Music',
                style: const TextStyle(color: CupertinoColors.systemGrey),
              ),
              onTap: () {
                final next = isJio ? 'youtube' : 'jiosaavn';
                preferredSource.value = next;
                addOrUpdateData('settings', 'preferredSource', next);
                showToast(context, 'Default provider set to ${next == 'youtube' ? 'YouTube Music' : 'JioSaavn 320k'}');
              },
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: jiosaavnEnabled,
          builder: (context, enabled, _) {
            return CupertinoListTile(
              leading: const Icon(CupertinoIcons.waveform, color: CupertinoColors.activeBlue),
              title: const Text('Enable JioSaavn 320k Lossless'),
              trailing: CupertinoSwitch(
                value: enabled,
                activeTrackColor: const Color(0xFFFF2D55),
                onChanged: (val) {
                  jiosaavnEnabled.value = val;
                  addOrUpdateData('settings', 'jiosaavnEnabled', val);
                },
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: offlineMode,
          builder: (context, offline, _) {
            return CupertinoListTile(
              leading: const Icon(CupertinoIcons.airplane, color: CupertinoColors.systemOrange),
              title: const Text('Offline Mode Only'),
              trailing: CupertinoSwitch(
                value: offline,
                activeTrackColor: const Color(0xFFFF2D55),
                onChanged: (val) {
                  offlineMode.value = val;
                  addOrUpdateData('settings', 'offlineMode', val);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStorageSection(BuildContext context, bool isDark) {
    return CupertinoListSection.insetGrouped(
      header: const Text('STORAGE & CACHE'),
      children: [
        CupertinoListTile(
          leading: const Icon(CupertinoIcons.trash, color: CupertinoColors.systemRed),
          title: const Text('Clear Audio Cache'),
          trailing: const CupertinoListTileChevron(),
          onTap: () async {
            await clearAllCache();
            if (context.mounted) showToast(context, 'Audio cache cleared');
          },
        ),
        CupertinoListTile(
          leading: const Icon(CupertinoIcons.clock_fill, color: CupertinoColors.systemPurple),
          title: const Text('Clear Search & Recents'),
          trailing: const CupertinoListTileChevron(),
          onTap: () async {
            await deleteData('user', 'searchHistory');
            await deleteData('user', 'recentlyPlayed');
            userRecentlyPlayed.value = [];
            if (context.mounted) showToast(context, 'History cleared');
          },
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context, bool isDark) {
    return CupertinoListSection.insetGrouped(
      header: const Text('ABOUT'),
      children: [
        CupertinoListTile(
          leading: const Icon(CupertinoIcons.info_circle_fill, color: CupertinoColors.activeBlue),
          title: const Text('Version'),
          trailing: Text(
            appVersion,
            style: const TextStyle(color: CupertinoColors.systemGrey),
          ),
        ),
        CupertinoListTile(
          leading: const Icon(CupertinoIcons.doc_text_fill, color: CupertinoColors.systemGrey),
          title: const Text('Diagnostic Logs'),
          trailing: const CupertinoListTileChevron(),
          onTap: () {
            context.push('/settings/logs');
          },
        ),
      ],
    );
  }
}
