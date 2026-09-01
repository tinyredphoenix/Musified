import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:musified/models/youtube_innertube_client_entry.dart';
import 'package:musified/services/data_manager.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

const _ytdlpBasePyUrl =
    'https://raw.githubusercontent.com/yt-dlp/yt-dlp/master/yt_dlp/extractor/youtube/_base.py';

const _defaultClientId = 'android_vr';

/// Registry for InnerTube clients: built-in defaults + optional yt-dlp sync.
class YtdlpClientSyncService {
  YtdlpClientSyncService._();
  static final YtdlpClientSyncService instance = YtdlpClientSyncService._();

  final ValueNotifier<List<YoutubeInnertubeClientEntry>> catalog =
      ValueNotifier<List<YoutubeInnertubeClientEntry>>([]);
  final ValueNotifier<String> selectedClientId =
      ValueNotifier<String>(_defaultClientId);
  final ValueNotifier<DateTime?> lastSyncedAt = ValueNotifier<DateTime?>(null);
  final ValueNotifier<String?> lastSyncCommit = ValueNotifier<String?>(null);

  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    await _loadFromStorage();
  }

  List<YoutubeInnertubeClientEntry> get builtinClients =>
      List<YoutubeInnertubeClientEntry>.unmodifiable(_builtinCatalog());

  YoutubeInnertubeClientEntry? entryById(String id) {
    for (final entry in catalog.value) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  YoutubeInnertubeClientEntry? selectedEntry() =>
      entryById(selectedClientId.value);

  /// Selected client only — no built-in fallback if missing or auth-required.
  YoutubeApiClient? selectedYoutubeClient() {
    final entry = selectedEntry();
    if (entry == null || entry.requiresAuth) return null;
    return entry.toYoutubeApiClient();
  }

  String selectedClientLabel() {
    final entry = selectedEntry();
    if (entry == null) return 'ANDROID_VR (default)';
    return entry.displayLabel;
  }

  Future<void> selectClient(String id) async {
    if (entryById(id) == null) return;
    selectedClientId.value = id;
    await addOrUpdateData('settings', 'youtubeInnertubeClientId', id);
  }

  Future<YtdlpClientSyncResult> syncFromYtdlp() async {
    try {
      final response = await http
          .get(Uri.parse(_ytdlpBasePyUrl))
          .timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) {
        return YtdlpClientSyncResult.failed(
          'Could not download yt-dlp client list (${response.statusCode})',
        );
      }

      final parsed = _parseInnertubeClients(response.body);
      if (parsed.isEmpty) {
        return YtdlpClientSyncResult.failed(
          'No playable clients found in yt-dlp source',
        );
      }

      final merged = _mergeCatalog(parsed);
      catalog.value = merged;

      final syncedAt = DateTime.now();
      lastSyncedAt.value = syncedAt;

      String? commit;
      try {
        final meta = await http
            .get(
              Uri.parse(
                'https://api.github.com/repos/yt-dlp/yt-dlp/commits/master',
              ),
              headers: {'Accept': 'application/vnd.github+json'},
            )
            .timeout(const Duration(seconds: 10));
        if (meta.statusCode == 200) {
          final body = jsonDecode(meta.body) as Map<String, dynamic>;
          final sha = body['sha']?.toString();
          if (sha != null && sha.length >= 7) {
            commit = sha.substring(0, 7);
            lastSyncCommit.value = commit;
          }
        }
      } catch (_) {
        // Commit metadata is optional.
      }

      await addOrUpdateData(
        'settings',
        'youtubeInnertubeClientsJson',
        jsonEncode(
          merged.map((e) {
            try {
              return e.toJson();
            } catch (err) {
              throw FormatException('Client ${e.id} not serializable: $err');
            }
          }).toList(),
        ),
      );
      await addOrUpdateData(
        'settings',
        'youtubeInnertubeSyncAt',
        syncedAt.toIso8601String(),
      );
      if (commit != null) {
        await addOrUpdateData('settings', 'youtubeInnertubeSyncCommit', commit);
      }

      if (entryById(selectedClientId.value) == null) {
        final fallback = merged.firstWhere(
          (e) => e.id == _defaultClientId,
          orElse: () => merged.first,
        );
        await selectClient(fallback.id);
      }

      return YtdlpClientSyncResult.success(
        count: merged.length,
        commit: commit,
      );
    } catch (e) {
      return YtdlpClientSyncResult.failed('$e');
    }
  }

  Future<void> _loadFromStorage() async {
    catalog.value = _mergeCatalog([]);

    if (!Hive.isBoxOpen('settings')) {
      selectedClientId.value = _defaultClientId;
      return;
    }

    final settings = Hive.box('settings');
    final storedId = settings.get('youtubeInnertubeClientId');
    if (storedId is String && storedId.isNotEmpty) {
      selectedClientId.value = storedId;
    }

    final syncAtRaw = settings.get('youtubeInnertubeSyncAt');
    if (syncAtRaw is String) {
      lastSyncedAt.value = DateTime.tryParse(syncAtRaw);
    }

    final commit = settings.get('youtubeInnertubeSyncCommit');
    if (commit is String) lastSyncCommit.value = commit;

    final rawCatalog = settings.get('youtubeInnertubeClientsJson');
    if (rawCatalog is String && rawCatalog.isNotEmpty) {
      try {
        final list = jsonDecode(rawCatalog) as List<dynamic>;
        final synced = list
            .whereType<Map>()
            .map((m) => YoutubeInnertubeClientEntry.fromJson(
                  Map<String, dynamic>.from(m),
                ))
            .where((e) => e.id.isNotEmpty && !e.requiresAuth)
            .toList();
        if (synced.isNotEmpty) {
          catalog.value = _mergeCatalog(synced);
        }
      } catch (_) {
        // Keep built-in catalog.
      }
    }

    if (entryById(selectedClientId.value) == null) {
      selectedClientId.value = _defaultClientId;
    }
  }

  List<YoutubeInnertubeClientEntry> _mergeCatalog(
    List<YoutubeInnertubeClientEntry> synced,
  ) {
    final byId = <String, YoutubeInnertubeClientEntry>{};
    for (final builtin in _builtinCatalog()) {
      byId[builtin.id] = builtin;
    }
    for (final entry in synced) {
      byId[entry.id] = entry;
    }
    final merged = byId.values.toList();
    merged.sort((a, b) {
      if (a.isRecommended != b.isRecommended) {
        return a.isRecommended ? -1 : 1;
      }
      return a.id.compareTo(b.id);
    });
    return merged;
  }

  List<YoutubeInnertubeClientEntry> _builtinCatalog() {
    return [
      _fromStatic('android_vr', YoutubeApiClient.androidVr, recommended: true),
      _fromStatic('visionos', YoutubeApiClient.visionOs, recommended: true),
      _fromStatic('android', YoutubeApiClient.android),
      _fromStatic('mweb', YoutubeApiClient.mweb),
      _fromStatic('web_safari', YoutubeApiClient.safari),
      _fromStatic('tv', YoutubeApiClient.tv),
    ];
  }

  YoutubeInnertubeClientEntry _fromStatic(
    String id,
    YoutubeApiClient client, {
    bool recommended = false,
  }) {
    final payload = Map<String, dynamic>.from(client.payload);
    final clientMap = payload['context']?['client'] as Map?;
    return YoutubeInnertubeClientEntry(
      id: id,
      clientName: clientMap?['clientName']?.toString() ?? id,
      clientVersion: clientMap?['clientVersion']?.toString() ?? '',
      host: _hostFromApiUrl(client.apiUrl),
      payload: payload,
      apiUrl: client.apiUrl,
      userAgent: clientMap?['userAgent']?.toString(),
      isBuiltin: true,
      isRecommended: recommended,
    );
  }

  String _hostFromApiUrl(String apiUrl) {
    final uri = Uri.tryParse(apiUrl);
    return uri?.host ?? 'www.youtube.com';
  }
}

class YtdlpClientSyncResult {
  const YtdlpClientSyncResult._({
    required this.ok,
    this.count = 0,
    this.commit,
    this.error,
  });

  final bool ok;
  final int count;
  final String? commit;
  final String? error;

  factory YtdlpClientSyncResult.success({required int count, String? commit}) =>
      YtdlpClientSyncResult._(ok: true, count: count, commit: commit);

  factory YtdlpClientSyncResult.failed(String error) =>
      YtdlpClientSyncResult._(ok: false, error: error);
}

List<YoutubeInnertubeClientEntry> parseInnertubeClientsFromYtdlp(String source) =>
    _parseInnertubeClients(source);

List<YoutubeInnertubeClientEntry> _parseInnertubeClients(String source) {
  final start = source.indexOf('INNERTUBE_CLIENTS = {');
  if (start < 0) return [];

  final sectionStart = start + 'INNERTUBE_CLIENTS = {'.length;
  final sectionEnd = _findSectionEnd(source, sectionStart - 1);
  if (sectionEnd == null) return [];

  final section = source.substring(sectionStart - 1, sectionEnd + 1);
  final blocks = _extractTopLevelClientBlocks(section);
  final entries = <YoutubeInnertubeClientEntry>[];

  for (final block in blocks) {
    final entry = _parseClientBlock(block.key, block.value);
    if (entry != null) entries.add(entry);
  }
  return entries;
}

int? _findSectionEnd(String source, int openBraceIndex) {
  var depth = 0;
  for (var i = openBraceIndex; i < source.length; i++) {
    final char = source[i];
    if (char == '{') depth++;
    if (char == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return null;
}

List<({String key, String value})> _extractTopLevelClientBlocks(String section) {
  final results = <({String key, String value})>[];
  final keyRegex = RegExp("\n '([^']+)': \\{");
  var searchFrom = 0;

  while (true) {
    final match = keyRegex.firstMatch(section.substring(searchFrom));
    if (match == null) break;

    final absoluteStart = searchFrom + match.start;
    final key = match.group(1)!;
    if (key.startsWith('_')) {
      searchFrom = searchFrom + match.end;
      continue;
    }

    final braceIndex = section.indexOf('{', absoluteStart);
    final end = _findSectionEnd(section, braceIndex);
    if (end == null) break;

    results.add((key: key, value: section.substring(braceIndex, end + 1)));
    searchFrom = end + 1;
  }
  return results;
}

YoutubeInnertubeClientEntry? _parseClientBlock(String id, String block) {
  if (block.contains("'REQUIRE_AUTH': True")) return null;

  final host = _extractQuotedField(block, 'INNERTUBE_HOST') ?? 'www.youtube.com';
  final clientName = _extractQuotedField(block, 'clientName');
  final clientVersion = _extractQuotedField(block, 'clientVersion');
  if (clientName == null || clientVersion == null) return null;

  final client = <String, dynamic>{
    'clientName': clientName,
    'clientVersion': clientVersion,
    'hl': 'en',
    'timeZone': 'UTC',
    'utcOffsetMinutes': 0,
  };

  void putString(String field) {
    final value = _extractQuotedField(block, field);
    if (value != null) client[field] = value;
  }

  void putInt(String field) {
    final value = _extractIntField(block, field);
    if (value != null) client[field] = value;
  }

  putString('userAgent');
  putString('deviceMake');
  putString('deviceModel');
  putString('osName');
  putString('osVersion');
  putString('platform');
  putString('gl');
  putInt('androidSdkVersion');

  final payload = <String, dynamic>{
    'context': <String, dynamic>{'client': client},
  };

  final apiUrl = 'https://$host/youtubei/v1/player?prettyPrint=false';

  return YoutubeInnertubeClientEntry(
    id: id,
    clientName: clientName,
    clientVersion: clientVersion,
    host: host,
    payload: payload,
    apiUrl: apiUrl,
    userAgent: client['userAgent']?.toString(),
    isRecommended: id == 'android_vr' || id == 'visionos',
  );
}

String? _extractQuotedField(String block, String field) {
  final pattern = RegExp("'$field': '((?:\\\\'|[^'])*)'");
  final match = pattern.firstMatch(block);
  if (match == null) return null;
  return match.group(1)?.replaceAll(r"\'", "'");
}

int? _extractIntField(String block, String field) {
  final match = RegExp("'$field': (\\d+)").firstMatch(block);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}
