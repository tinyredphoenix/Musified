import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:musified/constants/app_constants.dart';
import 'package:musified/extensions/l10n.dart';
import 'package:musified/main.dart';
import 'package:musified/services/router_service.dart';
import 'package:musified/services/settings_manager.dart';
import 'package:musified/theme/app_themes.dart';
import 'package:musified/utilities/flutter_bottom_sheet.dart' show closeCurrentBottomSheet;
import 'package:musified/widgets/mini_player.dart';

class BottomNavigationPage extends StatefulWidget {
  const BottomNavigationPage({required this.child, super.key});

  final StatefulNavigationShell child;

  @override
  State<BottomNavigationPage> createState() => _BottomNavigationPageState();
}

class _BottomNavigationPageState extends State<BottomNavigationPage> {
  Stream<bool> _miniPlayerVisibilityStream() {
    return audioHandler.mediaItem
        .map((mediaItem) => mediaItem != null)
        .distinct();
  }

  bool? _previousOfflineMode;
  int? _previousShellIndex;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.child.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final currentIndex = widget.child.currentIndex;
        if (currentIndex != 0) {
          widget.child.goBranch(0);
        } else {
          SystemNavigator.pop();
        }
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([offlineMode, usePureBlackColor]),
        builder: (context, _) {
          final isOfflineMode = offlineMode.value;
          final isDark = isAppDarkMode(context);
          const activeColor = Color(0xFFFF2D55);
          final inactiveColor = isDark ? const Color(0x80FFFFFF) : const Color(0x80000000);
          final barBg = isDark ? const Color(0xB3121214) : const Color(0xB3F2F2F7);
          final border = isDark ? const Color(0x26FFFFFF) : const Color(0x1F000000);
          if (_previousOfflineMode != null && _previousOfflineMode != isOfflineMode) {
            SchedulerBinding.instance.addPostFrameCallback((_) {
              _handleOfflineModeChange(isOfflineMode);
            });
          }
          _previousOfflineMode = isOfflineMode;

          final items = _getNavigationItems(isOfflineMode);

          return CupertinoPageScaffold(
            backgroundColor: musifiedCanvas(isDark),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: audioHandlerReady,
                    builder: (context, handlerReady, _) {
                      return StreamBuilder<bool>(
                        initialData: false,
                        stream: handlerReady ? _miniPlayerVisibilityStream() : null,
                        builder: (context, snapshot) {
                          final mediaQuery = MediaQuery.of(context);
                          final isMiniPlayerVisible = snapshot.data ?? false;
                          final bottomPadding = isMiniPlayerVisible
                              ? mediaQuery.padding.bottom + miniPlayerTotalHeight
                              : mediaQuery.padding.bottom + 54;

                          return MediaQuery(
                            data: mediaQuery.copyWith(
                              padding: mediaQuery.padding.copyWith(bottom: bottomPadding),
                            ),
                            child: widget.child,
                          );
                        },
                      );
                    },
                  ),
                ),

                // Floating MiniPlayer + TabBar
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const MiniPlayer(),
                      ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                          child: Container(
                            decoration: BoxDecoration(
                              color: barBg,
                              border: Border(top: BorderSide(color: border, width: 0.5)),
                            ),
                            child: CupertinoTabBar(
                              currentIndex: _getCurrentIndex(items, isOfflineMode),
                              onTap: (index) => _onTabTapped(index, items),
                              activeColor: activeColor,
                              inactiveColor: inactiveColor,
                              backgroundColor: const Color(0x00000000),
                              iconSize: 22,
                              border: null,
                              items: items
                                  .map(
                                    (item) => BottomNavigationBarItem(
                                      icon: Icon(item.icon),
                                      activeIcon: Icon(item.selectedIcon),
                                      label: item.label,
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<_NavigationItem> _getNavigationItems(bool isOfflineMode) {
    final items = <_NavigationItem>[
      _NavigationItem(
        icon: CupertinoIcons.house,
        selectedIcon: CupertinoIcons.house_fill,
        label: context.l10n.home,
        shellIndex: 0,
      ),
    ];

    if (!isOfflineMode) {
      items.add(
        _NavigationItem(
          icon: CupertinoIcons.search,
          selectedIcon: CupertinoIcons.search,
          label: context.l10n.search,
          shellIndex: 1,
        ),
      );
    }

    items.addAll([
      _NavigationItem(
        icon: CupertinoIcons.music_albums,
        selectedIcon: CupertinoIcons.music_albums_fill,
        label: context.l10n.library,
        shellIndex: 2,
      ),
      _NavigationItem(
        icon: CupertinoIcons.gear_alt,
        selectedIcon: CupertinoIcons.gear_alt_fill,
        label: context.l10n.settings,
        shellIndex: 3,
      ),
    ]);

    return items;
  }

  void _handleOfflineModeChange(bool isOfflineMode) {
    if (!mounted) return;
    NavigationManager.refreshRouter();
    final currentRoute = GoRouterState.of(context).matchedLocation;
    if (isOfflineMode && currentRoute.startsWith('/search')) {
      widget.child.goBranch(0);
    }
  }

  void _onTabTapped(int index, List<_NavigationItem> items) {
    if (index < items.length) {
      final item = items[index];
      final isReselect = _previousShellIndex == item.shellIndex;
      HapticFeedback.selectionClick();
      closeCurrentBottomSheet();

      if (isReselect) {
        widget.child.goBranch(item.shellIndex, initialLocation: true);
      } else {
        widget.child.goBranch(item.shellIndex);
      }
      _previousShellIndex = item.shellIndex;
    }
  }

  int _getCurrentIndex(List<_NavigationItem> items, bool isOfflineMode) {
    final currentShellIndex = widget.child.currentIndex;
    if (items.isEmpty) return 0;
    final matchedIndex = items.indexWhere((item) => item.shellIndex == currentShellIndex);
    if (matchedIndex != -1) return matchedIndex;
    if (isOfflineMode && currentShellIndex == 1) return 0;
    return 0;
  }
}

class _NavigationItem {
  const _NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.shellIndex,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int shellIndex;
}
