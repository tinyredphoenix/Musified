with open('pubspec.yaml', 'r') as f:
    content = f.read()

# Replace block
block_old = """  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  flutter_cache_manager: ^3.4.1"""

block_new = """  flutter:
    sdk: flutter
  flutter_cache_manager: ^3.4.1
  flutter_localizations:
    sdk: flutter"""

content = content.replace(block_old, block_new)

# Now move crypto: ^3.0.6 right after cupertino_icons
content = content.replace('  crypto: ^3.0.6\n', '')
content = content.replace('  cupertino_icons: ^1.0.8\n', '  crypto: ^3.0.6\n  cupertino_icons: ^1.0.8\n')

with open('pubspec.yaml', 'w') as f:
    f.write(content)
