import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const CuraApp());
}

class CuraApp extends StatelessWidget {
  const CuraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cura - Your Medical Learning Platform',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const WebViewScreen(),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _webViewController = _createWebViewController();
  double _loadingProgress = 0.0;
  bool _isLoading = true;
  String? _errorMessage;
  bool _hasLoadedSuccessfully = false;
  final Uri _initialUri = Uri.parse('https://cura.anmka.com/');
  final Map<String, String> _anmkaHeaders = const {'X-App-Source': 'anmka'};
  String? _lastHeaderInjectedUrl;

  @override
  void initState() {
    super.initState();
    _initializeScreenProtector();
  }

  /// Initialize screen protection on Android/iOS
  Future<void> _initializeScreenProtector() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        debugPrint('🛡️ Enabling Android screen protection...');
        await ScreenProtector.protectDataLeakageOn();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        debugPrint('🛡️ Enabling iOS screenshot prevention...');
        await ScreenProtector.preventScreenshotOn();
      }
    } catch (e) {
      debugPrint('❌ ScreenProtector init error: $e');
    }
  }

  void _refreshWebView() {
    debugPrint('🔄 Refreshing WebView...');
    if (mounted) {
      setState(() {
        _loadingProgress = 0.0;
        _isLoading = true;
        _errorMessage = null;
        _hasLoadedSuccessfully = false;
      });
    }
    // Reload with custom header
    _webViewController.loadRequest(_initialUri, headers: _anmkaHeaders);
  }

  @override
  void dispose() {
    // Disable screen protection when leaving
    if (defaultTargetPlatform == TargetPlatform.android) {
      ScreenProtector.protectDataLeakageOff();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      ScreenProtector.preventScreenshotOff();
    }
    super.dispose();
  }

  WebViewController _createWebViewController() {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            debugPrint('🚀 Page started loading: $url');
            if (mounted) {
              setState(() {
                _loadingProgress = 0.0;
                _isLoading = true;
                _errorMessage = null;
                _hasLoadedSuccessfully = false;
              });
            }
          },
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _loadingProgress = progress / 100;
              });
            }
          },
          onPageFinished: (url) {
            debugPrint('✅ Page finished loading: $url');
            if (mounted) {
              setState(() {
                _loadingProgress = 1.0;
                _isLoading = false;
                _hasLoadedSuccessfully = true;
                _errorMessage = null;
              });
            }
          },
          onWebResourceError: (error) {
            debugPrint('❌ WebView Error: ${error.description}');
            if (!_hasLoadedSuccessfully && mounted) {
              setState(() {
                _errorMessage = 'خطأ في تحميل الصفحة: ${error.description}';
                _isLoading = false;
              });
            }
          },
          onNavigationRequest: _handleNavigationRequest,
        ),
      )
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..loadRequest(_initialUri, headers: _anmkaHeaders);

    return controller;
  }

  Future<NavigationDecision> _handleNavigationRequest(
    NavigationRequest request,
  ) async {
    final urlString = request.url;
    debugPrint('🧭 Navigation request: $urlString');

    if (urlString.contains('appcura.anmka.com') && request.isMainFrame) {
      if (_lastHeaderInjectedUrl == urlString) {
        _lastHeaderInjectedUrl = null;
        return NavigationDecision.navigate;
      }
      final uri = Uri.tryParse(urlString);
      if (uri != null) {
        try {
          _lastHeaderInjectedUrl = urlString;
          await _webViewController.loadRequest(uri, headers: _anmkaHeaders);
          debugPrint('✅ Navigation with custom header: $urlString');
        } catch (e) {
          debugPrint('⚠️ Could not load with headers: $e');
          _lastHeaderInjectedUrl = null;
        }
      }
      return NavigationDecision.prevent;
    }

    if (urlString.startsWith('intent://')) {
      await _handleIntentUrl(urlString);
      return NavigationDecision.prevent;
    }

    if (_isExternalScheme(urlString)) {
      final uri = Uri.tryParse(urlString);
      if (uri != null) {
        await _launchExternal(uri);
      }
      return NavigationDecision.prevent;
    }

    if (!request.isMainFrame) {
      final uri = Uri.tryParse(urlString);
      if (uri != null) {
        await _launchExternal(uri);
      }
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  Future<void> _handleIntentUrl(String urlString) async {
    try {
      final intentMatch = RegExp(
        r'intent://(.+)#Intent;scheme=([^;]+);package=([^;]+);end',
      ).firstMatch(urlString);

      if (intentMatch == null) {
        return;
      }

      final scheme = intentMatch.group(2);
      final packageName = intentMatch.group(3);
      final path = intentMatch.group(1);

      if (scheme == null || path == null) {
        return;
      }

      final appUrl = '$scheme://$path';
      debugPrint('🔄 Trying app URL: $appUrl');

      final appUri = Uri.tryParse(appUrl);
      if (appUri != null && await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
        debugPrint('✅ Opened with app scheme: $appUrl');
        return;
      }

      if (packageName != null) {
        final marketUri = Uri.tryParse('market://details?id=$packageName');
        if (marketUri != null && await canLaunchUrl(marketUri)) {
          await launchUrl(marketUri, mode: LaunchMode.externalApplication);
          debugPrint('✅ Opened store for: $packageName');
        }
      }
    } catch (e) {
      debugPrint('❌ Error parsing intent URL: $e');
    }
  }

  bool _isExternalScheme(String urlString) {
    return urlString.startsWith('whatsapp://') ||
        urlString.startsWith('tel:') ||
        urlString.startsWith('mailto:') ||
        urlString.startsWith('sms:') ||
        urlString.startsWith('fb://') ||
        urlString.startsWith('fb-messenger://') ||
        urlString.startsWith('instagram://') ||
        urlString.startsWith('twitter://') ||
        urlString.startsWith('tg://');
  }

  Future<void> _launchExternal(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        debugPrint('✅ Opened external link: $uri');
      } else {
        debugPrint('❌ Cannot launch: $uri');
      }
    } catch (e) {
      debugPrint('❌ Error launching URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _refreshWebView();
          },
          child: Stack(
            children: [
              WebViewWidget(controller: _webViewController),
              if (_isLoading && _loadingProgress < 1.0)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: _loadingProgress,
                    backgroundColor: Colors.grey[200],
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                    minHeight: 3,
                  ),
                ),
              if (_errorMessage != null && !_isLoading)
                Container(
                  color: Colors.white,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _refreshWebView,
                            icon: const Icon(Icons.refresh),
                            label: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
