import 'package:flutter/services.dart';

enum WebNavigation { embedded, externalApp, blocked }

WebNavigation classifyWebNavigation(String url, {required bool isMainFrame}) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return WebNavigation.blocked;
  if (uri.scheme == 'https') {
    return uri.host.isNotEmpty && uri.userInfo.isEmpty
        ? WebNavigation.embedded
        : WebNavigation.blocked;
  }
  // Let WebKit handle iframe documents in their own frame, never load them
  // into the top-level WebView or send them to another application.
  if (!isMainFrame &&
      ((uri.scheme == 'about' && {'blank', 'srcdoc'}.contains(uri.path)) ||
          uri.scheme == 'blob' ||
          uri.scheme == 'data')) {
    return WebNavigation.embedded;
  }
  if ({'http', 'file', 'content', 'javascript', 'data', 'blob', 'about'}
      .contains(uri.scheme)) {
    return WebNavigation.blocked;
  }
  return WebNavigation.externalApp;
}

class WebViewBridge {
  static const channel = MethodChannel('lucky_games/webview');

  static void registerTrackingHandler(Future<void> Function(String) submit) {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'trackH5Event' && call.arguments is String) {
        await submit(call.arguments as String);
        return null;
      }
      throw MissingPluginException('Unknown native callback: ${call.method}');
    });
  }

  static Future<bool> isAirbridgeReady() async =>
      await channel.invokeMethod<bool>('isAirbridgeReady') ?? false;

  static Future<bool> installTrackingScript(
          int identifier, String script) async =>
      await channel.invokeMethod<bool>('installTrackingScript', {
        'identifier': identifier,
        'script': script,
      }) ??
      false;

  static Future<List<String>> selectFiles({
    required List<String> acceptTypes,
    required bool multiple,
  }) async {
    try {
      return await channel.invokeListMethod<String>('selectFiles', {
            'acceptTypes': acceptTypes,
            'multiple': multiple,
          }) ??
          const [];
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  /// Returns an optional HTTPS fallback when an Android intent app is absent.
  static Future<({bool opened, Uri? fallback})> openExternal(String url) async {
    try {
      final result = await channel.invokeMapMethod<String, dynamic>(
        'openExternal',
        {'url': url},
      );
      final fallback = Uri.tryParse(result?['fallbackUrl'] as String? ?? '');
      return (
        opened: result?['opened'] == true,
        fallback: fallback != null &&
                classifyWebNavigation(fallback.toString(), isMainFrame: true) ==
                    WebNavigation.embedded
            ? fallback
            : null,
      );
    } on PlatformException {
      return (opened: false, fallback: null);
    } on MissingPluginException {
      return (opened: false, fallback: null);
    }
  }

  static Future<void> configureAndroidFrames(int identifier) => channel
      .invokeMethod<void>('configureWebView', {'identifier': identifier});
}
