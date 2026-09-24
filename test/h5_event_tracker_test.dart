import 'dart:convert';

import 'package:airbridge_flutter_sdk/airbridge_flutter_sdk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky_games/h5_event_tracker.dart';
import 'package:lucky_games/webview_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FailedWritePreferences extends Fake implements SharedPreferences {
  @override
  bool? getBool(String key) => null;
  @override
  Future<bool> setBool(String key, bool value) async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const sdkChannel = MethodChannel('airbridge_flutter_sdk/method/event');
  late List<H5TrackingEvent> sent;
  late H5EventTracker tracker;
  String message(String name, [Map<String, dynamic> params = const {}]) =>
      jsonEncode({'eventName': name, 'params': params});

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sent = [];
    tracker = H5EventTracker(isReady: () async => true, send: sent.add);
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(WebViewBridge.channel, null);
    messenger.setMockMethodCallHandler(sdkChannel, null);
  });

  test('maps to Airbridge standard categories and revenue/transaction fields',
      () async {
    await tracker.submit(message('register', {'source': 'H5'}));
    await tracker.submit(message('apply', {'orderId': 'order-1'}));
    await tracker.submit(message('purchase', {
      'orderId': 'order-1',
      'value': '12.50',
      'currency': 'usd',
      'campaign': 'test',
    }));
    expect(sent.map((e) => e.category), [
      AirbridgeCategory.SIGN_UP,
      AirbridgeCategory.INITIATE_CHECKOUT,
      AirbridgeCategory.ORDER_COMPLETED
    ]);
    expect(sent.last.semanticAttributes,
        {'transactionID': 'order-1', 'value': 12.5, 'currency': 'USD'});
    expect(sent.last.customAttributes['campaign'], 'test');
  });

  test('object and JSON-string params both work', () async {
    expect(
        await tracker.submit(jsonEncode({
          'eventName': 'purchase',
          'params': jsonEncode({'orderId': 'encoded', 'amount': 5})
        })),
        H5TrackingResult.submitted);
    expect(sent.single.semanticAttributes['value'], 5);
  });

  test(
      'current H5 fields map correctly and alias IDs share the existing ledger',
      () async {
    await tracker.submit(message('register', {'user_id': 'user-1'}));
    expect(sent.last.customAttributes['user_id'], 'user-1');
    await tracker.submit(message('apply', {'product_id': 'p1', 'amount': 20}));
    expect(sent.last.semanticAttributes['value'], 20);
    await tracker.submit(message('purchase', {
      'transaction_id': 'tx-1',
      'revenue': 20,
      'currency': 'USD',
      'product_id': 'p1',
    }));
    expect(sent.last.semanticAttributes, {
      'transactionID': 'tx-1',
      'value': 20,
      'currency': 'USD',
      'products': [
        {'productID': 'p1'}
      ],
    });
    expect(await tracker.submit(message('purchase', {'orderId': 'tx-1'})),
        H5TrackingResult.duplicate);
    expect(
        await tracker.submit(message('purchase', {'transaction_id': 'tx-1'})),
        H5TrackingResult.duplicate);
    expect(sent.length, 3);
  });

  test('conflicting order aliases and null revenue are rejected', () async {
    expect(
        await tracker.submit(
            message('purchase', {'orderId': 'a', 'transaction_id': 'b'})),
        H5TrackingResult.invalid);
    expect(
        await tracker.submit(
            message('purchase', {'transaction_id': 'a', 'revenue': null})),
        H5TrackingResult.invalid);
    expect(sent, isEmpty);
  });

  test('concurrent duplicate purchase callbacks only hand off once', () async {
    final results = await Future.wait(List.generate(30,
        (_) => tracker.submit(message('purchase', {'orderId': 'same-order'}))));
    expect(results.where((r) => r == H5TrackingResult.submitted).length, 1);
    expect(results.where((r) => r == H5TrackingResult.duplicate).length, 29);
    expect(sent.length, 1);
  });

  test(
      'changed params cannot bypass order dedup, different orders still report',
      () async {
    await tracker.submit(message('purchase', {'orderId': 'one', 'value': 1}));
    expect(
        await tracker
            .submit(message('purchase', {'orderId': 'one', 'value': 99})),
        H5TrackingResult.duplicate);
    expect(
        await tracker
            .submit(message('purchase', {'orderId': 'two', 'value': 1})),
        H5TrackingResult.submitted);
    expect(sent.length, 2);
  });

  test('numeric order IDs and trimmed string IDs deduplicate consistently',
      () async {
    await tracker.submit(message('purchase', {'orderId': 123}));
    expect(await tracker.submit(message('purchase', {'orderId': ' 123 '})),
        H5TrackingResult.duplicate);
  });

  test(
      'persistent order reservation survives a recreated tracker and preferences',
      () async {
    await tracker.submit(message('purchase', {'orderId': 'persisted'}));
    final preferences = await SharedPreferences.getInstance();
    final disk = {
      for (final key in preferences.getKeys()) key: preferences.get(key)!
    };
    SharedPreferences.setMockInitialValues(disk);
    final restarted = H5EventTracker(isReady: () async => true, send: sent.add);
    expect(
        await restarted.submit(message('purchase', {'orderId': 'persisted'})),
        H5TrackingResult.duplicate);
    expect(sent.length, 1);
  });

  test('checkout dedup does not suppress purchase for the same order',
      () async {
    await tracker.submit(message('apply', {'orderId': 'one'}));
    expect(await tracker.submit(message('apply', {'orderId': 'one'})),
        H5TrackingResult.duplicate);
    expect(await tracker.submit(message('purchase', {'orderId': 'one'})),
        H5TrackingResult.submitted);
    expect(sent.length, 2);
  });

  test('invalid input is rejected and does not poison subsequent processing',
      () async {
    for (final value in [
      'not-json',
      '[]',
      message('unknown'),
      message('purchase'),
      message('purchase', {'orderId': ''}),
      message('purchase', {'orderId': true}),
      message('purchase', {'orderId': 1.2}),
      message('purchase', {'orderId': 9007199254740992}),
      message('purchase', {'orderId': 'x', 'value': 'NaN'}),
      message('purchase', {'orderId': 'x', 'currency': 'not-a-currency'}),
      jsonEncode({'eventName': 'purchase', 'params': []}),
      message('register', {'large': List.filled(65537, 'x').join()})
    ]) {
      expect(await tracker.submit(value), H5TrackingResult.invalid);
    }
    expect(sent, isEmpty);
    expect(await tracker.submit(message('purchase', {'orderId': 'x'})),
        H5TrackingResult.submitted);
  });

  test('disabled SDK does not reserve orders', () async {
    final disabled = H5EventTracker(isReady: () async => false, send: sent.add);
    expect(await disabled.submit(message('purchase', {'orderId': 'retry'})),
        H5TrackingResult.disabled);
    expect(await tracker.submit(message('purchase', {'orderId': 'retry'})),
        H5TrackingResult.submitted);
    expect(sent.length, 1);
  });

  test('failed persistence prevents unprotected purchase submission', () async {
    final broken = H5EventTracker(
        isReady: () async => true,
        preferences: () async => FailedWritePreferences(),
        send: sent.add);
    expect(await broken.submit(message('purchase', {'orderId': 'one'})),
        H5TrackingResult.failed);
    expect(sent, isEmpty);
  });

  test(
      'reservation happens before SDK call and remains after an ambiguous failure',
      () async {
    final preferences = await SharedPreferences.getInstance();
    final broken = H5EventTracker(
        isReady: () async => true,
        send: (event) {
          expect(preferences.getBool(event.deduplicationKey!), isTrue);
          throw StateError('SDK handoff failed');
        });
    expect(await broken.submit(message('purchase', {'orderId': 'one'})),
        H5TrackingResult.failed);
    expect(await tracker.submit(message('purchase', {'orderId': 'one'})),
        H5TrackingResult.duplicate);
    expect(sent, isEmpty);
  });

  test('public Flutter SDK receives exactly one standard Order Complete call',
      () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(
        WebViewBridge.channel, (_) async => true);
    messenger.setMockMethodCallHandler(sdkChannel, (call) async {
      calls.add(call);
      return null;
    });
    final realAdapter = H5EventTracker();
    await realAdapter.submit(message(
        'purchase', {'orderId': 'sdk-order', 'value': 10, 'currency': 'USD'}));
    await realAdapter.submit(message('purchase', {'orderId': 'sdk-order'}));
    await Future<void>.delayed(Duration.zero);
    expect(calls.length, 1);
    expect(calls.single.method, 'trackEvent');
    expect(calls.single.arguments['parameter']['category'],
        AirbridgeCategory.ORDER_COMPLETED);
    expect(
        calls.single.arguments['parameter']['semanticAttributes']
            ['transactionID'],
        'sdk-order');
  });
}
