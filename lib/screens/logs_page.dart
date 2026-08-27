import 'package:flutter/cupertino.dart';
import 'package:musified/main.dart' show logger;
import 'package:musified/theme/app_themes.dart';
import 'package:musified/theme/musified_style.dart';
import 'package:musified/utilities/flutter_toast.dart';

class LogsPage extends StatelessWidget {
  const LogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDarkMode(context);
    final navBarColor = isDark ? const Color(0xB3121214) : const Color(0xB3FFFFFF);

    return CupertinoPageScaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      navigationBar: CupertinoNavigationBar(
        middle: const Text(
          'Diagnostic Logs',
          style: TextStyle(
            fontFamily: MusifiedStyle.displayFont,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: navBarColor,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0x26FFFFFF) : const Color(0x1F000000),
            width: 0.5,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              onPressed: () async {
                final message = await logger.copyLogs(context);
                if (context.mounted) showToast(context, message);
              },
              child: const Icon(CupertinoIcons.doc_on_doc, size: 20),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              onPressed: logger.clearLogs,
              child: const Icon(CupertinoIcons.trash, size: 20, color: CupertinoColors.destructiveRed),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: logger,
          builder: (context, _) {
            final logs = logger.getLogs();
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              child: Text(
                logs.isEmpty ? 'No diagnostic logs recorded.' : logs,
                style: TextStyle(
                  fontFamily: 'Menlo',
                  fontSize: 12,
                  height: 1.35,
                  color: isDark ? const Color(0xCCEBEBF5) : const Color(0xCC1C1C1E),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
