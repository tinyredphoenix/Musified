import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:musified/constants/clients.dart';
import 'package:musified/main.dart';
import 'package:musified/models/proxy_model.dart';
import 'package:musified/services/proxy_fetch_service.dart';
import 'package:musified/services/settings_manager.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class _ProxyResources {
  _ProxyResources(this.httpClient, this.ioClient);

  final HttpClient httpClient;
  final IOClient ioClient;

  void close() {
    try {
      ioClient.close();
    } catch (_) {}
    try {
      httpClient.close(force: true);
    } catch (_) {}
  }
}

class ProxyManager {
  // Singleton
  factory ProxyManager() => _instance;
  ProxyManager._internal() {
    _defaultYt = YoutubeExplode();
    _sharedYt = _defaultYt;
    if (useProxy.value) {
      unawaited(_initSharedProxyClient());
    }
    useProxy.addListener(_onUseProxyChanged);
  }

  void _onUseProxyChanged() {
    final generation = ++_proxySettingsGeneration;
    if (!useProxy.value) {
      _disableProxyClient();
      return;
    }
    unawaited(_initializeForGeneration(generation));
  }

  void dispose() {
    useProxy.removeListener(_onUseProxyChanged);
    _disableProxyClient();
    _defaultYt.close();
  }
  // Timeout constants
  static const int _validateDirectTimeout = 5;
  static const int _proxyRefreshIntervalMinutes = 60;

  final ProxyFetchService _fetchService = ProxyFetchService();

  static final ProxyManager _instance = ProxyManager._internal();

  /// Default non-proxy YoutubeExplode instance (long-lived)
  late final YoutubeExplode _defaultYt;

  /// Currently active shared YoutubeExplode - either [_defaultYt] or a
  /// proxy-backed client. Use [getClientSync] to access.
  YoutubeExplode? _sharedYt;

  Future<void>? _fetchingProxiesFuture;
  Completer<void>? _initializationCompletion;
  var _proxySettingsGeneration = 0;
  bool _hasFetched = false;
  final Map<String, List<ProxyInfo>> _proxiesByCountry = {};
  final Set<ProxyInfo> _workingProxies = {};

  /// Maps proxy addresses to the time they were blocked (TTL-aware blocklist)
  final Map<String, DateTime> _blockedProxyAddresses = {};
  final _random = Random();
  DateTime _lastFetched = DateTime.now();
  DateTime _lastProxyCleanup = DateTime.now();
  static const int _proxyCleanupIntervalMinutes = 120;
  static const int _maxProxyResourcePoolSize = 50;
  static const int _blockedProxyTtlMinutes = 30;
  static const int _maxBlockedProxiesSize = 200;

  final Map<String, _ProxyResources> _proxyResources = {};

  String? _sharedProxyAddress;

  Future<void> _initializeForGeneration(int generation) async {
    await _initSharedProxyClient(generation: generation);
    if (generation != _proxySettingsGeneration ||
        !useProxy.value ||
        _sharedYt != _defaultYt) {
      return;
    }
    await _initSharedProxyClient(generation: generation);
  }

  void _disableProxyClient() {
    if (_sharedYt != _defaultYt) {
      try {
        _sharedYt?.close();
      } catch (_) {}
      _sharedYt = _defaultYt;
    }
    _sharedProxyAddress = null;
    _workingProxies.clear();
    _closeAllProxyResources();
  }

  Future<void> _fetchProxies() async {
    if (!useProxy.value) return;
    final activeFetch = _fetchingProxiesFuture;
    if (activeFetch != null) {
      await activeFetch;
      return;
    }
    try {
      // Clear existing candidates to avoid duplicates and stale proxies
      _proxiesByCountry.clear();

      final fetch = _fetchService.fetchAll(
        onCandidate: ({
          required String source,
          required String address,
          required String country,
          bool? isSsl,
        }) {
          _addProxyCandidate(
            source: source,
            address: address,
            country: country,
            isSsl: isSsl,
          );
        },
        isBlocked: _isBlockedProxyAddress,
      );
      _fetchingProxiesFuture = fetch;
      await fetch.whenComplete(() {
        _hasFetched = true;
        _lastFetched = DateTime.now();
        _pruneStaleProxyResources();
      });
    } catch (e, stackTrace) {
      logger.log(
        'ProxyManager: Error fetching proxies',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _fetchingProxiesFuture = null;
    }
  }

  bool _isBlockedProxyAddress(String address) {
    final blockedAt = _blockedProxyAddresses[address];
    if (blockedAt == null) return false;

    // Check if TTL has expired
    if (DateTime.now().difference(blockedAt).inMinutes >
        _blockedProxyTtlMinutes) {
      _blockedProxyAddresses.remove(address);
      return false;
    }
    return true;
  }

  void _pruneExpiredBlockedProxies() {
    final now = DateTime.now();
    _blockedProxyAddresses.removeWhere(
      (_, blockedAt) =>
          now.difference(blockedAt).inMinutes > _blockedProxyTtlMinutes,
    );
  }

  void _enforceBlockedProxiesLimit() {
    if (_blockedProxyAddresses.length <= _maxBlockedProxiesSize) return;

    // Remove oldest entries when exceeding limit
    final entries = _blockedProxyAddresses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final toKeep = entries.take(_maxBlockedProxiesSize ~/ 2).toList();
    _blockedProxyAddresses.clear();
    for (final entry in toKeep) {
      _blockedProxyAddresses[entry.key] = entry.value;
    }
  }

  void _addProxyCandidate({
    required String source,
    required String address,
    required String country,
    bool? isSsl,
  }) {
    if (_isBlockedProxyAddress(address)) return;

    final countryProxies = _proxiesByCountry.putIfAbsent(country, () => []);
    if (countryProxies.any((candidate) => candidate.address == address)) {
      return;
    }

    countryProxies.add(
      ProxyInfo(
        source: source,
        address: address,
        country: country,
        isSsl: isSsl,
      ),
    );
  }

  /// Initialize a shared YoutubeExplode client that uses a working proxy.
  Future<void> _initSharedProxyClient({
    int timeoutSeconds = 5,
    int? generation,
  }) async {
    if (_initializationCompletion != null) {
      return _initializationCompletion!.future;
    }

    _initializationCompletion = Completer<void>();
    try {
      if (!_hasFetched) await _fetchProxies();
      if (_proxiesByCountry.isEmpty) await _fetchProxies();
      if (!useProxy.value ||
          (generation != null && generation != _proxySettingsGeneration)) {
        return;
      }

      do {
        final proxy = await _getRandomProxy();
        if (proxy == null) break;
        if (!useProxy.value ||
            (generation != null && generation != _proxySettingsGeneration)) {
          break;
        }
        try {
          final res = _ensureProxyResources(
            proxy,
            timeoutSeconds: timeoutSeconds,
          );
          final ytClient = YoutubeExplode(
            httpClient: YoutubeHttpClient(res.ioClient),
          );

          if (_sharedYt != null && _sharedYt != _defaultYt) {
            try {
              _sharedYt?.close();
            } catch (_) {}
          }
          _sharedYt = ytClient;
          _sharedProxyAddress = proxy.address;
          _workingProxies.add(proxy);
          break;
        } catch (e, stackTrace) {
          logger.log(
            'ProxyManager: failed to init shared proxy client for ${proxy.address}',
            error: e,
            stackTrace: stackTrace,
          );
          _discardProxy(proxy, reason: 'shared client init failed');
          continue;
        }
      } while (true);
    } catch (e, stackTrace) {
      logger.log(
        'Error initializing proxy client',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _initializationCompletion?.complete();
      _initializationCompletion = null;
    }
  }

  /// Returns the currently active YoutubeExplode client. Never null.
  YoutubeExplode getClientSync() => _sharedYt ?? _defaultYt;

  Future<StreamManifest?> _validateDirect(
    String songId,
    int timeoutSeconds,
  ) async {
    try {
      final manifest = await _defaultYt.videos.streams
          .getManifest(songId, ytClients: customClients)
          .timeout(Duration(seconds: timeoutSeconds));
      return manifest;
    } catch (e) {
      return null;
    }
  }

  Future<StreamManifest?> _validateProxy(
    ProxyInfo proxy,
    String songId,
    int timeoutSeconds,
  ) async {
    if (!useProxy.value) return null;
    YoutubeExplode? ytClient;
    try {
      final res = _ensureProxyResources(proxy, timeoutSeconds: timeoutSeconds);
      ytClient = YoutubeExplode(httpClient: YoutubeHttpClient(res.ioClient));
      final manifest = await ytClient.videos.streams
          .getManifest(songId, ytClients: customClients)
          .timeout(Duration(seconds: timeoutSeconds));
      _workingProxies.add(proxy);
      return manifest;
    } catch (e, stackTrace) {
      logger.log(
        'ProxyManager: failed to validate proxy ${proxy.address}',
        error: e,
        stackTrace: stackTrace,
      );
      _discardProxy(proxy, reason: 'validation failed', closeResources: false);
      return null;
    } finally {
      if (ytClient != null) {
        try {
          ytClient.close();
        } catch (_) {}
      }
    }
  }

  /// Periodically clean up old proxies to prevent memory bloat
  void _maybeCleanupProxies() {
    if (DateTime.now().difference(_lastProxyCleanup).inMinutes <
        _proxyCleanupIntervalMinutes) {
      return;
    }
    _lastProxyCleanup = DateTime.now();

    if (DateTime.now().difference(_lastFetched).inMinutes >=
        _proxyCleanupIntervalMinutes) {
      _proxiesByCountry.clear();
      _workingProxies.clear();
      _blockedProxyAddresses.clear();
      _hasFetched = false;
      _closeAllProxyResources();
    } else {
      // Prune expired blocked proxies even if not doing full cleanup
      _pruneExpiredBlockedProxies();
    }
  }

  Future<ProxyInfo?> _getRandomProxy({String? preferredCountry}) async {
    if (!useProxy.value) return null;
    try {
      if (!_hasFetched) await (_fetchingProxiesFuture ?? _fetchProxies());
      if (_hasFetched && _proxiesByCountry.isEmpty) await _fetchProxies();
      if (_proxiesByCountry.isEmpty) return null;

      ProxyInfo proxy;
      String countryCode;
      final workingProxies = _workingProxies
          .where((candidate) => !_isBlockedProxyAddress(candidate.address))
          .toList(growable: false);
      if (workingProxies.isNotEmpty) {
        final idx = workingProxies.length == 1
            ? 0
            : _random.nextInt(workingProxies.length);
        proxy = workingProxies[idx];
        _workingProxies.remove(proxy);
      } else {
        if (preferredCountry != null &&
            _proxiesByCountry.containsKey(preferredCountry)) {
          countryCode = preferredCountry;
        } else {
          final countries = _proxiesByCountry.keys.toList(growable: false);
          countryCode = countries[_random.nextInt(countries.length)];
        }
        final countryProxies = _proxiesByCountry[countryCode]
            ?.where((candidate) => !_isBlockedProxyAddress(candidate.address))
            .toList(growable: false);
        if (countryProxies == null || countryProxies.isEmpty) {
          if (_proxiesByCountry.isEmpty) return null;
          final allProxies = _proxiesByCountry.values
              .expand((x) => x)
              .where((candidate) => !_isBlockedProxyAddress(candidate.address))
              .toList(growable: false);
          if (allProxies.isEmpty) return null;
          proxy = allProxies[_random.nextInt(allProxies.length)];
        } else {
          proxy = countryProxies[_random.nextInt(countryProxies.length)];
        }
      }
      return proxy;
    } catch (e, stackTrace) {
      logger.log(
        'ProxyManager: Error getting random proxy',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  _ProxyResources _ensureProxyResources(
    ProxyInfo proxy, {
    int timeoutSeconds = 5,
  }) {
    final key = proxy.address;
    var res = _proxyResources[key];
    if (res != null) return res;

    final httpClient = HttpClient()
      ..connectionTimeout = Duration(seconds: timeoutSeconds)
      ..findProxy = (_) {
        return 'PROXY ${proxy.address}';
      }
      ..badCertificateCallback = (cert, host, port) => false;

    final ioClient = IOClient(httpClient);
    res = _ProxyResources(httpClient, ioClient);

    if (_proxyResources.length >= _maxProxyResourcePoolSize) {
      // Skip the entry that backs _sharedYt to avoid closing its IOClient.
      final oldestKey = _proxyResources.keys.firstWhere(
        (k) => k != _sharedProxyAddress,
        orElse: () => '',
      );
      if (oldestKey.isNotEmpty) {
        final oldest = _proxyResources.remove(oldestKey);
        try {
          oldest?.close();
        } catch (e, stackTrace) {
          logger.log(
            'ProxyManager: Error closing proxy resources',
            error: e,
            stackTrace: stackTrace,
          );
        }
      }
    }

    _proxyResources[key] = res;
    return res;
  }

  void _pruneStaleProxyResources() {
    if (_proxyResources.isEmpty) return;

    final activeAddresses = _proxiesByCountry.values
        .expand((x) => x)
        .map((p) => p.address)
        .toSet();

    final staleKeys = _proxyResources.keys
        .where(
          (key) => key != _sharedProxyAddress && !activeAddresses.contains(key),
        )
        .toList();

    for (final key in staleKeys) {
      final stale = _proxyResources.remove(key);
      try {
        stale?.close();
      } catch (e, stackTrace) {
        logger.log(
          'ProxyManager: Error closing stale proxy resources',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  void _discardProxy(
    ProxyInfo proxy, {
    String? reason,
    bool closeResources = true,
  }) {
    final address = proxy.address;
    _blockedProxyAddresses[address] = DateTime.now();
    _enforceBlockedProxiesLimit();

    _proxiesByCountry.removeWhere((_, proxies) {
      proxies.removeWhere((candidate) => candidate.address == address);
      return proxies.isEmpty;
    });
    _workingProxies.removeWhere((candidate) => candidate.address == address);

    final resources = _proxyResources.remove(address);
    if (resources != null) {
      if (closeResources) {
        try {
          resources.close();
        } catch (e, stackTrace) {
          logger.log(
            'ProxyManager: Error closing discarded proxy resources',
            error: e,
            stackTrace: stackTrace,
          );
        }
      } else {
        // Let timed-out validation requests unwind before closing the client.
        unawaited(
          Future.delayed(const Duration(seconds: 2), () {
            try {
              resources.close();
            } catch (e, stackTrace) {
              logger.log(
                'ProxyManager: Error closing discarded proxy resources',
                error: e,
                stackTrace: stackTrace,
              );
            }
          }),
        );
      }
    }

    if (_sharedProxyAddress == address) {
      if (_sharedYt != null && _sharedYt != _defaultYt) {
        try {
          _sharedYt?.close();
        } catch (_) {}
      }
      _sharedYt = _defaultYt;
      _sharedProxyAddress = null;
    }

    logger.log(
      'ProxyManager: discarded proxy $address${reason != null ? ' ($reason)' : ''}',
    );
  }

  Future<StreamManifest?> getSongManifest(String songId) async {
    if (!useProxy.value) {
      return _validateDirect(songId, _validateDirectTimeout);
    }
    var manifest = await _validateDirect(songId, _validateDirectTimeout);
    if (manifest != null) return manifest;

    if (DateTime.now().difference(_lastFetched).inMinutes >=
        _proxyRefreshIntervalMinutes) {
      await _fetchProxies();
    }

    _maybeCleanupProxies();

    manifest = await _tryProxies(songId);
    return manifest;
  }

  Future<StreamManifest?> _tryProxies(String songId) async {
    if (!useProxy.value) return null;
    StreamManifest? manifest;
    var attempts = 0;
    const maxAttempts = 5;
    do {
      if (attempts++ >= maxAttempts) break;
      final proxy = await _getRandomProxy();
      if (proxy == null) break;
      manifest = await _validateProxy(proxy, songId, 5);
    } while (manifest == null);
    return manifest;
  }

  /// Performs an HTTP GET request that respects current proxy settings.
  Future<http.Response> getProxiedResponse(
    Uri uri, {
    Map<String, String>? headers,
    int timeoutSeconds = 10,
  }) async {
    if (!useProxy.value || _sharedProxyAddress == null) {
      return http
          .get(uri, headers: headers)
          .timeout(
            Duration(seconds: timeoutSeconds),
            onTimeout: () => http.Response('Timeout', 408),
          );
    }

    final res = _proxyResources[_sharedProxyAddress!];
    if (res == null) {
      return http
          .get(uri, headers: headers)
          .timeout(
            Duration(seconds: timeoutSeconds),
            onTimeout: () => http.Response('Timeout', 408),
          );
    }

    return res.ioClient
        .get(uri, headers: headers)
        .timeout(
          Duration(seconds: timeoutSeconds),
          onTimeout: () => http.Response('Timeout', 408),
        );
  }

  void _closeAllProxyResources() {
    for (final res in _proxyResources.values) {
      try {
        res.close();
      } catch (e, stackTrace) {
        logger.log(
          'ProxyManager: Error closing proxy resources',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
    _proxyResources.clear();
    _sharedProxyAddress = null;
  }

  /// Try to create a [YoutubeExplode] client that routes requests through a
  /// working proxy. Returns null if no proxy client could be created.
  ///
  /// **IMPORTANT**: Caller is responsible for calling `close()` on the returned
  /// [YoutubeExplode] when finished to free resources. Failure to close will leak
  /// HTTP connections and memory.
  Future<YoutubeExplode?> getYoutubeExplodeClient({
    int timeoutSeconds = 5,
  }) async {
    if (!useProxy.value) return null;
    if (!_hasFetched) await _fetchProxies();

    if (_proxiesByCountry.isEmpty) await _fetchProxies();

    if (_proxiesByCountry.isEmpty) return null;

    do {
      final proxy = await _getRandomProxy();
      if (proxy == null) break;

      try {
        final res = _ensureProxyResources(
          proxy,
          timeoutSeconds: timeoutSeconds,
        );
        final ytClient = YoutubeExplode(
          httpClient: YoutubeHttpClient(res.ioClient),
        );

        _workingProxies.add(proxy);
        return ytClient;
      } catch (e, stackTrace) {
        logger.log(
          'ProxyManager: failed to create proxy youtube client for ${proxy.address}',
          error: e,
          stackTrace: stackTrace,
        );
        _discardProxy(proxy, reason: 'youtube client creation failed');
        continue;
      }
    } while (true);

    return null;
  }
}

/// Lazy accessor so that ProxyManager (and its Hive read of `useProxy`) is not
/// created at import time before Hive is initialized. Each call returns the
/// current shared client.
YoutubeExplode get ytClient => ProxyManager().getClientSync();
