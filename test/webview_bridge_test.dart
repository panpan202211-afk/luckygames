import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky_games/webview_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test('native event callback forwards once to the shared tracking handler',
      () async {
    final received = <String>[];
    WebViewBridge.registerTrackingHandler((message) async {
      received.add(message);
    });
    const payload =
        '{"eventName":"purchase","params":{"transaction_id":"tx1"}}';
    await messenger.handlePlatformMessage(
      WebViewBridge.channel.name,
      const StandardMethodCodec()
          .encodeMethodCall(const MethodCall('trackH5Event', payload)),
      (_) {},
    );
    expect(received, [payload]);
    WebViewBridge.channel.setMethodCallHandler(null);
  });

  tearDown(
      () => messenger.setMockMethodCallHandler(WebViewBridge.channel, null));

  test('HTTPS stays embedded for both parent and cross-origin iframe', () {
    for (final mainFrame in [true, false]) {
      expect(
          classifyWebNavigation('https://other.example/page',
              isMainFrame: mainFrame),
          WebNavigation.embedded);
    }
  });

  test('iframe blank/srcdoc/blob/data documents never launch external apps',
      () {
    for (final url in [
      'about:blank',
      'about:srcdoc',
      'blob:https://example.com/uuid',
      'data:text/html,<p>frame</p>'
    ]) {
      expect(classifyWebNavigation(url, isMainFrame: false),
          WebNavigation.embedded);
      expect(
          classifyWebNavigation(url, isMainFrame: true), WebNavigation.blocked);
    }
  });

  test('custom schemes and Android intents can open apps in either frame', () {
    for (final url in [
      'weixin://',
      'alipays://platformapi/startapp',
      'tel:123',
      'mailto:test@example.com',
      'intent://scan/#Intent;scheme=zxing;package=com.example;end'
    ]) {
      for (final mainFrame in [true, false]) {
        expect(classifyWebNavigation(url, isMainFrame: mainFrame),
            WebNavigation.externalApp);
      }
    }
  });

  test('local files, script URLs and insecure navigation are not app intents',
      () {
    for (final url in [
      'file:///private/file',
      'content://private/file',
      'javascript:alert(1)',
      'http://example.com',
      'https://',
      'https://user:password@example.com',
      'bad-url'
    ]) {
      for (final mainFrame in [true, false]) {
        expect(classifyWebNavigation(url, isMainFrame: mainFrame),
            WebNavigation.blocked);
      }
    }
  });

  test(
      'file picker forwards MIME filters and multiple and returns selected URIs',
      () async {
    messenger.setMockMethodCallHandler(WebViewBridge.channel, (call) async {
      expect(call.method, 'selectFiles');
      expect(call.arguments, {
        'acceptTypes': ['image/*'],
        'multiple': true
      });
      return ['content://media/1', 'content://media/2'];
    });
    expect(
        await WebViewBridge.selectFiles(
            acceptTypes: ['image/*'], multiple: true),
        ['content://media/1', 'content://media/2']);
  });

  test('file picker cancellation or native error completes with no files',
      () async {
    for (final failure in [false, true]) {
      messenger.setMockMethodCallHandler(WebViewBridge.channel, (_) async {
        if (failure) throw PlatformException(code: 'unavailable');
        return <String>[];
      });
      expect(await WebViewBridge.selectFiles(acceptTypes: [], multiple: false),
          isEmpty);
    }
  });

  test(
      'external app success and failure are returned without navigating the WebView',
      () async {
    for (final opened in [true, false]) {
      messenger.setMockMethodCallHandler(WebViewBridge.channel, (call) async {
        expect(call.method, 'openExternal');
        expect(call.arguments, {'url': 'weixin://'});
        return {'opened': opened};
      });
      final result = await WebViewBridge.openExternal('weixin://');
      expect(result.opened, opened);
      expect(result.fallback, isNull);
    }
  });

  test('only HTTPS Android intent fallback URLs are accepted', () async {
    for (final url in [
      'https://example.com/install',
      'http://example.com',
      'javascript:alert(1)',
      'file:///private/file'
    ]) {
      messenger.setMockMethodCallHandler(WebViewBridge.channel,
          (_) async => {'opened': false, 'fallbackUrl': url});
      final result = await WebViewBridge.openExternal('intent://example');
      expect(
          result.fallback?.toString(), url.startsWith('https:') ? url : null);
    }
  });
}
