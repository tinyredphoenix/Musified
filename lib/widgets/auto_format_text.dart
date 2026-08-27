import 'package:flutter/cupertino.dart';
import 'package:musified/theme/musified_style.dart';

class AutoFormatText extends StatelessWidget {
  const AutoFormatText({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final spans = <TextSpan>[];

    final boldExp = RegExp(r'\*\*(.*?)\*\*');
    final matches = boldExp.allMatches(text);
    final textStyle = TextStyle(
      fontFamily: MusifiedStyle.uiFont,
      fontSize: 14,
      color: isDark ? const Color(0xCCEBEBF5) : const Color(0xCC1C1C1E),
    );

    var currentTextIndex = 0;

    for (final match in matches) {
      spans
        ..add(
          TextSpan(
            text: text
                .substring(currentTextIndex, match.start)
                .replaceAll('* ', '• '),
            style: textStyle,
          ),
        )
        ..add(
          TextSpan(
            text: match.group(1),
            style: textStyle.copyWith(fontWeight: FontWeight.bold),
          ),
        );

      currentTextIndex = match.end;
    }

    spans.add(
      TextSpan(
        text: text.substring(currentTextIndex).replaceAll('* ', '• '),
        style: textStyle,
      ),
    );

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(children: spans),
    );
  }
}
