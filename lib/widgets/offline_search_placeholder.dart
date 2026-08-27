import 'package:flutter/cupertino.dart';
import 'package:musified/theme/musified_style.dart';

class OfflineSearchPlaceholder extends StatelessWidget {
  const OfflineSearchPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final navBarColor = isDark ? const Color(0xB3121214) : const Color(0xB3FFFFFF);

    return CupertinoPageScaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      navigationBar: CupertinoNavigationBar(
        middle: const Text(
          'Offline Mode',
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
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.cloud_download,
              size: 56,
              color: CupertinoColors.systemGrey,
            ),
            SizedBox(height: 16),
            Text(
              'Search unavailable in offline mode',
              style: TextStyle(
                fontFamily: MusifiedStyle.uiFont,
                fontSize: 15,
                color: CupertinoColors.systemGrey,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
