with open('lib/main.dart', 'r') as f:
    content = f.read()

content = content.replace(
    'child: child ?? const SizedBox.shrink(),',
    'child: DefaultTextStyle(\n              style: const TextStyle(decoration: TextDecoration.none),\n              child: child ?? const SizedBox.shrink(),\n            ),'
)

with open('lib/main.dart', 'w') as f:
    f.write(content)
