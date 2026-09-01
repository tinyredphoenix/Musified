import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:musified/main.dart';
import 'package:musified/constants/version.dart';
import 'package:musified/screens/youtube_auth_webview.dart';
import 'package:musified/services/common_services.dart';
import 'package:musified/services/data_manager.dart';
import 'package:musified/services/settings_manager.dart';
import 'package:musified/services/youtube_auth_service.dart';
import 'package:musified/services/youtube_music_sync_service.dart';
import 'package:musified/theme/app_themes.dart';
import 'package:musified/theme/musified_style.dart';
import 'package:musified/utilities/flutter_toast.dart';
import 'package:musified/widgets/mini_player_bottom_space.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: usePureBlackColor,
      builder: (context, _, __) {
        final isDark = isAppDarkMode(context);
        final navBarColor =
            isDark ? const Color(0xB3121214) : const Color(0xB3FFFFFF);
        final scaffoldBg = musifiedCanvas(isDark);

        return CupertinoPageScaffold(
          backgroundColor: scaffoldBg,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              CupertinoSliverNavigationBar(
                largeTitle: const Text(
                  'Settings',
                  style: TextStyle(
                    fontFamily: MusifiedStyle.displayFont,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                backgroundColor: navBarColor,
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? const Color(0x26FFFFFF)
                        : const Color(0x1F000000),
                    width: 0.5,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildThemeSelector(context, isDark),
                      const SizedBox(height: 20),
                      _buildYouTubeAccountCard(context, isDark),
                      const SizedBox(height: 20),
                      _buildAudioEngineSection(context, isDark),
                      const SizedBox(height: 20),
                      _buildStorageSection(context, isDark),
                      const SizedBox(height: 20),
                      _buildAboutSection(context, isDark),
                      const SizedBox(height: 12),
                      const MiniPlayerBottomSpace(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // THEME SELECTOR CARD
  // ---------------------------------------------------------------------------
  Widget _buildThemeSelector(BuildContext context, bool isDark) {
    final cardBg = musifiedSheetCard(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('APPEARANCE'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0x1FFFFFFF) : const Color(0x0A000000),
              width: 0.8,
            ),
          ),
          child: Column(
            children: [
              ValueListenableBuilder<int>(
                valueListenable: themeModeSetting,
                builder: (context, currentThemeIndex, _) {
                  return Row(
                    children: [
                      _buildThemeOption(
                        title: 'System',
                        icon: CupertinoIcons.device_phone_portrait,
                        isSelected: currentThemeIndex == 0,
                        onTap: () => _updateTheme(context, 0),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildThemeOption(
                        title: 'Light',
                        icon: CupertinoIcons.sun_max_fill,
                        isSelected: currentThemeIndex == 1,
                        onTap: () => _updateTheme(context, 1),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildThemeOption(
                        title: 'Dark',
                        icon: CupertinoIcons.moon_fill,
                        isSelected: currentThemeIndex == 2,
                        onTap: () => _updateTheme(context, 2),
                        isDark: isDark,
                      ),
                    ],
                  );
                },
              ),
              if (isDark) ...[
                const SizedBox(height: 12),
                Container(
                  height: 0.5,
                  color: const Color(0x26FFFFFF),
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<bool>(
                  valueListenable: usePureBlackColor,
                  builder: (context, pureBlack, _) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              CupertinoIcons.circle_fill,
                              color: CupertinoColors.systemGrey,
                              size: 16,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Pure OLED Black',
                              style: TextStyle(
                                fontFamily: MusifiedStyle.uiFont,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        CupertinoSwitch(
                          value: pureBlack,
                          activeTrackColor: const Color(0xFFFF2D55),
                          onChanged: (val) {
                            HapticFeedback.selectionClick();
                            usePureBlackColor.value = val;
                            unawaited(addOrUpdateData('settings', 'usePureBlackColor', val));
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeOption({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    const primaryColor = Color(0xFFFF2D55);
    final buttonBg = isSelected
        ? primaryColor
        : musifiedSecondarySurface(isDark);
    final textColor = isSelected
        ? CupertinoColors.white
        : (isDark ? CupertinoColors.white : CupertinoColors.black);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: buttonBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: textColor, size: 20),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontFamily: MusifiedStyle.uiFont,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateTheme(BuildContext context, int index) {
    HapticFeedback.selectionClick();
    themeModeSetting.value = index;
    syncThemeFromSettings();
    unawaited(addOrUpdateData('settings', 'themeIndex', index));
  }

  // ---------------------------------------------------------------------------
  // YOUTUBE MUSIC ACCOUNT SECTION
  // ---------------------------------------------------------------------------
  Widget _buildYouTubeAccountCard(BuildContext context, bool isDark) {
    final cardBg = musifiedSheetCard(isDark);

    return ValueListenableBuilder<bool>(
      valueListenable: YouTubeAuthService().isSignedIn,
      builder: (context, isSignedIn, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('YOUTUBE MUSIC SYNC'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0x1FFFFFFF) : const Color(0x0A000000),
                  width: 0.8,
                ),
              ),
              child: isSignedIn
                  ? _buildSignedInContent(context, isDark)
                  : _buildSignedOutContent(context, isDark),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSignedOutContent(BuildContext context, bool isDark) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFF0033),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            CupertinoIcons.play_rectangle_fill,
            color: CupertinoColors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Connect YouTube Music',
                style: TextStyle(
                  fontFamily: MusifiedStyle.displayFont,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Sync your liked tracks, playlists & mixes',
                style: TextStyle(
                  fontFamily: MusifiedStyle.uiFont,
                  fontSize: 13,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: const Color(0xFFFF0033),
          borderRadius: BorderRadius.circular(20),
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.push(
              context,
              CupertinoPageRoute(builder: (context) => const YouTubeAuthWebView()),
            );
          },
          child: const Text(
            'Sign In',
            style: TextStyle(
              fontFamily: MusifiedStyle.uiFont,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: CupertinoColors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignedInContent(BuildContext context, bool isDark) {
    final name = YouTubeAuthService().userName.value ?? 'YouTube User';
    final email = YouTubeAuthService().userEmail.value ?? 'Connected';

    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: CupertinoColors.activeBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'Y',
                  style: const TextStyle(
                    fontFamily: MusifiedStyle.displayFont,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontFamily: MusifiedStyle.displayFont,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: const TextStyle(
                      fontFamily: MusifiedStyle.uiFont,
                      fontSize: 13,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Text(
                'Sign Out',
                style: TextStyle(
                  fontFamily: MusifiedStyle.uiFont,
                  color: CupertinoColors.destructiveRed,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                YouTubeAuthService().signOut();
                showToast(context, 'Signed out of YouTube Music');
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          height: 0.5,
          color: isDark ? const Color(0x26FFFFFF) : const Color(0x1F000000),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            unawaited(YouTubeMusicSyncService().fullSync());
            showToast(context, 'Syncing YouTube Music library...');
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    CupertinoIcons.arrow_2_circlepath,
                    color: CupertinoColors.systemGreen,
                    size: 18,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Sync Library Now',
                    style: TextStyle(
                      fontFamily: MusifiedStyle.uiFont,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.systemGreen,
                    ),
                  ),
                ],
              ),
              Icon(
                CupertinoIcons.chevron_right,
                color: CupertinoColors.systemGrey3,
                size: 16,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // AUDIO & PLAYBACK ENGINE
  // ---------------------------------------------------------------------------
  Widget _buildAudioEngineSection(BuildContext context, bool isDark) {
    final cardBg = musifiedSheetCard(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('PLAYBACK & AUDIO QUALITY'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0x1FFFFFFF) : const Color(0x0A000000),
              width: 0.8,
            ),
          ),
          child: Column(
            children: [
              ValueListenableBuilder<String>(
                valueListenable: preferredSource,
                builder: (context, source, _) {
                  final isJio = source == 'saavn' || source == 'jiosaavn';
                  return _buildSettingRow(
                    icon: CupertinoIcons.music_note_2,
                    iconBg: const Color(0xFFFF2D55),
                    title: 'Default Audio Provider',
                    subtitle: 'Priority stream source for playback',
                    trailingText: isJio ? 'JioSaavn 320k' : 'YouTube Music',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      final next = isJio ? 'youtube' : 'jiosaavn';
                      preferredSource.value = next;
                      unawaited(addOrUpdateData('settings', 'preferredSource', next));
                      if (isAudioHandlerInitialized) {
                        audioHandler.clearPinnedSources();
                      }
                      showToast(
                        context,
                        'Default provider: ${next == 'youtube' ? 'YouTube Music' : 'JioSaavn 320k Lossless'}',
                      );
                    },
                    isDark: isDark,
                  );
                },
              ),
              _buildDivider(isDark),
              ValueListenableBuilder<bool>(
                valueListenable: jiosaavnEnabled,
                builder: (context, enabled, _) {
                  return _buildSwitchRow(
                    icon: CupertinoIcons.waveform,
                    iconBg: CupertinoColors.systemIndigo,
                    title: 'JioSaavn 320k Lossless',
                    subtitle: 'Studio master high-definition AAC streams',
                    value: enabled,
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      jiosaavnEnabled.value = val;
                      unawaited(addOrUpdateData('settings', 'jiosaavnEnabled', val));
                    },
                    isDark: isDark,
                  );
                },
              ),
              _buildDivider(isDark),
              ValueListenableBuilder<bool>(
                valueListenable: playNextSongAutomatically,
                builder: (context, autoPlay, _) {
                  return _buildSwitchRow(
                    icon: CupertinoIcons.infinite,
                    iconBg: CupertinoColors.systemTeal,
                    title: 'Infinite Recommendations',
                    subtitle: 'Auto-play similar music when queue ends',
                    value: autoPlay,
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      playNextSongAutomatically.value = val;
                      unawaited(addOrUpdateData('settings', 'playNextSongAutomatically', val));
                    },
                    isDark: isDark,
                  );
                },
              ),
              _buildDivider(isDark),
              ValueListenableBuilder<bool>(
                valueListenable: offlineMode,
                builder: (context, offline, _) {
                  return _buildSwitchRow(
                    icon: CupertinoIcons.airplane,
                    iconBg: CupertinoColors.systemOrange,
                    title: 'Offline Mode Only',
                    subtitle: 'Play exclusively from downloaded local tracks',
                    value: offline,
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      offlineMode.value = val;
                      unawaited(addOrUpdateData('settings', 'offlineMode', val));
                    },
                    isDark: isDark,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STORAGE & CACHE
  // ---------------------------------------------------------------------------
  Widget _buildStorageSection(BuildContext context, bool isDark) {
    final cardBg = musifiedSheetCard(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('STORAGE & CACHE'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0x1FFFFFFF) : const Color(0x0A000000),
              width: 0.8,
            ),
          ),
          child: Column(
            children: [
              _buildSettingRow(
                icon: CupertinoIcons.trash_fill,
                iconBg: CupertinoColors.systemRed,
                title: 'Clear Audio Cache',
                subtitle: 'Frees temporary streams & token manifests',
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  await clearAllCache();
                  if (context.mounted) showToast(context, 'Audio cache cleared');
                },
                isDark: isDark,
              ),
              _buildDivider(isDark),
              _buildSettingRow(
                icon: CupertinoIcons.clock_fill,
                iconBg: CupertinoColors.systemPurple,
                title: 'Clear History & Recents',
                subtitle: 'Resets search keywords and recently played',
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  await deleteData('user', 'searchHistory');
                  await deleteData('user', 'recentlyPlayed');
                  userRecentlyPlayed.value = [];
                  if (context.mounted) showToast(context, 'Search & recent history cleared');
                },
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ABOUT MUSIFIED
  // ---------------------------------------------------------------------------
  Widget _buildAboutSection(BuildContext context, bool isDark) {
    final cardBg = musifiedSheetCard(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('ABOUT MUSIFIED'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0x1FFFFFFF) : const Color(0x0A000000),
              width: 0.8,
            ),
          ),
          child: Column(
            children: [
              _buildSettingRow(
                icon: CupertinoIcons.info_circle_fill,
                iconBg: CupertinoColors.activeBlue,
                title: 'Version',
                subtitle: 'Musified Native iOS Edition',
                trailingText: 'v$appVersion',
                onTap: null,
                isDark: isDark,
              ),
              _buildDivider(isDark),
              _buildSettingRow(
                icon: CupertinoIcons.doc_plaintext,
                iconBg: const Color(0xFF64D2FF),
                title: 'Diagnostic Logs',
                subtitle: 'Inspect live network & audio pipeline logs',
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.push('/settings/logs');
                },
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // REUSABLE ROW BUILDERS
  // ---------------------------------------------------------------------------
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: MusifiedStyle.uiFont,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: CupertinoColors.systemGrey,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    String? trailingText,
    VoidCallback? onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: CupertinoColors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: MusifiedStyle.uiFont,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: MusifiedStyle.uiFont,
                      fontSize: 13,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
            ),
            if (trailingText != null) ...[
              Text(
                trailingText,
                style: const TextStyle(
                  fontFamily: MusifiedStyle.uiFont,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (onTap != null)
              const Icon(
                CupertinoIcons.chevron_right,
                color: CupertinoColors.systemGrey3,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: CupertinoColors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: MusifiedStyle.uiFont,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: MusifiedStyle.uiFont,
                    fontSize: 13,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: const Color(0xFFFF2D55),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.only(left: 68),
      color: isDark ? const Color(0x1FFFFFFF) : const Color(0x14000000),
    );
  }
}
