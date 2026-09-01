import 'package:flutter_test/flutter_test.dart';
import 'package:musified/services/ytdlp_client_sync_service.dart';

void main() {
  test('parseVisionOsFromYtdlp extracts visionos definition', () {
    const snippet = '''
INNERTUBE_CLIENTS = {
    'android': {
        'INNERTUBE_CONTEXT': {
            'client': {
                'clientName': 'ANDROID',
                'clientVersion': '21.26.364',
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

    final parsed = parseVisionOsFromYtdlp(snippet);

    expect(parsed, isNotNull);
    expect(parsed!.clientName, 'VISIONOS');
    expect(parsed.clientVersion, '1.02');
    expect(parsed.isUsable, isTrue);
    expect(parsed.apiUrl, contains('www.youtube.com/youtubei/v1/player'));
  });

  test('built-in visionos config is usable before any sync', () {
    final config = builtinVisionOsConfig();
    expect(config.isUsable, isTrue);
    expect(config.clientName, 'VISIONOS');
    expect(config.isBuiltin, isTrue);
  });
}
