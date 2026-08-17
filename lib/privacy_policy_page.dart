import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

const privacyPolicyEndpoint = 'https://lucky.funnygames365.com/api/privacy';

Uri parsePrivacyPolicyUrl(String responseBody) {
  final decoded = jsonDecode(responseBody);
  if (decoded is! Map<String, dynamic> || decoded['code'].toString() != '0') {
    throw const FormatException('Privacy API returned an unsuccessful result.');
  }

  final uri = Uri.tryParse(decoded['url']?.toString() ?? '');
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    throw const FormatException('Privacy API returned an invalid HTTPS URL.');
  }
  return uri;
}

class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key});

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
      final response = await _client
          .get(Uri.parse(privacyPolicyEndpoint))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw http.ClientException(
          'Privacy API returned HTTP ${response.statusCode}.',
        );
      }

      final policyUri = parsePrivacyPolicyUrl(response.body);
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) {
              if (mounted) setState(() => _loadingPage = true);
            },
            onPageFinished: (_) {
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
            onNavigationRequest: (request) {
              final uri = Uri.tryParse(request.url);
              return uri != null &&
                      (uri.scheme == 'https' || uri.scheme == 'http')
                  ? NavigationDecision.navigate
                  : NavigationDecision.prevent;
            },
          ),
        );

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
      appBar: AppBar(
        title: const Text(
          'Privacy Policy',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: Stack(
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
      ),
    );
  }
}
