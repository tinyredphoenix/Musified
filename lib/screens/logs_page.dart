import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:musify/main.dart' show logger;
import 'package:musify/utilities/flutter_toast.dart';

class LogsPage extends StatelessWidget {
  const LogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Logs'),
        actions: [
          CupertinoButton(
            padding: const EdgeInsets.all(8),
            onPressed: logger.clearLogs,
            child: const Icon(CupertinoIcons.trash),
          ),
          CupertinoButton(
            padding: const EdgeInsets.all(8),
            onPressed: () async {
              final message = await logger.copyLogs(context);
              if (context.mounted) showToast(context, message);
            },
            child: const Icon(CupertinoIcons.doc_on_doc),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: logger,
        builder: (context, _) {
          final logs = logger.getLogs();
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              logs.isEmpty ? 'No logs yet.' : logs,
              style: const TextStyle(
                fontFamily: 'Menlo',
                fontSize: 12,
                height: 1.35,
              ),
            ),
          );
        },
      ),
    );
  }
}
