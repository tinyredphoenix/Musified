with open('lib/screens/now_playing_page.dart', 'r') as f:
    content = f.read()

content = content.replace(
    'Scaffold(\n      backgroundColor: bg,\n      body: Material(\n        type: MaterialType.transparency,\n',
    'CupertinoPageScaffold(\n      backgroundColor: bg,\n      child: Material(\n        type: MaterialType.transparency,\n'
)

with open('lib/screens/now_playing_page.dart', 'w') as f:
    f.write(content)
