import re

files = [
    'lib/screens/now_playing_page.dart',
    'lib/widgets/now_playing/synced_lyrics_view.dart',
    'lib/widgets/now_playing/source_picker_sheet.dart'
]

for file in files:
    with open(file, 'r') as f:
        content = f.read()
    
    # Simple regex to remove the Material wrap if it's formatted a specific way
    # Or I can just replace `child: Material(\n        type: MaterialType.transparency,\n        child: ` with `child: `
    content = content.replace('      child: Material(\n        type: MaterialType.transparency,\n        child: DefaultTextStyle(', '      child: DefaultTextStyle(')
    content = content.replace('    return Material(\n      type: MaterialType.transparency,\n      child: DefaultTextStyle(', '    return DefaultTextStyle(')
    content = content.replace('      return Material(\n        type: MaterialType.transparency,\n        child: SingleChildScrollView(', '      return SingleChildScrollView(')
    content = content.replace('        child: Material(\n          type: MaterialType.transparency,\n          child: DefaultTextStyle(', '        child: DefaultTextStyle(')
    content = content.replace('import \'package:flutter/material.dart\';', '')
    
    with open(file, 'w') as f:
        f.write(content)
