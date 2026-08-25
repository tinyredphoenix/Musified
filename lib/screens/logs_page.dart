import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:musify/main.dart' show logger;

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  @override
  Widget build(BuildContext context) {
    final logs = logger.getLogs();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Logs'),
        actions: [
          IconButton(
            icon: const Icon(FluentIcons.delete_24_regular),
            tooltip: 'Clear Logs',
            onPressed: () => setState(logger.clearLogs),
          ),
          IconButton(
            icon: const Icon(FluentIcons.copy_24_regular),
            tooltip: 'Copy All',
            onPressed: () => logger.copyLogs(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(
          logs.isEmpty ? 'No logs yet.' : logs,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
