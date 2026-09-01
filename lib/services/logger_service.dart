import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musified/extensions/l10n.dart';

/// App-wide log sink (settings → copy logs). Defined here so services can log
/// without importing [main.dart].
final logger = Logger();

class Logger extends ChangeNotifier {
  static const int _maxLogChars = 80000;
  static const int _maxLogLines = 400;

  final List<String> _logLines = [];
  int _logCount = 0;

  void log(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final errorMessage = error != null ? ' $error' : '';
    final dataMessage = data == null || data.isEmpty
        ? ''
        : ' ${data.entries.map((e) => '${e.key}=${e.value}').join(' ')}';
    final stackTraceMessage =
        stackTrace != null ? '\n$stackTrace' : '';
    final logMessage =
        '[$timestamp] $message$dataMessage$errorMessage$stackTraceMessage';

    debugPrint(logMessage);
    _logLines.add(logMessage);
    _logCount++;
    while (_logLines.length > _maxLogLines) {
      _logLines.removeAt(0);
    }
    notifyListeners();
  }

  Future<String> copyLogs(BuildContext context) async {
    try {
      final logs = getLogs();
      if (logs.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: logs));
        return '${context.l10n.copyLogsSuccess}.';
      } else {
        return '${context.l10n.copyLogsNoLogs}.';
      }
    } catch (e, stackTrace) {
      log('Error copying logs', error: e, stackTrace: stackTrace);
      return 'Error: $e';
    }
  }

  int getLogCount() => _logCount;

  String getLogs() {
    final joined = _logLines.join('\n');
    if (joined.length <= _maxLogChars) return joined;
    return joined.substring(joined.length - _maxLogChars);
  }

  void clearLogs() {
    _logLines.clear();
    _logCount = 0;
    notifyListeners();
  }

  /// Wipes the in-memory log buffer. Does not touch Hive, stream cache, or
  /// downloaded files. Called once at cold start so prior sessions cannot
  /// accumulate in RAM.
  void resetForNewSession() => clearLogs();
}
