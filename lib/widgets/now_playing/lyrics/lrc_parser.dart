/// Parsed timed line from LRC / synced lyrics.
typedef LrcLine = ({Duration time, String text});

final _lrcLineRegex = RegExp(r'^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$');

/// Parse LRC timestamps into timed lines. Returns empty when input is plain text.
List<LrcLine> parseLrcLyrics(String raw) {
  final parsed = <LrcLine>[];
  for (final line in raw.split('\n')) {
    final match = _lrcLineRegex.firstMatch(line.trim());
    if (match == null) continue;

    final minutes = int.parse(match.group(1)!);
    final seconds = int.parse(match.group(2)!);
    final millisStr = match.group(3)!;
    final millis = millisStr.length == 2
        ? int.parse(millisStr) * 10
        : int.parse(millisStr);
    final text = match.group(4)!.trim();
    if (text.isEmpty) continue;

    parsed.add((
      time: Duration(
        minutes: minutes,
        seconds: seconds,
        milliseconds: millis,
      ),
      text: text,
    ));
  }
  return parsed;
}

Duration? lineEndTime(List<LrcLine> lines, int index, Duration songDuration) {
  if (index < 0 || index >= lines.length) return null;
  if (index + 1 < lines.length) return lines[index + 1].time;
  if (songDuration > Duration.zero) return songDuration;
  return lines[index].time + const Duration(seconds: 8);
}
