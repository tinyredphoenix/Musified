import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Writes every log line to a file and mirrors it to `device-logs/` on GitHub.
///
/// The phone cannot see the git checkout, so the repo folder is filled through
/// the Contents API. Pass the token at build time:
/// `--dart-define=GITHUB_LOG_TOKEN=...`
/// No token: the file is still kept on the device, and nothing is uploaded.
class DeviceLogUpload {
  DeviceLogUpload._();

  static const _token = String.fromEnvironment('GITHUB_LOG_TOKEN');
  static const _repo = 'tinyredphoenix/Musified';
  static const _uploadGap = Duration(seconds: 15);

  static final String _session = DateTime.now()
      .toUtc()
      .toIso8601String()
      .replaceAll(':', '')
      .replaceAll('-', '')
      .split('.')
      .first;

  static File? _file;
  static String? _remoteSha;
  static bool _uploading = false;
  static bool _dirty = false;
  static Timer? _timer;

  static String get remotePath => 'device-logs/$_session.log';

  static void capture(String line, {bool urgent = false}) {
    unawaited(_capture(line, urgent: urgent));
  }

  static Future<void> _capture(String line, {required bool urgent}) async {
    try {
      final file = _file ??= await _open();
      await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
    } catch (e) {
      debugPrint('device log file write failed: $e');
      return;
    }
    _dirty = true;
    if (_token.isEmpty) return;
    if (urgent) {
      await _upload();
      return;
    }
    _timer ??= Timer(_uploadGap, () {
      _timer = null;
      unawaited(_upload());
    });
  }

  static Future<File> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/logs');
    if (!folder.existsSync()) {
      folder.createSync(recursive: true);
    }
    return File('${folder.path}/$_session.log');
  }

  static Future<void> _upload() async {
    if (_token.isEmpty || _uploading || !_dirty) return;
    final file = _file;
    if (file == null || !file.existsSync()) return;
    _uploading = true;
    try {
      final text = await file.readAsString();
      final body = <String, Object?>{
        'message': 'device log $_session',
        'content': base64Encode(utf8.encode(text)),
        if (_remoteSha != null) 'sha': _remoteSha,
      };
      final uri = Uri.parse(
        'https://api.github.com/repos/$_repo/contents/$remotePath',
      );
      var response = await http.put(
        uri,
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'musified-device-log',
        },
        body: jsonEncode(body),
      );
      if (response.statusCode == 409 || response.statusCode == 422) {
        final current = await http.get(
          uri,
          headers: {
            'Authorization': 'Bearer $_token',
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'musified-device-log',
          },
        );
        if (current.statusCode == 200) {
          final sha = (jsonDecode(current.body) as Map)['sha']?.toString();
          if (sha != null) {
            body['sha'] = sha;
            response = await http.put(
              uri,
              headers: {
                'Authorization': 'Bearer $_token',
                'Accept': 'application/vnd.github+json',
                'User-Agent': 'musified-device-log',
              },
              body: jsonEncode(body),
            );
          }
        }
      }
      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          final content = decoded['content'];
          if (content is Map) {
            _remoteSha = content['sha']?.toString();
          }
        }
        _dirty = false;
        debugPrint('device log uploaded to $remotePath');
      } else {
        debugPrint(
          'device log upload failed ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('device log upload error: $e');
    } finally {
      _uploading = false;
    }
  }
}
