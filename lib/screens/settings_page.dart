/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Musify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Musify, including how to contribute,
 *     please visit: https://github.com/gokadzev/Musify
 */

import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/services/youtube_auth_service.dart';
import 'package:musify/services/youtube_music_sync_service.dart';
import 'package:musify/screens/youtube_auth_webview.dart';
import 'package:musify/constants/app_constants.dart';
import 'package:musify/constants/version.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/screens/search_page.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/listening_stats_service.dart';
import 'package:musify/services/playlist_download_service.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/theme/app_colors.dart';
import 'package:musify/theme/app_themes.dart';
import 'package:musify/utilities/flutter_bottom_sheet.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/language_utils.dart';
import 'package:musify/utilities/url_launcher.dart';
import 'package:musify/widgets/bottom_sheet_bar.dart';
import 'package:musify/widgets/confirmation_dialog.dart';
import 'package:musify/widgets/custom_bar.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';
import 'package:musify/widgets/section_header.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final activatedColor = Theme.of(context).colorScheme.secondaryContainer;
    final inactivatedColor = Theme.of(context).colorScheme.surfaceContainerHigh;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settings)),
      body: SingleChildScrollView(
        padding: commonSingleChildScrollViewPadding,
        child: Column(
          children: <Widget>[
            _buildYouTubeMusicSection(context),
            _buildPreferencesSection(
              context,
              primaryColor,
              activatedColor,
              inactivatedColor,
            ),
            if (!offlineMode.value) _buildAudioSourcesSection(context),
            if (!offlineMode.value) _buildOnlineFeaturesSection(context),
            _buildOthersSection(context),
            const SizedBox(height: 20),
            const MiniPlayerBottomSpace(),
          ],
        ),
      ),
    );
  }

  Widget _buildYouTubeMusicSection(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: YouTubeAuthService().isSignedIn,
      builder: (context, isSignedIn, _) {
        if (!isSignedIn) {
          return Column(
            children: [
              const SectionHeader(
                title: 'YouTube Music Account',
                icon: CupertinoIcons.music_note,
              ),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Icon(CupertinoIcons.music_note_2, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'YouTube Music',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sign in to sync liked songs, playlists, and history',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      CupertinoButton.filled(
                        child: const Text('Sign In'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const YouTubeAuthWebView(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        }

        return Column(
          children: [
            const SectionHeader(
              title: 'YouTube Music Account',
              icon: CupertinoIcons.person_crop_circle,
            ),
            ValueListenableBuilder<String?>(
              valueListenable: YouTubeAuthService().userName,
              builder: (context, name, _) {
                return ValueListenableBuilder<String?>(
                  valueListenable: YouTubeAuthService().userEmail,
                  builder: (context, email, _) {
                    return ValueListenableBuilder<String?>(
                      valueListenable: YouTubeAuthService().userAvatarUrl,
                      builder: (context, avatarUrl, _) {
                        return ListTile(
                          leading: avatarUrl != null
                              ? CircleAvatar(backgroundImage: NetworkImage(avatarUrl))
                              : const Icon(CupertinoIcons.person_crop_circle, size: 40),
                          title: Text(name ?? 'YouTube User'),
                          subtitle: Text(email ?? ''),
                        );
                      }
                    );
                  }
                );
              }
            ),
            ValueListenableBuilder<DateTime?>(
              valueListenable: YouTubeMusicSyncService().lastSyncTime,
              builder: (context, lastSync, _) {
                String syncText = 'Never';
                if (lastSync != null) {
                  final diff = DateTime.now().difference(lastSync);
                  if (diff.inDays > 0) {
                    syncText = '${diff.inDays} days ago';
                  } else if (diff.inHours > 0) {
                    syncText = '${diff.inHours} hours ago';
                  } else if (diff.inMinutes > 0) {
                    syncText = '${diff.inMinutes} minutes ago';
                  } else {
                    syncText = 'Just now';
                  }
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text('Last synced: $syncText', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                );
              },
            ),
            ValueListenableBuilder<bool>(
              valueListenable: ytAutoSyncLikes,
              builder: (context, value, _) {
                return CustomBar(
                  'Auto-sync liked songs',
                  CupertinoIcons.heart,
                  trailing: CupertinoSwitch(
                    value: value,
                    onChanged: (val) {
                      ytAutoSyncLikes.value = val;
                      Hive.box('settings').put('ytAutoSyncLikes', val);
                    },
                  ),
                );
              },
            ),
            ValueListenableBuilder<bool>(
              valueListenable: ytAutoSyncPlaylists,
              builder: (context, value, _) {
                return CustomBar(
                  'Auto-sync playlists',
                  CupertinoIcons.music_note_list,
                  trailing: CupertinoSwitch(
                    value: value,
                    onChanged: (val) {
                      ytAutoSyncPlaylists.value = val;
                      Hive.box('settings').put('ytAutoSyncPlaylists', val);
                    },
                  ),
                );
              },
            ),
            ValueListenableBuilder<bool>(
              valueListenable: ytReportHistory,
              builder: (context, value, _) {
                return CustomBar(
                  'Report play history',
                  CupertinoIcons.clock,
                  trailing: CupertinoSwitch(
                    value: value,
                    onChanged: (val) {
                      ytReportHistory.value = val;
                      Hive.box('settings').put('ytReportHistory', val);
                    },
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  CupertinoButton.filled(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: const Text('Sync Now'),
                    onPressed: () {
                      unawaited(YouTubeMusicSyncService().fullSync());
                      showToast(context, 'Sync started');
                    },
                  ),
                  CupertinoButton(
                    color: Theme.of(context).colorScheme.error,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: const Text('Sign Out'),
                    onPressed: () {
                      YouTubeAuthService().signOut();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildPreferencesSection(
    BuildContext context,
    Color primaryColor,
    Color activatedColor,
    Color inactivatedColor,
  ) {
    final isOffline = offlineMode.value;

    return Column(
      children: [
        SectionHeader(
          title: context.l10n.preferences,
          icon: FluentIcons.options_24_filled,
        ),
        CustomBar(
          context.l10n.accentColor,
          FluentIcons.color_24_regular,
          borderRadius: commonCustomBarRadiusFirst,
          onTap: () => _showAccentColorPicker(context),
        ),
        CustomBar(
          context.l10n.themeMode,
          FluentIcons.weather_sunny_28_regular,
          onTap: () => _showThemeModePicker(context),
        ),
        CustomBar(
          context.l10n.language,
          FluentIcons.translate_24_regular,
          onTap: () => _showLanguagePicker(context),
        ),
        CustomBar(
          context.l10n.audioQuality,
          FluentIcons.music_note_1_24_regular,
          onTap: () => _showAudioQualityPicker(context),
        ),
        if (themeMode == ThemeMode.dark)
          CustomBar(
            context.l10n.pureBlackTheme,
            FluentIcons.color_background_24_regular,
            description: context.l10n.pureBlackThemeDescription,
            trailing: Switch(
              value: usePureBlackColor.value,
              onChanged: (value) => _togglePureBlack(context, value),
            ),
          ),

        ValueListenableBuilder<bool>(
          valueListenable: showAudioQualityBadge,
          builder: (_, value, __) {
            return CustomBar(
              context.l10n.audioQualityBadge,
              FluentIcons.badge_24_regular,
              description: context.l10n.audioQualityBadgeDescription,
              trailing: Switch(
                value: value,
                onChanged: (value) => _toggleAudioQualityBadge(context, value),
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: wrappedEnabled,
          builder: (_, value, __) {
            return CustomBar(
              context.l10n.listeningStats,
              FluentIcons.clock_24_regular,
              description: context.l10n.listeningStatsDescription,
              trailing: Switch(
                value: value,
                onChanged: (value) => _toggleWrapped(context, value),
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: offlineMode,
          builder: (_, value, __) {
            return CustomBar(
              context.l10n.offlineMode,
              FluentIcons.cloud_off_24_regular,
              description: context.l10n.offlineModeDescription,
              borderRadius: isOffline
                  ? commonCustomBarRadiusLast
                  : BorderRadius.zero,
              trailing: Switch(
                value: value,
                onChanged: (value) => _toggleOfflineMode(context, value),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAudioSourcesSection(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: jiosaavnEnabled,
      builder: (_, isSaavnEnabled, __) {
        return Column(
          children: [
            const SectionHeader(
              title: 'Audio Sources',
              icon: FluentIcons.music_note_2_24_filled,
            ),
            CustomBar(
              'JioSaavn High Quality',
              FluentIcons.music_note_2_24_regular,
              description: 'Use JioSaavn for 320kbps AAC when available',
              trailing: Switch(
                value: isSaavnEnabled,
                onChanged: (value) {
                  jiosaavnEnabled.value = value;
                  addOrUpdateData<bool>('settings', 'jiosaavnEnabled', value);
                  showToast(context, context.l10n.settingChangedMsg);
                },
              ),
            ),
            if (isSaavnEnabled) ...[
              ValueListenableBuilder<String>(
                valueListenable: preferredSource,
                builder: (_, value, __) {
                  return CustomBar(
                    'Streaming Source',
                    FluentIcons.play_circle_24_regular,
                    description: value == 'auto'
                        ? 'Auto (Best Quality)'
                        : (value == 'youtube'
                            ? 'YouTube Only'
                            : 'JioSaavn Only'),
                    onTap: () => _showPreferredSourcePicker(context),
                  );
                },
              ),
              ValueListenableBuilder<String>(
                valueListenable: jiosaavnQuality,
                builder: (_, value, __) {
                  return CustomBar(
                    'JioSaavn Streaming Quality',
                    FluentIcons.cellular_data_3_24_regular,
                    description: value == '320'
                        ? 'High (320 kbps)'
                        : (value == '160'
                            ? 'Medium (160 kbps)'
                            : 'Low (96 kbps)'),
                    onTap: () => _showJioSaavnQualityPicker(context),
                  );
                },
              ),
              ValueListenableBuilder<String>(
                valueListenable: downloadSource,
                builder: (_, value, __) {
                  return CustomBar(
                    'Download Source',
                    FluentIcons.arrow_download_24_regular,
                    description: value == 'best'
                        ? 'Best Quality'
                        : (value == 'youtube'
                            ? 'YouTube Only'
                            : 'JioSaavn Only'),
                    onTap: () => _showDownloadSourcePicker(context),
                  );
                },
              ),
            ],
            ValueListenableBuilder<String>(
              valueListenable: downloadQuality,
              builder: (_, value, __) {
                return CustomBar(
                  'Download Quality',
                  FluentIcons.arrow_download_24_regular,
                  description: value == '320'
                      ? '320 kbps'
                      : (value == '160'
                          ? '160 kbps'
                          : '128 kbps'),
                  onTap: () => _showDownloadQualityPicker(context),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildOnlineFeaturesSection(BuildContext context) {
    return Column(
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: sponsorBlockSupport,
          builder: (_, value, __) {
            return CustomBar(
              'SponsorBlock',
              FluentIcons.cut_24_regular,
              description: context.l10n.sponsorBlockDescription,
              trailing: Switch(
                value: value,
                onChanged: (value) => _toggleSponsorBlock(context, value),
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: playNextSongAutomatically,
          builder: (_, value, __) {
            return CustomBar(
              context.l10n.automaticSongPicker,
              FluentIcons.music_note_2_play_20_regular,
              description: context.l10n.automaticSongPickerDescription,
              trailing: Switch(
                value: value,
                onChanged: (value) {
                  _toggleAutoPlayNext(context, value);
                  showToast(context, context.l10n.settingChangedMsg);
                },
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: externalRecommendations,
          builder: (_, value, __) {
            return CustomBar(
              context.l10n.externalRecommendations,
              FluentIcons.channel_share_24_regular,
              description: context.l10n.externalRecommendationsDescription,
              borderRadius: commonCustomBarRadiusLast,
              trailing: Switch(
                value: value,
                onChanged: (value) =>
                    _toggleExternalRecommendations(context, value),
              ),
            );
          },
        ),

        _buildToolsSection(context),
      ],
    );
  }

  Widget _buildToolsSection(BuildContext context) {
    return Column(
      children: [
        SectionHeader(
          title: context.l10n.tools,
          icon: FluentIcons.toolbox_24_filled,
        ),
        CustomBar(
          context.l10n.clearCache,
          FluentIcons.broom_24_regular,
          borderRadius: commonCustomBarRadiusFirst,
          onTap: () async {
            final cleared = await clearCache();
            showToast(
              context,
              cleared ? '${context.l10n.cacheMsg}!' : context.l10n.error,
            );
          },
        ),
        CustomBar(
          context.l10n.clearSearchHistory,
          FluentIcons.history_24_regular,
          onTap: () => _showConfirmationDialog(
            context: context,
            confirmationMessage: context.l10n.clearSearchHistoryQuestion,
            onSubmit: () {
              searchHistoryNotifier.value = [];
              deleteData('user', 'searchHistory');
              showToast(context, '${context.l10n.searchHistoryMsg}!');
            },
          ),
        ),
        CustomBar(
          context.l10n.clearRecentlyPlayed,
          FluentIcons.receipt_play_24_regular,
          onTap: () => _showConfirmationDialog(
            context: context,
            confirmationMessage: context.l10n.clearRecentlyPlayedQuestion,
            onSubmit: () {
              userRecentlyPlayed.value = [];
              deleteData('user', 'recentlyPlayedSongs');
              showToast(context, '${context.l10n.recentlyPlayedMsg}!');
            },
          ),
        ),
        CustomBar(
          context.l10n.clearListeningStats,
          FluentIcons.clock_24_regular,
          onTap: () => _showConfirmationDialog(
            context: context,
            confirmationMessage: context.l10n.clearListeningStatsQuestion,
            submitMessage: context.l10n.delete,
            isDangerous: true,
            onSubmit: () async {
              audioHandler.resetListeningStatsSession(flushStats: false);
              await listeningStatsService.clearStats();
              audioHandler.startListeningStatsSessionIfNeeded();
              if (context.mounted) {
                showToast(context, '${context.l10n.listeningStatsCleared}!');
              }
            },
          ),
        ),
        CustomBar(
          context.l10n.deleteDownloads,
          FluentIcons.delete_24_regular,
          onTap: () => _showConfirmationDialog(
            context: context,
            confirmationMessage: context.l10n.deleteDownloadsQuestion,
            submitMessage: context.l10n.delete,
            isDangerous: true,
            onSubmit: () async {
              try {
                await offlinePlaylistService.deleteAllDownloads();
                if (context.mounted) {
                  showToast(context, context.l10n.downloadsDeleted);
                }
              } catch (e) {
                if (context.mounted) {
                  showToast(context, context.l10n.error);
                }
              }
            },
          ),
        ),
        CustomBar(
          context.l10n.importSpotifyPlaylist,
          FluentIcons.arrow_upload_24_regular,
          onTap: () => context.push('/settings/import-spotify-playlist'),
        ),
        CustomBar(
          context.l10n.backupUserData,
          FluentIcons.cloud_sync_24_regular,
          onTap: () => _backupUserData(context),
        ),
        CustomBar(
          context.l10n.restoreUserData,
          FluentIcons.cloud_add_24_regular,
          onTap: () async {
            try {
              final result = await restoreData(context);
              if (result.success) {
                reloadSettingsFromStorage();
                reloadSongLibraryStateFromStorage();
                reloadPlaylistLibraryStateFromStorage();
                reloadSearchHistoryFromStorage();
                listeningStatsService.reload();
                await audioHandler.setShuffleMode(
                  shuffleNotifier.value
                      ? AudioServiceShuffleMode.all
                      : AudioServiceShuffleMode.none,
                );
                await audioHandler.setRepeatMode(repeatNotifier.value);
                themeMode = getThemeMode(themeModeSetting);
                brightness = getBrightnessFromThemeMode(themeMode);
                if (context.mounted) {
                  await Musify.updateAppState(
                    context,
                    newThemeMode: themeMode,
                    newLocale: languageSetting,
                    newAccentColor: primaryColorSetting,
                    useSystemColor: useSystemColor.value,
                  );
                  NavigationManager.refreshRouter();
                }
              }
              if (context.mounted) {
                showToast(
                  context,
                  result.message,
                  icon: result.success
                      ? null
                      : FluentIcons.error_circle_24_regular,
                );
              }
            } catch (e, str) {
              logger.log('Error restoring data', error: e, stackTrace: str);
              if (context.mounted) {
                showToast(
                  context,
                  context.l10n.error,
                  icon: FluentIcons.error_circle_24_regular,
                );
              }
            }
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Center(
            child: Column(
              children: [
                Text(
                  'Musified v$appVersion (Build 4)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'YouTube Music + JioSaavn 320k Lossless',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildOthersSection(BuildContext context) {
    return Column(
      children: [
        SectionHeader(
          title: context.l10n.others,
          icon: FluentIcons.more_circle_24_filled,
        ),
        CustomBar(
          context.l10n.licenses,
          FluentIcons.document_24_regular,
          borderRadius: commonCustomBarRadiusFirst,
          onTap: () => NavigationManager.router.go('/settings/license'),
        ),
        CustomBar(
          context.l10n.translate,
          FluentIcons.translate_24_regular,
          description: context.l10n.translateDescription,
          onTap: () =>
              launchURL(Uri.parse('https://crowdin.com/project/musify')),
        ),
        CustomBar(
          '${context.l10n.copyLogs} (${logger.getLogCount()})',
          FluentIcons.error_circle_24_regular,
          onTap: () async => showToast(context, await logger.copyLogs(context)),
        ),
        CustomBar(
          'Musified iOS v1.1.0',
          FluentIcons.info_24_regular,
          borderRadius: commonCustomBarRadiusLast,
          onTap: () {},
        ),
      ],
    );
  }

  void _showAccentColorPicker(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    showCustomBottomSheet(
      context,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          shrinkWrap: true,
          physics: const BouncingScrollPhysics(),
          itemCount: availableColors.length,
          itemBuilder: (context, index) {
            final color = availableColors[index];
            final isSelected = color == primaryColorSetting;

            return GestureDetector(
              onTap: () {
                addOrUpdateData<int>(
                  'settings',
                  'accentColor',
                  color.toARGB32(),
                );
                Musify.updateAppState(
                  context,
                  newAccentColor: color,
                  useSystemColor: false,
                );
                showToast(context, context.l10n.accentChangeMsg);
                Navigator.pop(context);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: colorScheme.onSurface, width: 3)
                      : null,
                ),
                child: isSelected
                    ? Icon(
                        FluentIcons.checkmark_20_filled,
                        color: color.computeLuminance() > 0.5
                            ? Colors.black
                            : Colors.white,
                        size: 24,
                      )
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }

  void _showThemeModePicker(BuildContext context) {
    final availableModes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];
    const modeIcons = [
      FluentIcons.phone_24_regular,
      FluentIcons.weather_sunny_24_regular,
      FluentIcons.weather_moon_24_regular,
    ];

    showCustomBottomSheet(
      context,
      ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: commonListViewBottomPadding,
        itemCount: availableModes.length,
        itemBuilder: (context, index) {
          final mode = availableModes[index];
          final modeNames = [
            context.l10n.themeModeSystem,
            context.l10n.themeModeLight,
            context.l10n.themeModeDark,
          ];

          return BottomSheetBar(
            modeNames[mode.index],
            () {
              addOrUpdateData<int>('settings', 'themeIndex', mode.index);
              Musify.updateAppState(context, newThemeMode: mode);
              Navigator.pop(context);
            },
            themeMode == mode,
            icon: modeIcons[mode.index],
          );
        },
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    final availableLanguages = appLanguages.toList();
    final activeLanguageCode = Localizations.localeOf(context).languageCode;
    final activeScriptCode = Localizations.localeOf(context).scriptCode;
    final activeLanguageFullCode = activeScriptCode != null
        ? '$activeLanguageCode-$activeScriptCode'
        : activeLanguageCode;

    showCustomBottomSheet(
      context,
      ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: commonListViewBottomPadding,
        itemCount: availableLanguages.length,
        itemBuilder: (context, index) {
          final language = availableLanguages[index];
          final newLocale = getLocaleFromLanguageCode(language);
          final newLocaleFullCode = newLocale.scriptCode != null
              ? '${newLocale.languageCode}-${newLocale.scriptCode}'
              : newLocale.languageCode;

          return BottomSheetBar(getLanguageDisplayName(context, language), () {
            addOrUpdateData<String>(
              'settings',
              'languageCode',
              newLocaleFullCode,
            );
            Musify.updateAppState(context, newLocale: newLocale);
            showToast(context, context.l10n.languageMsg);
            Navigator.pop(context);
          }, activeLanguageFullCode == newLocaleFullCode);
        },
      ),
    );
  }

  void _showAudioQualityPicker(BuildContext context) {
    final availableQualities = ['low', 'medium', 'high'];
    final qualityNames = [
      context.l10n.audioQualityLow,
      context.l10n.audioQualityMedium,
      context.l10n.audioQualityHigh,
    ];
    const qualityIcons = [
      FluentIcons.speaker_1_24_regular,
      FluentIcons.speaker_2_24_regular,
      FluentIcons.speaker_2_24_filled,
    ];

    showCustomBottomSheet(
      context,
      ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: commonListViewBottomPadding,
        itemCount: availableQualities.length,
        itemBuilder: (context, index) {
          final quality = availableQualities[index];

          return BottomSheetBar(
            qualityNames[index],
            () {
              addOrUpdateData<String>('settings', 'audioQuality', quality);
              audioQualitySetting.value = quality;
              showToast(context, context.l10n.audioQualityMsg);
              Navigator.pop(context);
            },
            audioQualitySetting.value == quality,
            icon: qualityIcons[index],
          );
        },
      ),
    );
  }


  void _togglePureBlack(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'usePureBlackColor', value);
    usePureBlackColor.value = value;
    Musify.updateAppState(context);
    showToast(context, context.l10n.settingChangedMsg);
  }

  void _toggleAudioQualityBadge(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'showAudioQualityBadge', value);
    showAudioQualityBadge.value = value;
    showToast(context, context.l10n.settingChangedMsg);
  }

  Future<void> _toggleWrapped(BuildContext context, bool value) async {
    if (!value) {
      audioHandler.resetListeningStatsSession(
        countCurrentTick: true,
        flushStats: false,
      );
      await listeningStatsService.flush();
    }

    await addOrUpdateData<bool>('settings', 'wrappedEnabled', value);
    wrappedEnabled.value = value;
    listeningStatsService.reload();
    if (value) {
      audioHandler.startListeningStatsSessionIfNeeded();
    }
    if (context.mounted) {
      showToast(context, context.l10n.settingChangedMsg);
    }
  }

  void _toggleOfflineMode(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'offlineMode', value);
    offlineMode.value = value;

    // Trigger router refresh and notify about the change
    NavigationManager.refreshRouter();

    showToast(context, context.l10n.settingChangedMsg);
  }

  void _toggleSponsorBlock(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'sponsorBlockSupport', value);
    sponsorBlockSupport.value = value;
    showToast(context, context.l10n.settingChangedMsg);
  }

  void _toggleAutoPlayNext(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'playNextSongAutomatically', value);
    playNextSongAutomatically.value = value;
    showToast(context, context.l10n.settingChangedMsg);
  }

  void _toggleExternalRecommendations(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'externalRecommendations', value);
    externalRecommendations.value = value;
    showToast(context, context.l10n.settingChangedMsg);
  }

  void _showConfirmationDialog({
    required BuildContext context,
    required String confirmationMessage,
    required VoidCallback onSubmit,
    String? submitMessage,
    bool isDangerous = false,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ConfirmationDialog(
          submitMessage: submitMessage ?? context.l10n.clear,
          confirmationMessage: confirmationMessage,
          isDangerous: isDangerous,
          onCancel: () => Navigator.of(context).pop(),
          onSubmit: () {
            Navigator.of(context).pop();
            onSubmit();
          },
        );
      },
    );
  }

  Future<void> _backupUserData(BuildContext context) async {
    try {
      final result = await backupData(context);
      if (context.mounted) {
        showToast(
          context,
          result.message,
          icon: result.success ? null : FluentIcons.error_circle_24_regular,
        );
      }
    } catch (e, stackTrace) {
      logger.log('Error backing up data', error: e, stackTrace: stackTrace);
      if (context.mounted) {
        showToast(
          context,
          context.l10n.error,
          icon: FluentIcons.error_circle_24_regular,
        );
      }
    }
  }

  void _showPreferredSourcePicker(BuildContext context) {
    final availableSources = ['auto', 'youtube', 'saavn'];
    final sourceNames = [
      'Auto (Best Quality)',
      'YouTube Only',
      'JioSaavn Only',
    ];
    const sourceIcons = [
      FluentIcons.sparkle_24_regular,
      FluentIcons.video_24_regular,
      FluentIcons.music_note_1_24_regular,
    ];

    showCustomBottomSheet(
      context,
      ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: commonListViewBottomPadding,
        itemCount: availableSources.length,
        itemBuilder: (context, index) {
          final source = availableSources[index];

          return BottomSheetBar(
            sourceNames[index],
            () {
              addOrUpdateData<String>('settings', 'preferredSource', source);
              preferredSource.value = source;
              showToast(context, context.l10n.settingChangedMsg);
              Navigator.pop(context);
            },
            preferredSource.value == source,
            icon: sourceIcons[index],
          );
        },
      ),
    );
  }

  void _showJioSaavnQualityPicker(BuildContext context) {
    final availableQualities = ['96', '160', '320'];
    final qualityNames = [
      'Low (96 kbps)',
      'Medium (160 kbps)',
      'High (320 kbps)',
    ];
    const qualityIcons = [
      FluentIcons.cellular_data_1_24_regular,
      FluentIcons.cellular_data_2_24_regular,
      FluentIcons.cellular_data_3_24_regular,
    ];

    showCustomBottomSheet(
      context,
      ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: commonListViewBottomPadding,
        itemCount: availableQualities.length,
        itemBuilder: (context, index) {
          final quality = availableQualities[index];

          return BottomSheetBar(
            qualityNames[index],
            () {
              addOrUpdateData<String>('settings', 'jiosaavnQuality', quality);
              jiosaavnQuality.value = quality;
              showToast(context, context.l10n.settingChangedMsg);
              Navigator.pop(context);
            },
            jiosaavnQuality.value == quality,
            icon: qualityIcons[index],
          );
        },
      ),
    );
  }

  void _showDownloadSourcePicker(BuildContext context) {
    final availableSources = ['best', 'youtube', 'saavn'];
    final sourceNames = [
      'Best Quality',
      'YouTube Only',
      'JioSaavn Only',
    ];
    const sourceIcons = [
      FluentIcons.sparkle_24_regular,
      FluentIcons.video_24_regular,
      FluentIcons.music_note_1_24_regular,
    ];

    showCustomBottomSheet(
      context,
      ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: commonListViewBottomPadding,
        itemCount: availableSources.length,
        itemBuilder: (context, index) {
          final source = availableSources[index];

          return BottomSheetBar(
            sourceNames[index],
            () {
              addOrUpdateData<String>('settings', 'downloadSource', source);
              downloadSource.value = source;
              showToast(context, context.l10n.settingChangedMsg);
              Navigator.pop(context);
            },
            downloadSource.value == source,
            icon: sourceIcons[index],
          );
        },
      ),
    );
  }

  void _showDownloadQualityPicker(BuildContext context) {
    final availableQualities = ['128', '160', '320'];
    final qualityNames = [
      '128 kbps',
      '160 kbps',
      '320 kbps',
    ];
    const qualityIcons = [
      FluentIcons.cellular_data_1_24_regular,
      FluentIcons.cellular_data_2_24_regular,
      FluentIcons.cellular_data_3_24_regular,
    ];

    showCustomBottomSheet(
      context,
      ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: commonListViewBottomPadding,
        itemCount: availableQualities.length,
        itemBuilder: (context, index) {
          final quality = availableQualities[index];

          return BottomSheetBar(
            qualityNames[index],
            () {
              addOrUpdateData<String>('settings', 'downloadQuality', quality);
              downloadQuality.value = quality;
              showToast(context, context.l10n.settingChangedMsg);
              Navigator.pop(context);
            },
            downloadQuality.value == quality,
            icon: qualityIcons[index],
          );
        },
      ),
    );
  }
}
