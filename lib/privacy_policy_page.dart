import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'privacy_api.dart';
import 'h5_event_tracker.dart';
import 'webview_bridge.dart';

Uri parsePrivacyPolicyUrl(String responseBody) {
  final result = PrivacyResult.parse(responseBody);
  return result.url ?? (throw const FormatException('Missing policy URL.'));
}

class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key, this.initialUrl, this.fullPage = false});

  final Uri? initialUrl;
  final bool fullPage;

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  final http.Client _client = http.Client();
  WebViewController? _webViewController;
  bool _loadingPage = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPrivacyPolicy();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _loadPrivacyPolicy() async {
    setState(() {
      _webViewController = null;
      _loadingPage = true;
      _errorMessage = null;
    });

    try {
      final policyUri =
          widget.initialUrl ?? (await fetchPrivacyResult(_client)).url;
      if (policyUri == null) throw const FormatException('Missing policy URL.');
      requireHttpsUrl(policyUri.toString());
      if (!mounted) return;
      final params = WebViewPlatform.instance is WebKitWebViewPlatform
          ? WebKitWebViewControllerCreationParams(
              allowsInlineMediaPlayback: true)
          : const PlatformWebViewControllerCreationParams();
      final controller = WebViewController.fromPlatformCreationParams(
        params,
        // File selection does not need camera/microphone permissions.
        onPermissionRequest: (request) => request.deny(),
      );
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(Colors.white);
      final trackingScript =
          await rootBundle.loadString('assets/airbridge_bridge.js');
      var trackingAtDocumentStart = false;
      WebViewBridge.registerTrackingHandler((message) async {
        final result = await H5EventTracker.instance.submit(message);
        if (result != H5TrackingResult.submitted) {
          debugPrint('H5 tracking: ${result.name}');
        }
      });
      await controller.addJavaScriptChannel(
        'LuckyAirbridgeEvents',
        onMessageReceived: (message) async {
          final result = await H5EventTracker.instance.submit(message.message);
          // No order IDs, tokens or full event payloads in logs.
          if (result != H5TrackingResult.submitted) {
            debugPrint('H5 tracking: ${result.name}');
          }
        },
      );
      Future<void> installLegacyTrackingScript() async {
        if (trackingAtDocumentStart || !mounted) return;
        try {
          await controller.runJavaScript(trackingScript);
        } catch (_) {
          // A navigation may have replaced the JS context; retry at page finish.
        }
      }

      await controller.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            unawaited(installLegacyTrackingScript());
            if (mounted) {
              setState(() {
                _loadingPage = true;
                _errorMessage = null;
              });
            }
          },
          onPageFinished: (_) {
            unawaited(installLegacyTrackingScript());
            if (mounted) setState(() => _loadingPage = false);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() {
                _loadingPage = false;
                _errorMessage = 'Unable to load the privacy policy.';
              });
            }
          },
          onNavigationRequest: (request) async {
            switch (classifyWebNavigation(request.url,
                isMainFrame: request.isMainFrame)) {
              case WebNavigation.embedded:
                return NavigationDecision.navigate;
              case WebNavigation.blocked:
                return NavigationDecision.prevent;
              case WebNavigation.externalApp:
                final result = await WebViewBridge.openExternal(request.url);
                if (!mounted) return NavigationDecision.prevent;
                if (!result.opened) {
                  if (result.fallback != null && request.isMainFrame) {
                    await controller.loadRequest(result.fallback!);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'Unable to open this app. It may not be installed.'),
                    ));
                  }
                }
                return NavigationDecision.prevent;
            }
          },
        ),
      );

      if (controller.platform case final AndroidWebViewController android) {
        await android.setAllowContentAccess(true);
        await android.setGeolocationEnabled(false);
        await android.setOnShowFileSelector((params) {
          if (params.mode == FileSelectorMode.save) {
            return Future.value(<String>[]);
          }
          // Ignore capture hints: only select existing files, no camera grant.
          return WebViewBridge.selectFiles(
            acceptTypes: params.acceptTypes,
            multiple: params.mode == FileSelectorMode.openMultiple,
          );
        });
        final cookies =
            WebViewCookieManager().platform as AndroidWebViewCookieManager;
        await cookies.setAcceptThirdPartyCookies(android, true);
        await WebViewBridge.configureAndroidFrames(android.webViewIdentifier);
        trackingAtDocumentStart = await WebViewBridge.installTrackingScript(
            android.webViewIdentifier, trackingScript);
      } else if (controller.platform
          case final WebKitWebViewController webkit) {
        trackingAtDocumentStart = await WebViewBridge.installTrackingScript(
            webkit.webViewIdentifier, trackingScript);
      }

      if (!mounted) return;
      setState(() => _webViewController = controller);
      await controller.loadRequest(policyUri);
    } on TimeoutException {
      _showError('The privacy request timed out. Please try again.');
    } on FormatException {
      _showError('The privacy service returned an invalid response.');
    } catch (_) {
      _showError('Privacy policy is temporarily unavailable.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _loadingPage = false;
      _errorMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.fullPage
          ? null
          : AppBar(
              title: const Text(
                'Privacy Policy',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              centerTitle: true,
            ),
      body: SafeArea(
          child: Stack(
        fit: StackFit.expand,
        children: [
          if (_webViewController != null)
            WebViewWidget(controller: _webViewController!),
          if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 54,
                      color: Color(0xFF8A718E),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _loadPrivacyPolicy,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('RETRY'),
                    ),
                  ],
                ),
              ),
            ),
          if (_loadingPage)
            const Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(minHeight: 3),
            ),
        ],
      )),
    );
  }
}
