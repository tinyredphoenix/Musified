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
 *     along with this program.  If not, see <https://github.com/gokadzev/Musify>.
 */

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';

class Logger extends ChangeNotifier {
  static const int _maxLogChars = 80000;
  String _logs = '';
  int _logCount = 0;

  void log(String message, {Object? error, StackTrace? stackTrace}) {
    final timestamp = DateTime.now().toIso8601String();
    final errorMessage = error != null ? ' $error' : '';
    final stackTraceMessage =
        stackTrace != null ? '\n$stackTrace' : '';
    final logMessage =
        '[$timestamp] $message$errorMessage$stackTraceMessage';

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
