import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
// Import the new package for Windows
import 'package:webview_windows/webview_windows.dart';
// Import screen_protector for Android/iOS
import 'package:screen_protector/screen_protector.dart';

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
  // Now handle two different types of controllers
  WebViewController? _androidIosController;
  final _windowsController = WebviewController();
  double _loadingProgress = 0.0;
  bool _isLoading = true;
  String? _errorMessage;
  bool _hasLoadedSuccessfully = false;

  // Flag to check if it's a Windows platform
  bool get _isWindows => defaultTargetPlatform == TargetPlatform.windows;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _initializeScreenProtector();
  }

  /// Initialize screen protection on Android/iOS
  Future<void> _initializeScreenProtector() async {
    if (!_isWindows) {
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
  }

  void _initializeWebView() async {
    debugPrint('🔧 Initializing WebView...');

    if (_isWindows) {
      // Windows-specific initialization
      debugPrint('💻 Using WebView for Windows');
      try {
        await _windowsController.initialize();
        _windowsController.url.listen((url) {
          debugPrint('🚀 Windows Page started loading: $url');
          if (mounted) {
            setState(() {
              _isLoading = true;
              _errorMessage = null;
            });
          }
        });
        _windowsController.loadingState.listen((state) {
          if (mounted) {
            setState(() {
              if (state == LoadingState.loading) {
                _loadingProgress = 0.5;
                _isLoading = true;
              } else if (state == LoadingState.navigationCompleted) {
                _loadingProgress = 1.0;
                _isLoading = false;
                _hasLoadedSuccessfully = true;
                _errorMessage = null;
              }
            });
          }
        });
        await _windowsController.loadUrl('https://cura.anmka.com/');
      } catch (e) {
        debugPrint('❌ Windows WebView Initialization Error: $e');
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to initialize WebView on Windows: $e';
            _isLoading = false;
          });
        }
      }
    } else {
      // Android/iOS-specific initialization
      debugPrint('📱 Using Android/iOS WebView');
      late final PlatformWebViewControllerCreationParams params;

      if (WebViewPlatform.instance is WebKitWebViewPlatform) {
        debugPrint('🍎 Using WebKit WebView (iOS)');
        params = WebKitWebViewControllerCreationParams(
          allowsInlineMediaPlayback: true,
        );
      } else {
        debugPrint('🤖 Using Android WebView');
        params = const PlatformWebViewControllerCreationParams();
      }

      final WebViewController controller =
          WebViewController.fromPlatformCreationParams(params);

      debugPrint('⚙️ Configuring WebView settings...');
      controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..enableZoom(true)
        ..setUserAgent(
            'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36')
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              debugPrint('📊 Loading progress: $progress%');
              if (mounted) {
                setState(() {
                  _loadingProgress = progress / 100;
                });
              }
            },
            onPageStarted: (String url) {
              debugPrint('🚀 Page started loading: $url');
              if (mounted) {
                setState(() {
                  _loadingProgress = 0.0;
                  _isLoading = true;
                  _errorMessage = null;
                });
              }
            },
            onPageFinished: (String url) {
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
            onWebResourceError: (WebResourceError error) {
              debugPrint('❌ WebView Error: ${error.description}');
              debugPrint('❌ Error Code: ${error.errorCode}');
              debugPrint('❌ Error Type: ${error.errorType}');
              debugPrint('❌ Has Loaded Successfully: $_hasLoadedSuccessfully');

              if (!_hasLoadedSuccessfully &&
                  !error.description.contains('ERR_NAME_NOT_RESOLVED') &&
                  !error.description.contains('ERR_CONNECTION_REFUSED') &&
                  !error.description.contains('ERR_INTERNET_DISCONNECTED')) {
                if (mounted) {
                  setState(() {
                    _errorMessage = 'خطأ في تحميل الصفحة: ${error.description}';
                    _isLoading = false;
                  });
                }
              }
            },
            onNavigationRequest: (NavigationRequest request) {
              debugPrint('🧭 Navigation request: ${request.url}');
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(Uri.parse('https://cura.anmka.com/'));

      debugPrint('🌐 Loading URL: https://cura.anmka.com/');
      _androidIosController = controller;
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

    if (_isWindows) {
      _windowsController.loadUrl('https://cura.anmka.com/');
    } else {
      _androidIosController?.reload();
    }
  }

  @override
  void dispose() {
    if (_isWindows) {
      _windowsController.dispose();
    } else {
      // Disable screen protection when leaving
      if (defaultTargetPlatform == TargetPlatform.android) {
        ScreenProtector.protectDataLeakageOff();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        ScreenProtector.preventScreenshotOff();
      }
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
              // Use the correct WebView widget based on the platform
              if (_isWindows)
                Webview(_windowsController)
              else if (_androidIosController != null)
                WebViewWidget(controller: _androidIosController!),

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

              if (_errorMessage != null && !_hasLoadedSuccessfully)
                Center(
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red[600],
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _refreshWebView,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[600],
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
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