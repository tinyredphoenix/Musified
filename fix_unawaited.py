import re
import os

files = [
    'lib/utilities/song_info_dialog.dart',
    'lib/widgets/now_playing/source_picker_sheet.dart',
    'lib/widgets/song_bar.dart'
]

for file in files:
    with open(file, 'r') as f:
        content = f.read()

    # Find showCupertinoModalPopup and wrap it.
    # Because it's flutter, it usually ends with `    ),` or similar.
    # We can just import unawaited and wrap it.
    
    if 'import \'dart:async\';' not in content:
        content = "import 'dart:async';\n" + content
        
    # Replace `showCupertinoModalPopup(` with `unawaited(showCupertinoModalPopup(`
    # and we just need to add a closing paren where the statement ends.
    # Let's do it manually for the exact occurrences.
    if file == 'lib/utilities/song_info_dialog.dart':
        content = content.replace('showCupertinoModalPopup(', 'unawaited(showCupertinoModalPopup(')
        content = content.replace('      ),\n    ),\n  );\n}', '      ),\n    ),\n  ));\n}')
    
    if file == 'lib/widgets/now_playing/source_picker_sheet.dart':
        content = content.replace('showAudioSourcePicker(context, widget.metadata);', 'unawaited(showAudioSourcePicker(context, widget.metadata));')
        content = content.replace('void showAudioSourcePicker(', 'Future<void> showAudioSourcePicker(')
        content = content.replace('showCupertinoModalPopup(', 'unawaited(showCupertinoModalPopup(')
        content = content.replace('      ),\n    ),\n  );\n}', '      ),\n    ),\n  ));\n}')
        
    if file == 'lib/widgets/song_bar.dart':
        content = content.replace('showCupertinoModalPopup(', 'unawaited(showCupertinoModalPopup(')
        content = content.replace('      ),\n    ),\n  );', '      ),\n    ),\n  ));')
        
    with open(file, 'w') as f:
        f.write(content)

