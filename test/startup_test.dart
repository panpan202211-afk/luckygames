import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lucky_games/privacy_api.dart';
import 'package:lucky_games/startup_page.dart';

void main() {
  test('game mode accepts numeric/string zero without a URL', () {
    for (final body in ['{"code":0}', '{"code":"0","url":"bad"}']) {
      expect(PrivacyResult.parse(body).code, 0);
    }
  });

  test('H5 mode requires HTTPS; unknown codes and invalid JSON fail', () {
    for (final code in [1, '1']) {
      expect(
          PrivacyResult.parse(
                  '{"code":${code is String ? '"1"' : '1'},"url":"https://example.com"}')
              .url!
              .host,
          'example.com');
    }
    for (final body in [
      '{}',
      '[]',
      'invalid',
      '{"code":2}',
      '{"code":1}',
      '{"code":1,"url":"http://example.com"}',
      '{"code":1,"url":"javascript:alert(1)"}'
    ]) {
      expect(() => PrivacyResult.parse(body), throwsFormatException);
    }
  });

  test('request uses TLS and refuses redirects and HTTP errors', () async {
    for (final status in [200, 302, 500]) {
      final client = MockClient((request) async {
        expect(request.url.scheme, 'https');
        expect(request.url.path, '/api/privacy');
        expect(request.followRedirects, isFalse);
        return http.Response('{"code":0}', status);
      });
      if (status == 200) {
        expect((await fetchPrivacyResult(client)).code, 0);
      } else {
        await expectLater(
            fetchPrivacyResult(client), throwsA(isA<http.ClientException>()));
      }
      client.close();
    }
  });

  testWidgets('startup selects game or H5 without showing game first',
      (tester) async {
    for (final code in [0, 1]) {
      await tester.pumpWidget(MaterialApp(
          home: StartupPage(
        key: ValueKey(code),
        loader: () async =>
            PrivacyResult.parse('{"code":$code,"url":"https://example.com"}'),
        gameBuilder: (_) => const Text('GAME'),
        webBuilder: (uri) => Text('H5 ${uri.host}'),
      )));
      expect(find.text('GAME'), findsNothing);
      await tester.pump();
      expect(find.text(code == 0 ? 'GAME' : 'H5 example.com'), findsOneWidget);
      expect(find.text(code == 0 ? 'H5 example.com' : 'GAME'), findsNothing);
    }
  });

  testWidgets('failed startup can retry successfully', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(
        home: StartupPage(
      loader: () async {
        if (++attempts == 1) throw Exception('offline');
        return const PrivacyResult(code: 0);
      },
      gameBuilder: (_) => const Text('GAME'),
    )));
    await tester.pump();
    expect(find.text('GAME'), findsNothing);
    await tester.tap(find.text('RETRY'));
    await tester.pump();
    await tester.pump();
    expect(find.text('GAME'), findsOneWidget);
  });
}
