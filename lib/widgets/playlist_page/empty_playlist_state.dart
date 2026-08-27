import 'package:flutter/cupertino.dart';
import 'package:musified/theme/musified_style.dart';

class EmptyPlaylistState extends StatelessWidget {
  const EmptyPlaylistState({
    super.key,
    this.icon = CupertinoIcons.list_bullet,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 56,
                color: CupertinoColors.systemGrey,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: MusifiedStyle.uiFont,
                  color: CupertinoColors.systemGrey,
                  fontSize: 15,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
