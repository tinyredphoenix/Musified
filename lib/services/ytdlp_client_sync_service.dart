import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:musified/services/data_manager.dart';
import 'package:musified/services/logger_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

const _ytdlpBasePyUrl =
    'https://raw.githubusercontent.com/yt-dlp/yt-dlp/master/yt_dlp/extractor/youtube/_base.py';

/// Musified uses exactly one InnerTube client for stream resolution: visionos.
/// There is no picker and no automatic fallback to other clients.

const _clientEntryKey = 'youtubeVisionOsClient';
const _syncAtKey = 'youtubeVisionOsSyncAt';
const _syncCommitKey = 'youtubeVisionOsSyncCommit';

/// Synced or built-in visionos InnerTube definition.
class VisionOsClientConfig {
  const VisionOsClientConfig({
    required this.clientName,
    required this.clientVersion,
    required this.host,
    required this.payload,
    required this.apiUrl,
    this.userAgent,
    this.deviceModel,
    this.osVersion,
    this.isBuiltin = false,
  });

  final String clientName;
  final String clientVersion;
  final String host;
  final Map<String, dynamic> payload;
  final String apiUrl;
  final String? userAgent;
  final String? deviceModel;
  final String? osVersion;
  final bool isBuiltin;

  String get displayLabel => '$clientName $clientVersion'.trim();

  bool get isUsable =>
      clientName == 'VISIONOS' &&
      clientVersion.isNotEmpty &&
      apiUrl.isNotEmpty &&
      payload['context'] is Map;

  YoutubeApiClient toYoutubeApiClient() =>
      YoutubeApiClient(Map<String, dynamic>.from(payload), apiUrl);

  Map<String, dynamic> toJson() => {
        'clientName': clientName,
        'clientVersion': clientVersion,
        'host': host,
        'payload': payload,
        'apiUrl': apiUrl,
        'userAgent': userAgent,
        'deviceModel': deviceModel,
        'osVersion': osVersion,
        'isBuiltin': isBuiltin,
      };

  factory VisionOsClientConfig.fromJson(Map<String, dynamic> json) {
    return VisionOsClientConfig(
      clientName: json['clientName']?.toString() ?? '',
      clientVersion: json['clientVersion']?.toString() ?? '',
      host: json['host']?.toString() ?? 'www.youtube.com',
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
      apiUrl: json['apiUrl']?.toString() ?? '',
      userAgent: json['userAgent']?.toString(),
      deviceModel: json['deviceModel']?.toString(),
      osVersion: json['osVersion']?.toString(),
      isBuiltin: json['isBuiltin'] == true,
    );
  }

  Map<String, Object?> logFields() => {
        'client': displayLabel,
        'host': host,
        'deviceModel': deviceModel ?? '-',
        'osVersion': osVersion ?? '-',
        'userAgent': userAgent ?? '-',
        'builtin': isBuiltin,
      };
}

class YtdlpClientSyncService {
  YtdlpClientSyncService._();
  static final YtdlpClientSyncService instance = YtdlpClientSyncService._();

  final ValueNotifier<DateTime?> lastSyncedAt = ValueNotifier<DateTime?>(null);
  final ValueNotifier<String?> lastSyncCommit = ValueNotifier<String?>(null);
  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  final ValueNotifier<bool> syncing = ValueNotifier<bool>(false);

  VisionOsClientConfig _active = builtinVisionOsConfig();
  bool _loaded = false;

  VisionOsClientConfig get activeConfig => _active;
  String get clientLabel => _active.displayLabel;

  /// The only InnerTube client used for YouTube stream manifests and downloads.
  YoutubeApiClient streamClient() => _active.toYoutubeApiClient();

  List<YoutubeApiClient> streamClients() => [streamClient()];

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;

    logger.log(
      'YouTube visionos client boot',
      data: _active.logFields(),
    );

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
          final config = VisionOsClientConfig.fromJson(
            Map<String, dynamic>.from(decoded),
          );
          if (config.isUsable) {
            _active = config;
            revision.value++;
            logger.log(
              'Restored synced visionos client from settings',
              data: config.logFields(),
            );
          } else {
            logger.log(
              'Stored visionos client unusable — using built-in',
              data: config.logFields(),
            );
          }
        }
      } catch (e, st) {
        logger.log(
          'Failed to parse stored visionos client',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  /// User-initiated: pull yt-dlp's current visionos block and persist it.
  Future<YtdlpClientSyncResult> syncFromYtdlp() async {
    if (syncing.value) {
      return YtdlpClientSyncResult.failed('Sync already running');
    }
    syncing.value = true;
    logger.log(
      'YouTube visionos sync started',
      data: {
        'current': _active.displayLabel,
        'builtin': _active.isBuiltin,
        'url': _ytdlpBasePyUrl,
      },
    );

    try {
      final response = await http
          .get(Uri.parse(_ytdlpBasePyUrl))
          .timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) {
        logger.log(
          'YouTube visionos sync failed — yt-dlp HTTP error',
          data: {'status': response.statusCode},
        );
        return YtdlpClientSyncResult.failed(
          'yt-dlp download failed (HTTP ${response.statusCode})',
        );
      }

      final parsed = parseVisionOsFromYtdlp(response.body);
      if (parsed == null || !parsed.isUsable) {
        logger.log('YouTube visionos sync failed — parse/unusable definition');
        return YtdlpClientSyncResult.failed(
          'Could not read visionos definition from yt-dlp',
        );
      }

      final previous = _active.displayLabel;
      _active = parsed;
      revision.value++;

      final syncedAt = DateTime.now();
      lastSyncedAt.value = syncedAt;

      await addOrUpdateData('settings', _clientEntryKey, jsonEncode(parsed.toJson()));
      await addOrUpdateData('settings', _syncAtKey, syncedAt.toIso8601String());

      final commit = await _latestCommitSha();
      if (commit != null) {
        lastSyncCommit.value = commit;
        await addOrUpdateData('settings', _syncCommitKey, commit);
      }

      logger.log(
        'YouTube visionos sync OK',
        data: {
          'previous': previous,
          'new': parsed.displayLabel,
          'commit': commit ?? '-',
          ...parsed.logFields(),
        },
      );

      return YtdlpClientSyncResult.success(
        label: parsed.displayLabel,
        commit: commit,
      );
    } catch (e, st) {
      logger.log(
        'YouTube visionos sync error',
        error: e,
        stackTrace: st,
      );
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

VisionOsClientConfig builtinVisionOsConfig() {
  const client = YoutubeApiClient.visionOs;
  final payload = Map<String, dynamic>.from(client.payload);
  final clientMap = payload['context']?['client'] as Map?;
  return VisionOsClientConfig(
    clientName: clientMap?['clientName']?.toString() ?? 'VISIONOS',
    clientVersion: clientMap?['clientVersion']?.toString() ?? '',
    host: Uri.tryParse(client.apiUrl)?.host ?? 'www.youtube.com',
    payload: payload,
    apiUrl: client.apiUrl,
    userAgent: clientMap?['userAgent']?.toString(),
    deviceModel: clientMap?['deviceModel']?.toString(),
    osVersion: clientMap?['osVersion']?.toString(),
    isBuiltin: true,
  );
}

/// Reads only the `visionos` entry from yt-dlp's INNERTUBE_CLIENTS table.
VisionOsClientConfig? parseVisionOsFromYtdlp(String source) {
  const marker = "    'visionos': {";
  final start = source.indexOf(marker);
  if (start < 0) {
    logger.log('yt-dlp parse: visionos block not found in _base.py');
    return null;
  }

  final braceIndex = start + marker.length - 1;
  final end = _matchingBrace(source, braceIndex);
  if (end == null) {
    logger.log('yt-dlp parse: visionos block brace mismatch');
    return null;
  }

  final block = source.substring(braceIndex, end + 1);
  return _parseVisionOsBlock(block);
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

VisionOsClientConfig? _parseVisionOsBlock(String block) {
  final clientName = _quotedField(block, 'clientName');
  final clientVersion = _quotedField(block, 'clientVersion');
  if (clientName == null ||
      clientVersion == null ||
      clientName != 'VISIONOS') {
    return null;
  }

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

  return VisionOsClientConfig(
    clientName: clientName,
    clientVersion: clientVersion,
    host: host,
    payload: {'context': {'client': client}},
    apiUrl: 'https://$host/youtubei/v1/player?prettyPrint=false',
    userAgent: client['userAgent']?.toString(),
    deviceModel: client['deviceModel']?.toString(),
    osVersion: client['osVersion']?.toString(),
  );
}

String? _quotedField(String block, String field) {
  final match = RegExp("'$field':\\s*'((?:\\\\'|[^'])*)'").firstMatch(block);
  return match?.group(1)?.replaceAll(r"\'", "'");
}
