import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:musified/main.dart';
import 'package:musified/services/settings_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('musify_test_');
    Hive.init(tempDir.path);
    for (final box in ['settings', 'user', 'favorite_stations', 'favorite_playlists', 'search_history', 'cache', 'saavn_match_cache']) {
      await Hive.openBox(box);
    }
    reloadSettingsFromStorage();
  });

  testWidgets('App boots without null check errors or exceptions', (tester) async {
    await tester.pumpWidget(const Musify());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(Musify), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
