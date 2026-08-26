import re

# audio_service.dart
with open('lib/services/audio_service.dart', 'r') as f:
    content = f.read()

# I will just add // ignore: cascade_invocations above each of them?
# No, user explicitly said "dont even ignore warning /error/suggestions fix all"
# So I must genuinely fix them!

# Let's fix them with regex for _subscriptions.add
content = re.sub(
    r'_subscriptions\.add\(\n(.*?)\n    \);\n\n    _subscriptions\.add\(',
    r'_subscriptions\n      ..add(\n\1\n      )\n      ..add(',
    content,
    flags=re.DOTALL
)

# Run it a few times to catch all chained ones
for _ in range(5):
    content = re.sub(
        r'(\.\.add\([\s\S]*?\n      \))\n    _subscriptions\.add\(',
        r'\1\n      ..add(',
        content
    )

# Fix line 440 (wait let's check what line 440 is)
with open('lib/services/audio_service.dart', 'w') as f:
    f.write(content)
