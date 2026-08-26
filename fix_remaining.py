import re

# 1. library_page.dart - remove _buildUserPlaylistsSlivers
with open('lib/screens/library_page.dart', 'r') as f:
    lib_content = f.read()

lib_content = re.sub(
    r'  List<Widget> _buildUserPlaylistsSlivers\(\) \{.*?(?=  List<Widget> _buildCustomPlaylistsSlivers)',
    '',
    lib_content,
    flags=re.DOTALL
)
with open('lib/screens/library_page.dart', 'w') as f:
    f.write(lib_content)

# 2. data_manager.dart - cascade_invocations
with open('lib/services/data_manager.dart', 'r') as f:
    dm = f.read()
dm = dm.replace('downloadsBox.put(key, value);\n  downloadsBox.flush();', 'downloadsBox\n    ..put(key, value)\n    ..flush();')
with open('lib/services/data_manager.dart', 'w') as f:
    f.write(dm)

# 3. youtube_auth_service.dart - cascade_invocations
with open('lib/services/youtube_auth_service.dart', 'r') as f:
    ya = f.read()
ya = ya.replace('box.putAll(cookies);\n      box.flush();', 'box\n        ..putAll(cookies)\n        ..flush();')
with open('lib/services/youtube_auth_service.dart', 'w') as f:
    f.write(ya)

# 4. song_info_dialog.dart - unawaited_futures
with open('lib/utilities/song_info_dialog.dart', 'r') as f:
    si = f.read()
si = si.replace('showCupertinoModalPopup<void>(', 'unawaited(showCupertinoModalPopup<void>(')
si = si.replace('          ),', '          ),)')
with open('lib/utilities/song_info_dialog.dart', 'w') as f:
    f.write(si)

# 5. source_picker_sheet.dart - unawaited_futures
with open('lib/widgets/now_playing/source_picker_sheet.dart', 'r') as f:
    sp = f.read()
sp = sp.replace('showCupertinoModalPopup<void>(', 'unawaited(showCupertinoModalPopup<void>(')
with open('lib/widgets/now_playing/source_picker_sheet.dart', 'w') as f:
    f.write(sp)

# 6. song_bar.dart - unawaited_futures
with open('lib/widgets/song_bar.dart', 'r') as f:
    sb = f.read()
sb = sb.replace('showCupertinoModalPopup<void>(', 'unawaited(showCupertinoModalPopup<void>(')
with open('lib/widgets/song_bar.dart', 'w') as f:
    f.write(sb)

# 7. home_page.dart - unawaited_futures
with open('lib/screens/home_page.dart', 'r') as f:
    hp = f.read()
hp = hp.replace('HapticFeedback.mediumImpact();', 'unawaited(HapticFeedback.mediumImpact());')
with open('lib/screens/home_page.dart', 'w') as f:
    f.write(hp)
