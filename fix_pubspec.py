with open('pubspec.yaml', 'r') as f:
    lines = f.readlines()

# Very manual fix because pubspec yaml formatting can be tricky
# Just find crypto and flutter_cache_manager and sort them properly.
# Actually wait! The best way is to use `dart pub get`? No, flutter format doesn't sort pubspec.
# Let's just fix it by writing the sorted block.

deps_start = lines.index('dependencies:\n') + 1
deps_end = lines.index('\n', deps_start)

deps_lines = lines[deps_start:deps_end]
# Extract just the single line dependencies and leave multi-line flutter stuff untouched.
# Actually I'll just write it exactly sorted!
sorted_deps = """  app_links: ^7.2.1
  audio_service: ^0.18.19
  audio_session: ^0.2.4
  cached_network_image: ^3.4.1
  crypto: ^3.0.6
  cupertino_icons: ^1.0.8
  dart_des: ^1.0.2
  file_picker: ^12.0.0
  flutter:
    sdk: flutter
  flutter_cache_manager: ^3.4.1
  flutter_localizations:
    sdk: flutter
  go_router: ^17.5.0
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  html: ^0.15.6
  http: ^1.6.0
  intl: ^0.20.2
  just_audio: ^0.10.6
  material_ui: ^1.0.1
  path_provider: ^2.1.6
  rxdart: ^0.28.0
  share_plus: ^13.3.0
  url_launcher: ^6.3.2
  webview_flutter: ^4.12.0
"""

lines = lines[:deps_start] + [sorted_deps] + lines[deps_end:]

with open('pubspec.yaml', 'w') as f:
    f.writelines(lines)
