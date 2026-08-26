with open('lib/widgets/position_slider.dart', 'r') as f:
    content = f.read()

content = content.replace('style: TextStyle(\n              fontSize: 11,\n              fontFeatures: const [ui.FontFeature.tabularFigures()],\n              color: CupertinoDynamicColor.resolve(\n                CupertinoColors.secondaryLabel,\n                context,\n              ),\n              fontWeight: FontWeight.w500,\n            )', 'style: TextStyle(\n              fontSize: 11,\n              fontFeatures: const [ui.FontFeature.tabularFigures()],\n              color: CupertinoDynamicColor.resolve(\n                CupertinoColors.secondaryLabel,\n                context,\n              ),\n              fontWeight: FontWeight.w500,\n              decoration: TextDecoration.none,\n            )')

with open('lib/widgets/position_slider.dart', 'w') as f:
    f.write(content)
