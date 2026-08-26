#!/bin/bash
sed -i '' 's/if (isOffline) return CupertinoIcons.arrow_down_circle_fill;/if (extras['\''resolvedSource'\''] == '\''jiosaavn'\'') {/g' lib/widgets/now_playing/source_picker_sheet.dart
