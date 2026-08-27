import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musified/extensions/l10n.dart';

class Logger extends ChangeNotifier {
  static const int _maxLogChars = 200000;
  String _logs = '';
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
    _logs += '$logMessage\n';
    _logCount++;
    if (_logs.length > _maxLogChars) {
      _logs = _logs.substring(_logs.length - (_maxLogChars ~/ 2));
    }
    notifyListeners();
  }

  Future<String> copyLogs(BuildContext context) async {
    try {
      if (_logs.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: _logs));
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

  String getLogs() => _logs;

  void clearLogs() {
    _logs = '';
    _logCount = 0;
    notifyListeners();
  }
}
