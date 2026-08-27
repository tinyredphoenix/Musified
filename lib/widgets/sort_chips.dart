import 'package:flutter/cupertino.dart';
import 'package:musified/theme/app_themes.dart';
import 'package:musified/theme/musified_style.dart';

typedef SortTypeToStringConverter<T> = String Function(T type);
typedef OnSortTypeSelected<T> = void Function(T type);

class SortChips<T extends Enum> extends StatelessWidget {
  const SortChips({
    required this.currentSortType,
    required this.sortTypes,
    required this.sortTypeToString,
    required this.onSelected,
    super.key,
  });

  final T currentSortType;
  final List<T> sortTypes;
  final SortTypeToStringConverter<T> sortTypeToString;
  final OnSortTypeSelected<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDarkMode(context);
    final activeBg = const Color(0xFFFF2D55);
    final inactiveBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: sortTypes.map((type) {
          final isSelected = currentSortType == type;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                if (currentSortType == type) return;
                onSelected(type);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? activeBg : inactiveBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  sortTypeToString(type),
                  style: TextStyle(
                    fontFamily: MusifiedStyle.uiFont,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                    color: isSelected ? CupertinoColors.white : (isDark ? CupertinoColors.white : CupertinoColors.black),
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
