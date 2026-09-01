import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:musified/models/youtube_innertube_client_entry.dart';
import 'package:musified/services/data_manager.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

const _ytdlpBasePyUrl =
    'https://raw.githubusercontent.com/yt-dlp/yt-dlp/master/yt_dlp/extractor/youtube/_base.py';

/// Musified resolves streams with exactly one InnerTube client.
///
/// VISIONOS is the only client that currently returns directly playable
/// googlevideo URLs: it needs no PO Token and no JS signature deciphering
/// (which Musified cannot do). ANDROID/IOS/WEB hand back ciphered or empty
/// URLs, and ANDROID_VR/MWEB are answered with HTTP 403.
///
/// Syncing refreshes this client's version and user-agent from yt-dlp so the
/// app keeps working when YouTube rotates them, without shipping a new build.
const _activeClientId = 'visionos';

const _clientEntryKey = 'youtubeInnertubeActiveClient';
const _syncAtKey = 'youtubeInnertubeSyncAt';
const _syncCommitKey = 'youtubeInnertubeSyncCommit';

class YtdlpClientSyncService {
  YtdlpClientSyncService._();
  static final YtdlpClientSyncService instance = YtdlpClientSyncService._();

  final ValueNotifier<DateTime?> lastSyncedAt = ValueNotifier<DateTime?>(null);
  final ValueNotifier<String?> lastSyncCommit = ValueNotifier<String?>(null);

  /// Bumped whenever the active definition changes, so settings can rebuild.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  final ValueNotifier<bool> syncing = ValueNotifier<bool>(false);

  YoutubeInnertubeClientEntry _active = builtinVisionOsEntry();
  bool _loaded = false;

  YoutubeInnertubeClientEntry get activeEntry => _active;

  String get clientLabel => _active.displayLabel;

  YoutubeApiClient activeClient() => _active.toYoutubeApiClient();

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;

    if (!Hive.isBoxOpen('settings')) return;
    final settings = Hive.box('settings');

    final syncAt = settings.get(_syncAtKey);
    if (syncAt is String) lastSyncedAt.value = DateTime.tryParse(syncAt);

    final commit = settings.get(_syncCommitKey);
    if (commit is String) lastSyncCommit.value = commit;

    final raw = settings.get(_clientEntryKey);
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final entry = YoutubeInnertubeClientEntry.fromJson(
            Map<String, dynamic>.from(decoded),
          );
          if (entry.isUsable) {
            _active = entry;
            revision.value++;
          }
        }
      } catch (_) {
        // Keep the built-in definition.
      }
    }
  }

  Future<YtdlpClientSyncResult> syncFromYtdlp() async {
    if (syncing.value) {
      return YtdlpClientSyncResult.failed('Sync already running');
    }
    syncing.value = true;
    try {
      final response = await http
          .get(Uri.parse(_ytdlpBasePyUrl))
          .timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) {
        return YtdlpClientSyncResult.failed(
          'yt-dlp download failed (HTTP ${response.statusCode})',
        );
      }

      final clients = parseInnertubeClientsFromYtdlp(response.body);
      if (clients.isEmpty) {
        return YtdlpClientSyncResult.failed(
          'Could not read client definitions from yt-dlp',
        );
      }

      final match = clients.where((e) => e.id == _activeClientId).toList();
      if (match.isEmpty) {
        return YtdlpClientSyncResult.failed(
          'yt-dlp no longer defines the $_activeClientId client',
        );
      }

      final entry = match.first;
      if (!entry.isUsable) {
        return YtdlpClientSyncResult.failed(
          'Synced $_activeClientId definition was incomplete',
        );
      }

      _active = entry;
      revision.value++;

      final syncedAt = DateTime.now();
      lastSyncedAt.value = syncedAt;

      await addOrUpdateData('settings', _clientEntryKey, jsonEncode(entry.toJson()));
      await addOrUpdateData('settings', _syncAtKey, syncedAt.toIso8601String());

      final commit = await _latestCommitSha();
      if (commit != null) {
        lastSyncCommit.value = commit;
        await addOrUpdateData('settings', _syncCommitKey, commit);
      }

      return YtdlpClientSyncResult.success(
        label: entry.displayLabel,
        commit: commit,
      );
    } catch (e) {
      return YtdlpClientSyncResult.failed(_readableError(e));
    } finally {
      syncing.value = false;
    }
  }

  Future<String?> _latestCommitSha() async {
    try {
      final response = await http
          .get(
            Uri.parse('https://api.github.com/repos/yt-dlp/yt-dlp/commits/master'),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      if (body is! Map) return null;
      final sha = body['sha']?.toString();
      if (sha == null || sha.length < 7) return null;
      return sha.substring(0, 7);
    } catch (_) {
      return null;
    }
  }
}

String _readableError(Object error) {
  final text = error.toString();
  if (text.contains('SocketException') || text.contains('Failed host lookup')) {
    return 'No internet connection';
  }
  if (text.contains('TimeoutException')) {
    return 'yt-dlp request timed out';
  }
  return text.split('\n').first;
}

class YtdlpClientSyncResult {
  const YtdlpClientSyncResult._({
    required this.ok,
    this.label,
    this.commit,
    this.error,
  });

  final bool ok;
  final String? label;
  final String? commit;
  final String? error;

  factory YtdlpClientSyncResult.success({required String label, String? commit}) =>
      YtdlpClientSyncResult._(ok: true, label: label, commit: commit);

  factory YtdlpClientSyncResult.failed(String error) =>
      YtdlpClientSyncResult._(ok: false, error: error);
}

/// Compiled-in fallback used before the first sync, or if a sync is unusable.
YoutubeInnertubeClientEntry builtinVisionOsEntry() {
  const client = YoutubeApiClient.visionOs;
  final payload = Map<String, dynamic>.from(client.payload);
  final clientMap = payload['context']?['client'] as Map?;
  return YoutubeInnertubeClientEntry(
    id: _activeClientId,
    clientName: clientMap?['clientName']?.toString() ?? 'VISIONOS',
    clientVersion: clientMap?['clientVersion']?.toString() ?? '',
    host: Uri.tryParse(client.apiUrl)?.host ?? 'www.youtube.com',
    payload: payload,
    apiUrl: client.apiUrl,
    userAgent: clientMap?['userAgent']?.toString(),
    isBuiltin: true,
  );
}

/// Extracts the InnerTube client table from yt-dlp's `youtube/_base.py`.
List<YoutubeInnertubeClientEntry> parseInnertubeClientsFromYtdlp(String source) {
  const marker = 'INNERTUBE_CLIENTS = {';
  final start = source.indexOf(marker);
  if (start < 0) return [];

  final openBrace = start + marker.length - 1;
  final end = _matchingBrace(source, openBrace);
  if (end == null) return [];

  final section = source.substring(openBrace, end + 1);
  final entries = <YoutubeInnertubeClientEntry>[];
  for (final block in _topLevelClientBlocks(section)) {
    final entry = _parseClientBlock(block.key, block.value);
    if (entry != null) entries.add(entry);
  }
  return entries;
}

int? _matchingBrace(String source, int openBraceIndex) {
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

List<({String key, String value})> _topLevelClientBlocks(String section) {
  final results = <({String key, String value})>[];
  // Top-level client keys sit at one level of indentation inside the table.
  final keyRegex = RegExp("\n\\s{1,8}'([A-Za-z0-9_]+)':\\s*\\{");
  var searchFrom = 0;

  while (searchFrom < section.length) {
    final match = keyRegex.firstMatch(section.substring(searchFrom));
    if (match == null) break;

    final key = match.group(1)!;
    final braceIndex = searchFrom + match.end - 1;
    final end = _matchingBrace(section, braceIndex);
    if (end == null) break;

    if (!key.startsWith('_')) {
      results.add((key: key, value: section.substring(braceIndex, end + 1)));
    }
    searchFrom = end + 1;
  }
  return results;
}

YoutubeInnertubeClientEntry? _parseClientBlock(String id, String block) {
  if (block.contains("'REQUIRE_AUTH': True")) return null;

  final clientName = _quotedField(block, 'clientName');
  final clientVersion = _quotedField(block, 'clientVersion');
  if (clientName == null || clientVersion == null) return null;

  final host = _quotedField(block, 'INNERTUBE_HOST') ?? 'www.youtube.com';

  final client = <String, dynamic>{
    'clientName': clientName,
    'clientVersion': clientVersion,
    'hl': 'en',
    'timeZone': 'UTC',
    'utcOffsetMinutes': 0,
  };

  for (final field in [
    'userAgent',
    'deviceMake',
    'deviceModel',
    'osName',
    'osVersion',
    'platform',
    'gl',
  ]) {
    final value = _quotedField(block, field);
    if (value != null) client[field] = value;
  }
  final sdk = _intField(block, 'androidSdkVersion');
  if (sdk != null) client['androidSdkVersion'] = sdk;

  return YoutubeInnertubeClientEntry(
    id: id,
    clientName: clientName,
    clientVersion: clientVersion,
    host: host,
    payload: {
      'context': {'client': client},
    },
    apiUrl: 'https://$host/youtubei/v1/player?prettyPrint=false',
    userAgent: client['userAgent']?.toString(),
  );
}

String? _quotedField(String block, String field) {
  final match = RegExp("'$field':\\s*'((?:\\\\'|[^'])*)'").firstMatch(block);
  return match?.group(1)?.replaceAll(r"\'", "'");
}

int? _intField(String block, String field) {
  final match = RegExp("'$field':\\s*(\\d+)").firstMatch(block);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}
