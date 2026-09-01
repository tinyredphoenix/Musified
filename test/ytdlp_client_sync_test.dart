import 'package:flutter_test/flutter_test.dart';
import 'package:musified/services/ytdlp_client_sync_service.dart';

void main() {
  test('parseInnertubeClientsFromYtdlp extracts visionos definition', () {
    const snippet = '''
INNERTUBE_CLIENTS = {
    'android': {
        'INNERTUBE_CONTEXT': {
            'client': {
                'clientName': 'ANDROID',
                'clientVersion': '21.26.364',
                'userAgent': 'com.google.android.youtube/21.26.364 gzip',
            },
        },
    },
    'visionos': {
        'INNERTUBE_CONTEXT': {
            'client': {
                'clientName': 'VISIONOS',
                'clientVersion': '1.02',
                'deviceMake': 'Apple',
                'deviceModel': 'RealityDevice14,1',
                'osName': 'visionOS',
                'osVersion': '1.0.21N301',
            },
        },
    },
}
''';

    final parsed = parseInnertubeClientsFromYtdlp(snippet);

    expect(parsed.map((e) => e.id), containsAll(['android', 'visionos']));
    final visionOs = parsed.firstWhere((e) => e.id == 'visionos');
    expect(visionOs.clientName, 'VISIONOS');
    expect(visionOs.clientVersion, '1.02');
    expect(visionOs.isUsable, isTrue);
    expect(visionOs.apiUrl, contains('www.youtube.com/youtubei/v1/player'));
  });

  test('built-in visionos entry is usable before any sync', () {
    final entry = builtinVisionOsEntry();
    expect(entry.isUsable, isTrue);
    expect(entry.clientName, 'VISIONOS');
    expect(entry.isBuiltin, isTrue);
  });
}
