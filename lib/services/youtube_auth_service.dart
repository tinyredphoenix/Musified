// ignore_for_file: cascade_invocations

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:musified/main.dart' show logger;

class YouTubeAuthService {

  factory YouTubeAuthService() => _instance;

  YouTubeAuthService._internal();
  static final YouTubeAuthService _instance = YouTubeAuthService._internal();

  final isSignedIn = ValueNotifier<bool>(false);
  final userName = ValueNotifier<String?>(null);
  final userEmail = ValueNotifier<String?>(null);
  final userAvatarUrl = ValueNotifier<String?>(null);

  Map<String, String> getAuthHeaders() {
    try {
      final box = Hive.box('youtube_auth');
      final cookies = box.get('cookies');
      if (cookies == null || cookies is! Map) return {};
      
      final typedCookies = Map<String, String>.from(cookies);
      
      final cookieString = typedCookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
      
      final sapisid = typedCookies['SAPISID'] ?? typedCookies['__Secure-3PAPISID'] ?? '';
      if (sapisid.isEmpty) return {};

      const origin = 'https://music.youtube.com';
      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final hashStr = '$timestamp $sapisid $origin';
      
      final bytes = utf8.encode(hashStr);
      final digest = sha1.convert(bytes);
      
      final authHeader = 'SAPISIDHASH ${timestamp}_$digest';
      
      return {
        'Cookie': cookieString,
        'Authorization': authHeader,
        'Origin': origin,
      };
    } catch (e) {
      logger.log('Error generating auth headers: $e');
      return {};
    }
  }

  void saveCookies(Map<String, String> cookies) {
    try {
      if (!Hive.isBoxOpen('youtube_auth')) {
        logger.log('youtube_auth box is not open');
        return;
      }
      
      final hasRequired = cookies.containsKey('SAPISID') || cookies.containsKey('__Secure-3PAPISID');
      if (!hasRequired) {
        logger.log('Missing SAPISID or __Secure-3PAPISID cookie');
        return;
      }

      final box = Hive.box('youtube_auth');
      box.put('cookies', cookies);
      isSignedIn.value = true;
      fetchUserProfile();
    } catch (e) {
      logger.log('Error saving cookies: $e');
    }
  }

  void restoreSession() {
    try {
      if (!Hive.isBoxOpen('youtube_auth')) {
        return;
      }
      
      final box = Hive.box('youtube_auth');
      final cookies = box.get('cookies');
      
      if (cookies != null && cookies is Map) {
        final typedCookies = Map<String, String>.from(cookies);
        if (typedCookies.containsKey('SAPISID') || typedCookies.containsKey('__Secure-3PAPISID')) {
          isSignedIn.value = true;
          fetchUserProfile();
          return;
        }
      }
      
      isSignedIn.value = false;
    } catch (e) {
      logger.log('Error restoring session: $e');
      isSignedIn.value = false;
    }
  }

  void signOut() {
    try {
      if (Hive.isBoxOpen('youtube_auth')) {
        Hive.box('youtube_auth').clear();
      }
      isSignedIn.value = false;
      userName.value = null;
      userEmail.value = null;
      userAvatarUrl.value = null;
    } catch (e) {
      logger.log('Error signing out: $e');
    }
  }

  Future<void> fetchUserProfile() async {
    if (!isSignedIn.value) return;

    try {
      final headers = getAuthHeaders();
      if (headers.isEmpty) return;
      
      headers['Content-Type'] = 'application/json';
      
      final body = jsonEncode({
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20230508.01.00',
          }
        }
      });
      
      final response = await http.post(
        Uri.parse('https://music.youtube.com/youtubei/v1/account/account_menu'),
        headers: headers,
        body: body,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        final actions = data['actions'] as List?;
        if (actions != null && actions.isNotEmpty) {
          final firstAction = actions.first as Map?;
          final openPopupAction = firstAction?['openPopupAction'] as Map?;
          final popup = openPopupAction?['popup'] as Map?;
          final multiPageMenuRenderer = popup?['multiPageMenuRenderer'] as Map?;
          final header = multiPageMenuRenderer?['header'] as Map?;
          final activeAccountHeaderRenderer = header?['activeAccountHeaderRenderer'] as Map?;
          
          if (activeAccountHeaderRenderer != null) {
            final accountName = activeAccountHeaderRenderer['accountName'] as Map?;
            final simpleText = accountName?['simpleText'] as String?;
            if (simpleText != null) {
              userName.value = simpleText;
            }
            
            final emailMap = activeAccountHeaderRenderer['email'] as Map?;
            final emailText = emailMap?['simpleText'] as String?;
            if (emailText != null) {
              userEmail.value = emailText;
            }
            
            final accountPhoto = activeAccountHeaderRenderer['accountPhoto'] as Map?;
            final thumbnails = accountPhoto?['thumbnails'] as List?;
            if (thumbnails != null && thumbnails.isNotEmpty) {
              final lastThumbnail = thumbnails.last as Map?;
              final url = lastThumbnail?['url'] as String?;
              if (url != null) {
                userAvatarUrl.value = url;
              }
            }
          }
        }
      } else {
        logger.log('Failed to fetch profile: ${response.statusCode}');
      }
    } catch (e) {
      logger.log('Error fetching profile: $e');
    }
  }
}
