import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/services.dart';
import 'package:musified/models/youtube_innertube_client_entry.dart';
import 'package:musified/services/common_services.dart';
import 'package:musified/services/ytdlp_client_sync_service.dart';
import 'package:musified/theme/musified_style.dart';
import 'package:musified/utilities/flutter_toast.dart';

Future<void> showYoutubeClientPickerSheet(BuildContext context) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => const _YoutubeClientPickerSheet(),
  );
}

class _YoutubeClientPickerSheet extends StatefulWidget {
  const _YoutubeClientPickerSheet();

  @override
  State<_YoutubeClientPickerSheet> createState() =>
      _YoutubeClientPickerSheetState();
}

class _YoutubeClientPickerSheetState extends State<_YoutubeClientPickerSheet> {
  bool _syncing = false;

  Future<void> _sync() async {
    if (_syncing) return;
    HapticFeedback.mediumImpact();
    setState(() => _syncing = true);
    final result = await YtdlpClientSyncService.instance.syncFromYtdlp();
    setState(() => _syncing = false);

    if (!mounted) return;
    if (result.ok) {
      final commit = result.commit != null ? ' (${result.commit})' : '';
      showToast(
        context,
        'Synced ${result.count} clients from yt-dlp$commit',
      );
    } else {
      showToast(context, result.error ?? 'Sync failed');
    }
  }

  Future<void> _pick(YoutubeInnertubeClientEntry entry) async {
    if (entry.requiresAuth) {
      showToast(context, 'This client requires YouTube login');
      return;
    }
    HapticFeedback.selectionClick();
    await YtdlpClientSyncService.instance.selectClient(entry.id);
    await invalidateAllSongStreamCaches();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final registry = YtdlpClientSyncService.instance;

    return CupertinoPopupSurface(
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.62,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'YouTube Stream Client',
                              style: TextStyle(
                                fontFamily: MusifiedStyle.displayFont,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            ValueListenableBuilder<DateTime?>(
                              valueListenable: registry.lastSyncedAt,
                              builder: (_, syncedAt, __) {
                                return ValueListenableBuilder<String?>(
                                  valueListenable: registry.lastSyncCommit,
                                  builder: (_, commit, ___) {
                                    final parts = <String>[];
                                    if (syncedAt != null) {
                                      parts.add(
                                        'Synced ${_formatSync(syncedAt)}',
                                      );
                                    } else {
                                      parts.add('Using built-in clients');
                                    }
                                    if (commit != null) {
                                      parts.add('yt-dlp $commit');
                                    }
                                    return Text(
                                      parts.join(' · '),
                                      style: const TextStyle(
                                        fontFamily: MusifiedStyle.uiFont,
                                        fontSize: 12,
                                        color: CupertinoColors.systemGrey,
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        onPressed: _syncing ? null : _sync,
                        child: _syncing
                            ? const CupertinoActivityIndicator()
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(CupertinoIcons.arrow_2_circlepath, size: 18),
                                  SizedBox(width: 6),
                                  Text('Sync'),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Sync pulls InnerTube client definitions from yt-dlp on GitHub. Only the client you select is used for playback and downloads — no automatic fallback.',
                    style: TextStyle(
                      fontFamily: MusifiedStyle.uiFont,
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ValueListenableBuilder<List<YoutubeInnertubeClientEntry>>(
                    valueListenable: registry.catalog,
                    builder: (context, catalog, _) {
                      return ValueListenableBuilder<String>(
                        valueListenable: registry.selectedClientId,
                        builder: (context, selectedId, _) {
                          return ListView.builder(
                            padding: const EdgeInsets.only(bottom: 12),
                            itemCount: catalog.length,
                            itemBuilder: (context, index) {
                              final entry = catalog[index];
                              final selected = entry.id == selectedId;
                              return CupertinoListTile(
                                title: Text(entry.displayLabel),
                                subtitle: Text(entry.pickerSubtitle),
                                trailing: selected
                                    ? const Icon(
                                        CupertinoIcons.check_mark_circled_solid,
                                        color: CupertinoColors.activeBlue,
                                      )
                                    : null,
                                onTap: () => _pick(entry),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatSync(DateTime time) {
    final local = time.toLocal();
    return '${local.month}/${local.day} ${local.hour}:${local.minute.toString().padLeft(2, '0')}';
  }
}
