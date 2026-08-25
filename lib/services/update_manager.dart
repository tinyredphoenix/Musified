/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Musify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Musify, including how to contribute,
 *     please visit: https://github.com/gokadzev/Musify
 */

import 'dart:io';

import 'package:material_ui/material_ui.dart';

const String checkUrl =
    'https://raw.githubusercontent.com/gokadzev/Musify/update/check.json';
const String releasesUrl =
    'https://api.github.com/repos/gokadzev/Musify/releases/latest';
const String downloadUrlKey = 'url';
const String downloadUrlArm64Key = 'arm64url';
const String downloadFilename = 'Musify.apk';

Future<void> checkAppUpdates() async {
  // No-op
}

void showUpdateCheckDialog(BuildContext context) {
  // No-op - iOS updates managed via IPA / AltStore / TestFlight
}

bool isLatestVersionHigher(String appVersion, String latestVersion) {
  final parsedAppVersion = appVersion.split('.');
  final parsedAppLatestVersion = latestVersion.split('.');
  final length = parsedAppVersion.length > parsedAppLatestVersion.length
      ? parsedAppVersion.length
      : parsedAppLatestVersion.length;
  for (var i = 0; i < length; i++) {
    final value1 = i < parsedAppVersion.length
        ? int.parse(parsedAppVersion[i])
        : 0;
    final value2 = i < parsedAppLatestVersion.length
        ? int.parse(parsedAppLatestVersion[i])
        : 0;
    if (value2 > value1) {
      return true;
    } else if (value2 < value1) {
      return false;
    }
  }

  return false;
}

Future<String> getCPUArchitecture() async {
  final info = await Process.run('uname', ['-m']);
  final cpu = info.stdout.toString().replaceAll('\n', '');

  return cpu;
}

Future<String> getDownloadUrl(Map<String, dynamic> map) async {
  final cpuArchitecture = await getCPUArchitecture();
  final url = cpuArchitecture == 'aarch64'
      ? map[downloadUrlArm64Key].toString()
      : map[downloadUrlKey].toString();

  return url;
}

/// Fetch only the announcement URL from the `check.json` file and set the
/// global `announcementURL` ValueNotifier. This does not trigger releases
/// fetching or any update dialogs/downloads and is safe to call for F‑Droid
/// builds where update prompts are not allowed.
Future<void> fetchAnnouncementOnly() async {
  // No-op
}
