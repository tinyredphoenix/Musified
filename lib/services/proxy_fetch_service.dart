import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:musified/main.dart';

/// Fetches free proxy lists from public sources.
/// [ProxyManager] supplies blocklist checks and candidate registration.
class ProxyFetchService {
  static final RegExp spysRegex = RegExp(
    r'(?<ip>\d+\.\d+\.\d+\.\d+):(?<port>\d+)\s(?<country>[A-Z]{2})-(?<anon>[HNA!]{1,2})(?:\s|-)(?<ssl>[\sS!]*)',
  );
  static final RegExp openProxyRegex = RegExp(
    r'(.)\s(?<ip>\d+\.\d+\.\d+\.\d+):(?<port>\d+)\s(?:(?<responsetime>\d+)(?:ms))\s(?<country>[A-Z]{2})\s(?<isp>.+)$',
  );

  Future<void> fetchAll({
    required void Function({
      required String source,
      required String address,
      required String country,
      bool? isSsl,
    }) onCandidate,
    required bool Function(String address) isBlocked,
  }) async {
    await Future.wait([
      _fetchSpysMe(onCandidate: onCandidate, isBlocked: isBlocked),
      _fetchProxyScrape(onCandidate: onCandidate, isBlocked: isBlocked),
      _fetchOpenProxyList(onCandidate: onCandidate, isBlocked: isBlocked),
      _fetchGeonode(onCandidate: onCandidate, isBlocked: isBlocked),
    ]);
  }

  void _logFetchError(String source, dynamic error) {
    logger.log(
      'ProxyFetchService: error from $source: $error',
      error: error,
    );
  }

  Future<void> _fetchSpysMe({
    required void Function({
      required String source,
      required String address,
      required String country,
      bool? isSsl,
    }) onCandidate,
    required bool Function(String address) isBlocked,
  }) async {
    try {
      const url = 'https://spys.me/proxy.txt';
      final response = await http
          .get(Uri.parse(url))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => http.Response('', 408),
          );
      if (response.statusCode != 200) {
        _logFetchError('spys.me', 'Status code: ${response.statusCode}');
        return;
      }
      if (response.body.isEmpty) return;

      for (final line in response.body.split('\n')) {
        if (line.trim().isEmpty || line.startsWith(';')) continue;
        final match = spysRegex.firstMatch(line);
        if (match == null) continue;
        final country = match.namedGroup('country') ?? '';
        final address = '${match.namedGroup('ip')}:${match.namedGroup('port')}';
        if (country.isEmpty || isBlocked(address)) continue;
        onCandidate(
          source: 'spys.me',
          address: address,
          country: country,
          isSsl: (match.namedGroup('ssl') ?? '').trim().isNotEmpty,
        );
      }
    } catch (e) {
      _logFetchError('spys.me', e);
    }
  }

  Future<void> _fetchProxyScrape({
    required void Function({
      required String source,
      required String address,
      required String country,
      bool? isSsl,
    }) onCandidate,
    required bool Function(String address) isBlocked,
  }) async {
    try {
      const url =
          'https://api.proxyscrape.com/v4/free-proxy-list/get?request=display_proxies&proxy_format=protocolipport&format=json&protocol=http&ssl=yes';
      final response = await http
          .get(Uri.parse(url))
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => http.Response('', 408),
          );
      if (response.statusCode != 200) return;

      Map<String, dynamic> result;
      try {
        result = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        _logFetchError('proxyscrape.com', e);
        return;
      }
      if (result['proxies'] is! List) return;

      for (final proxyData in (result['proxies'] as List)) {
        if (proxyData is! Map) continue;
        if (proxyData['ip_data'] is! Map ||
            !(proxyData['alive'] ?? false) ||
            proxyData['ip_data']['countryCode'] == null) {
          continue;
        }
        final country = proxyData['ip_data']['countryCode'].toString();
        final address = '${proxyData['ip']}:${proxyData['port']}';
        if (isBlocked(address)) continue;
        onCandidate(
          source: 'proxyscrape.com',
          address: address,
          country: country,
          isSsl: true,
        );
      }
    } catch (e) {
      _logFetchError('proxyscrape.com', e);
    }
  }

  Future<void> _fetchOpenProxyList({
    required void Function({
      required String source,
      required String address,
      required String country,
      bool? isSsl,
    }) onCandidate,
    required bool Function(String address) isBlocked,
  }) async {
    try {
      const url =
          'https://raw.githubusercontent.com/roosterkid/openproxylist/main/HTTPS.txt';
      final response = await http
          .get(Uri.parse(url))
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => http.Response('', 408),
          );
      if (response.statusCode != 200) return;

      for (final line in response.body.split('\n')) {
        final match = openProxyRegex.firstMatch(line);
        if (match == null) continue;
        final country = match.namedGroup('country') ?? '';
        final address =
            '${match.namedGroup('ip')}:${match.namedGroup('port')}';
        if (country.isEmpty || isBlocked(address)) continue;
        onCandidate(
          source: 'openproxylist',
          address: address,
          country: country,
          isSsl: true,
        );
      }
    } catch (e) {
      _logFetchError('openproxylist', e);
    }
  }

  Future<void> _fetchGeonode({
    required void Function({
      required String source,
      required String address,
      required String country,
      bool? isSsl,
    }) onCandidate,
    required bool Function(String address) isBlocked,
  }) async {
    try {
      const url =
          'https://proxylist.geonode.com/api/proxy-list?limit=50&page=1&sort_by=lastChecked&sort_type=desc&protocols=http%2Chttps';
      final response = await http
          .get(Uri.parse(url))
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => http.Response('', 408),
          );
      if (response.statusCode != 200) return;

      final result = jsonDecode(response.body) as Map<String, dynamic>;
      final data = result['data'];
      if (data is! List) return;

      for (final item in data) {
        if (item is! Map) continue;
        final ip = item['ip'];
        final port = item['port'];
        final country = item['country'];
        if (ip == null || port == null || country == null) continue;
        final address = '$ip:$port';
        if (isBlocked(address)) continue;
        onCandidate(
          source: 'geonode',
          address: address,
          country: country.toString(),
          isSsl: true,
        );
      }
    } catch (e) {
      _logFetchError('geonode', e);
    }
  }
}
