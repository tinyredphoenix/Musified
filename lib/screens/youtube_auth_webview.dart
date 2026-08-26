import 'package:flutter/cupertino.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:musify/services/youtube_auth_service.dart';
import 'package:musify/main.dart' show logger;

class YouTubeAuthWebView extends StatefulWidget {
  const YouTubeAuthWebView({super.key});

  @override
  State<YouTubeAuthWebView> createState() => _YouTubeAuthWebViewState();
}

class _YouTubeAuthWebViewState extends State<YouTubeAuthWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
          onUrlChange: (UrlChange change) async {
            final url = change.url;
            if (url != null && url.contains('music.youtube.com')) {
              await _extractCookiesAndComplete();
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('https://accounts.google.com/ServiceLogin?service=youtube&continue=https://music.youtube.com/'));
  }

  Future<void> _extractCookiesAndComplete() async {
    try {
      final cookieManager = WebViewCookieManager();
      final youtubeCookies = await cookieManager.getCookies(domain: Uri.parse('https://youtube.com'));
      final musicCookies = await cookieManager.getCookies(domain: Uri.parse('https://music.youtube.com'));
      final googleCookies = await cookieManager.getCookies(domain: Uri.parse('https://google.com'));
      
      final Map<String, String> cookiesMap = {};
      
      for (final cookie in [...googleCookies, ...youtubeCookies, ...musicCookies]) {
        cookiesMap[cookie.name] = cookie.value;
      }
      
      final hasRequired = cookiesMap.containsKey('SAPISID') || cookiesMap.containsKey('__Secure-3PAPISID');
      if (hasRequired) {
        YouTubeAuthService().saveCookies(cookiesMap);
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      logger.log('Error extracting cookies: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Sign in to YouTube Music'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context, false),
          child: const Icon(CupertinoIcons.clear),
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              const Center(
                child: CupertinoActivityIndicator(radius: 14),
              ),
          ],
        ),
      ),
    );
  }
}
