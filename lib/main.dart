import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:url_launcher/url_launcher.dart';

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
  InAppWebViewController? _webViewController;
  double _loadingProgress = 0.0;
  bool _isLoading = true;
  String? _errorMessage;
  bool _hasLoadedSuccessfully = false;
  final String _initialUrl = 'https://appcura.anmka.com/';

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
    _webViewController?.reload();
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
              InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri(_initialUrl),
                ),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  javaScriptCanOpenWindowsAutomatically: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                  useHybridComposition: true,
                  useShouldOverrideUrlLoading: true,
                  allowFileAccessFromFileURLs: true,
                  allowUniversalAccessFromFileURLs: true,
                  domStorageEnabled: true,
                  databaseEnabled: true,
                  cacheEnabled: true,
                  clearCache: false,
                  supportZoom: true,
                  builtInZoomControls: true,
                  displayZoomControls: false,
                  userAgent: 'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
                  // Prevent popups and dialogs
                  supportMultipleWindows: false,
                  disableContextMenu: true,
                ),
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                  debugPrint('🔧 WebView created');
                },
                onLoadStart: (controller, url) {
                  debugPrint('🚀 Page started loading: $url');
                  if (mounted) {
                    setState(() {
                      _loadingProgress = 0.0;
                      _isLoading = true;
                      _errorMessage = null;
                    });
                  }
                },
                onLoadStop: (controller, url) async {
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
                onProgressChanged: (controller, progress) {
                  debugPrint('📊 Loading progress: $progress%');
                  if (mounted) {
                    setState(() {
                      _loadingProgress = progress / 100;
                    });
                  }
                },
                onReceivedError: (controller, request, error) {
                  debugPrint('❌ WebView Error: ${error.description}');
                  if (!_hasLoadedSuccessfully) {
                    if (mounted) {
                      setState(() {
                        _errorMessage = 'خطأ في تحميل الصفحة: ${error.description}';
                        _isLoading = false;
                      });
                    }
                  }
                },
                onPermissionRequest: (controller, request) async {
                  debugPrint('🎥 Permission requested: ${request.resources}');
                  // Automatically grant all permissions without showing popup
                  return PermissionResponse(
                    resources: request.resources,
                    action: PermissionResponseAction.GRANT,
                  );
                },
                onJsAlert: (controller, jsAlertRequest) async {
                  // Block JavaScript alerts
                  return JsAlertResponse(
                    handledByClient: true,
                  );
                },
                onJsConfirm: (controller, jsConfirmRequest) async {
                  // Block JavaScript confirms
                  return JsConfirmResponse(
                    handledByClient: true,
                    action: JsConfirmResponseAction.CONFIRM,
                  );
                },
                onJsPrompt: (controller, jsPromptRequest) async {
                  // Block JavaScript prompts
                  return JsPromptResponse(
                    handledByClient: true,
                    action: JsPromptResponseAction.CONFIRM,
                  );
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  final url = navigationAction.request.url;
                  debugPrint('🧭 Navigation request: $url');
                  
                  if (url != null) {
                    final urlString = url.toString();
                    
                    // Handle Android Intent URLs specially
                    if (urlString.startsWith('intent://')) {
                      try {
                        // Parse the intent URL to extract the actual scheme and package
                        // Format: intent://...#Intent;scheme=SCHEME;package=PACKAGE;end
                        final intentMatch = RegExp(r'intent://(.+)#Intent;scheme=([^;]+);package=([^;]+);end').firstMatch(urlString);
                        
                        if (intentMatch != null) {
                          final scheme = intentMatch.group(2);
                          final packageName = intentMatch.group(3);
                          final path = intentMatch.group(1);
                          
                          // Try the app-specific scheme first (e.g., fb-messenger://)
                          final appUrl = '$scheme://$path';
                          debugPrint('🔄 Trying app URL: $appUrl');
                          
                          try {
                            final uri = Uri.parse(appUrl);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                              debugPrint('✅ Opened with app scheme: $appUrl');
                              return NavigationActionPolicy.CANCEL;
                            }
                          } catch (e) {
                            debugPrint('⚠️ App scheme failed, trying package: $e');
                          }
                          
                          // If app scheme fails, try opening the package directly
                          final marketUrl = 'market://details?id=$packageName';
                          try {
                            final uri = Uri.parse(marketUrl);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                              debugPrint('✅ Opened Play Store for: $packageName');
                            }
                          } catch (e) {
                            debugPrint('❌ Could not open app or Play Store: $e');
                          }
                        }
                      } catch (e) {
                        debugPrint('❌ Error parsing intent URL: $e');
                      }
                      return NavigationActionPolicy.CANCEL;
                    }
                    
                    // Check if it's an external URL scheme (WhatsApp, tel, mailto, etc.)
                    if (urlString.startsWith('whatsapp://') ||
                        urlString.startsWith('tel:') ||
                        urlString.startsWith('mailto:') ||
                        urlString.startsWith('sms:') ||
                        urlString.startsWith('fb://') ||
                        urlString.startsWith('fb-messenger://') ||
                        urlString.startsWith('instagram://') ||
                        urlString.startsWith('twitter://') ||
                        urlString.startsWith('tg://')) {
                      // Try to launch the external app
                      try {
                        final uri = Uri.parse(urlString);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                          debugPrint('✅ Opened external app: $urlString');
                        } else {
                          debugPrint('❌ Cannot launch: $urlString');
                        }
                      } catch (e) {
                        debugPrint('❌ Error launching URL: $e');
                      }
                      return NavigationActionPolicy.CANCEL;
                    }
                    
                    // Check if it's trying to open a new window/tab
                    if (!navigationAction.isForMainFrame) {
                      // Open external links in external browser
                      try {
                        final uri = Uri.parse(urlString);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                          debugPrint('✅ Opened in external browser: $urlString');
                        }
                      } catch (e) {
                        debugPrint('❌ Error opening external link: $e');
                      }
                      return NavigationActionPolicy.CANCEL;
                    }
                  }
                  
                  return NavigationActionPolicy.ALLOW;
                },
                onConsoleMessage: (controller, consoleMessage) {
                  debugPrint('📝 Console: ${consoleMessage.message}');
                },
              ),

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


          ],
        ),
      ),
      ),
    );
  }
}
