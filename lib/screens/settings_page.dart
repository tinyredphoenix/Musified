import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
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
    final scaffoldBg = isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);

    return CupertinoPageScaffold(
      backgroundColor: scaffoldBg,
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
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
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
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: MusifiedStyle.uiFont,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.systemGrey,
          letterSpacing: -0.1,
        ),
      ),
    );
  }

  Widget _buildIconTile({
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(7.5),
      ),
      child: Icon(icon, color: CupertinoColors.white, size: 18),
    );
  }

  Widget _buildYouTubeAccountSection(BuildContext context, bool isDark) {
    return ValueListenableBuilder<bool>(
      valueListenable: YouTubeAuthService().isSignedIn,
      builder: (context, isSignedIn, _) {
        return CupertinoListSection.insetGrouped(
          header: _buildSectionHeader('YOUTUBE MUSIC ACCOUNT'),
          backgroundColor: const Color(0x00000000),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          children: [
            if (!isSignedIn)
              CupertinoListTile(
                leading: _buildIconTile(
                  icon: CupertinoIcons.play_circle_fill,
                  color: const Color(0xFFFF0033),
                ),
                title: const Text(
                  'Sign In to YouTube Music',
                  style: TextStyle(
                    fontFamily: MusifiedStyle.uiFont,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: const Text(
                  'Sync liked songs, mixes & your custom playlists',
                  style: TextStyle(
                    fontFamily: MusifiedStyle.uiFont,
                    fontSize: 13,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
                trailing: const CupertinoListTileChevron(),
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (context) => const YouTubeAuthWebView()),
                  );
                },
              )
            else ...[
              CupertinoListTile(
                leading: _buildIconTile(
                  icon: CupertinoIcons.person_crop_circle_fill,
                  color: CupertinoColors.activeBlue,
                ),
                title: Text(
                  YouTubeAuthService().userName.value ?? 'YouTube User',
                  style: const TextStyle(
                    fontFamily: MusifiedStyle.uiFont,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  YouTubeAuthService().userEmail.value ?? 'Connected & Synced',
                  style: const TextStyle(
                    fontFamily: MusifiedStyle.uiFont,
                    fontSize: 13,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
                trailing: CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(
                      fontFamily: MusifiedStyle.uiFont,
                      color: CupertinoColors.destructiveRed,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    YouTubeAuthService().signOut();
                    showToast(context, 'Signed out of YouTube Music');
                  },
                ),
              ),
              CupertinoListTile(
                leading: _buildIconTile(
                  icon: CupertinoIcons.arrow_2_circlepath,
                  color: CupertinoColors.systemGreen,
                ),
                title: const Text(
                  'Sync Library Now',
                  style: TextStyle(
                    fontFamily: MusifiedStyle.uiFont,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                subtitle: const Text(
                  'Fetches latest likes and mixes from YouTube',
                  style: TextStyle(
                    fontFamily: MusifiedStyle.uiFont,
                    fontSize: 13,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
                trailing: const CupertinoListTileChevron(),
                onTap: () {
                  HapticFeedback.selectionClick();
                  unawaited(YouTubeMusicSyncService().fullSync());
                  showToast(context, 'Syncing YouTube library...');
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
      header: _buildSectionHeader('PLAYBACK & QUALITY'),
      backgroundColor: const Color(0x00000000),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      children: [
        ValueListenableBuilder<String>(
          valueListenable: preferredSource,
          builder: (context, source, _) {
            final isJio = source == 'saavn' || source == 'jiosaavn';
            return CupertinoListTile(
              leading: _buildIconTile(
                icon: CupertinoIcons.music_note_2,
                color: const Color(0xFFFF2D55),
              ),
              title: const Text(
                'Default Audio Provider',
                style: TextStyle(
                  fontFamily: MusifiedStyle.uiFont,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              subtitle: const Text(
                'Priority provider for track streaming',
                style: TextStyle(
                  fontFamily: MusifiedStyle.uiFont,
                  fontSize: 13,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isJio ? 'JioSaavn 320k' : 'YouTube Music',
                    style: const TextStyle(
                      fontFamily: MusifiedStyle.uiFont,
                      color: CupertinoColors.systemGrey,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const CupertinoListTileChevron(),
                ],
              ),
              onTap: () {
                HapticFeedback.selectionClick();
                final next = isJio ? 'youtube' : 'jiosaavn';
                preferredSource.value = next;
                addOrUpdateData('settings', 'preferredSource', next);
                showToast(
                  context,
                  'Default provider: ${next == 'youtube' ? 'YouTube Music' : 'JioSaavn 320k Lossless'}',
                );
              },
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: jiosaavnEnabled,
          builder: (context, enabled, _) {
            return CupertinoListTile(
              leading: _buildIconTile(
                icon: CupertinoIcons.waveform,
                color: CupertinoColors.systemIndigo,
              ),
              title: const Text(
                'JioSaavn 320k Lossless',
                style: TextStyle(
                  fontFamily: MusifiedStyle.uiFont,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              subtitle: const Text(
                'Studio master 320 kbps high-definition audio',
                style: TextStyle(
                  fontFamily: MusifiedStyle.uiFont,
                  fontSize: 13,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              trailing: CupertinoSwitch(
                value: enabled,
                activeTrackColor: const Color(0xFFFF2D55),
                onChanged: (val) {
                  HapticFeedback.selectionClick();
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
              leading: _buildIconTile(
                icon: CupertinoIcons.airplane,
                color: CupertinoColors.systemOrange,
              ),
              title: const Text(
                'Offline Mode Only',
                style: TextStyle(
                  fontFamily: MusifiedStyle.uiFont,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              subtitle: const Text(
                'Strictly play downloaded songs without network calls',
                style: TextStyle(
                  fontFamily: MusifiedStyle.uiFont,
                  fontSize: 13,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              trailing: CupertinoSwitch(
                value: offline,
                activeTrackColor: const Color(0xFFFF2D55),
                onChanged: (val) {
                  HapticFeedback.selectionClick();
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
      header: _buildSectionHeader('STORAGE & CACHE'),
      backgroundColor: const Color(0x00000000),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      children: [
        CupertinoListTile(
          leading: _buildIconTile(
            icon: CupertinoIcons.trash_fill,
            color: CupertinoColors.systemRed,
          ),
          title: const Text(
            'Clear Audio & Manifest Cache',
            style: TextStyle(
              fontFamily: MusifiedStyle.uiFont,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          subtitle: const Text(
            'Frees temporary stream files and resolved tokens',
            style: TextStyle(
              fontFamily: MusifiedStyle.uiFont,
              fontSize: 13,
              color: CupertinoColors.systemGrey,
            ),
          ),
          trailing: const CupertinoListTileChevron(),
          onTap: () async {
            HapticFeedback.mediumImpact();
            await clearAllCache();
            if (context.mounted) showToast(context, 'Audio cache cleared');
          },
        ),
        CupertinoListTile(
          leading: _buildIconTile(
            icon: CupertinoIcons.clock_fill,
            color: CupertinoColors.systemPurple,
          ),
          title: const Text(
            'Clear Search History & Recents',
            style: TextStyle(
              fontFamily: MusifiedStyle.uiFont,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          subtitle: const Text(
            'Resets search queries and recently played songs',
            style: TextStyle(
              fontFamily: MusifiedStyle.uiFont,
              fontSize: 13,
              color: CupertinoColors.systemGrey,
            ),
          ),
          trailing: const CupertinoListTileChevron(),
          onTap: () async {
            HapticFeedback.mediumImpact();
            await deleteData('user', 'searchHistory');
            await deleteData('user', 'recentlyPlayed');
            userRecentlyPlayed.value = [];
            if (context.mounted) showToast(context, 'Search & recent history cleared');
          },
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context, bool isDark) {
    return CupertinoListSection.insetGrouped(
      header: _buildSectionHeader('ABOUT MUSIFIED'),
      backgroundColor: const Color(0x00000000),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      children: [
        CupertinoListTile(
          leading: _buildIconTile(
            icon: CupertinoIcons.info_circle_fill,
            color: CupertinoColors.activeBlue,
          ),
          title: const Text(
            'Version',
            style: TextStyle(
              fontFamily: MusifiedStyle.uiFont,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          trailing: Text(
            appVersion,
            style: const TextStyle(
              fontFamily: MusifiedStyle.uiFont,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.systemGrey,
              fontSize: 15,
            ),
          ),
        ),
        CupertinoListTile(
          leading: _buildIconTile(
            icon: CupertinoIcons.doc_plaintext,
            color: const Color(0xFF64D2FF),
          ),
          title: const Text(
            'Diagnostic Logs',
            style: TextStyle(
              fontFamily: MusifiedStyle.uiFont,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          subtitle: const Text(
            'Inspect network, stream & playback logs',
            style: TextStyle(
              fontFamily: MusifiedStyle.uiFont,
              fontSize: 13,
              color: CupertinoColors.systemGrey,
            ),
          ),
          trailing: const CupertinoListTileChevron(),
          onTap: () {
            HapticFeedback.selectionClick();
            context.push('/settings/logs');
          },
        ),
      ],
    );
  }
}
