import 'package:flutter_test/flutter_test.dart';
import 'package:musified/services/ytdlp_client_sync_service.dart';

void main() {
  test('parseInnertubeClientsFromYtdlp extracts android_vr and android', () {
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
 'android_vr': {
 'INNERTUBE_CONTEXT': {
 'client': {
 'clientName': 'ANDROID_VR',
 'clientVersion': '1.65.10',
 'userAgent': 'com.google.android.apps.youtube.vr.oculus/1.65.10 gzip',
 },
 },
 },
}
''';
    final parsed = parseInnertubeClientsFromYtdlp(snippet);
    expect(parsed.length, 2);
    expect(parsed.any((e) => e.id == 'android_vr'), isTrue);
    expect(parsed.any((e) => e.id == 'android'), isTrue);
    final vr = parsed.firstWhere((e) => e.id == 'android_vr');
    expect(vr.isRecommended, isTrue);
    expect(vr.clientName, 'ANDROID_VR');
  });
}
