import 'package:flutter/cupertino.dart';
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
          CupertinoButton(
            padding: const EdgeInsets.all(8),
            onPressed: () => setState(logger.clearLogs),
            child: const Icon(CupertinoIcons.trash),
          ),
          CupertinoButton(
            padding: const EdgeInsets.all(8),
            onPressed: () => logger.copyLogs(context),
            child: const Icon(CupertinoIcons.doc_on_doc),
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
