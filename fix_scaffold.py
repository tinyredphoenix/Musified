with open('lib/screens/now_playing_page.dart', 'r') as f:
    content = f.read()

content = content.replace('import \'package:flutter/cupertino.dart\';\nimport \'package:flutter/material.dart\' show Material, MaterialType;', 'import \'package:flutter/cupertino.dart\';\nimport \'package:flutter/material.dart\';')
content = content.replace('CupertinoPageScaffold(\n      backgroundColor: bg,\n      child: Material(\n        type: MaterialType.transparency,', 'Scaffold(\n      backgroundColor: bg,\n      body: Material(\n        type: MaterialType.transparency,')
content = content.replace('CupertinoPageScaffold(\n      backgroundColor: bg,\n      child: Material(\n        type: MaterialType.transparency,\n', 'Scaffold(\n      backgroundColor: bg,\n      body: Material(\n        type: MaterialType.transparency,\n')

with open('lib/screens/now_playing_page.dart', 'w') as f:
    f.write(content)
