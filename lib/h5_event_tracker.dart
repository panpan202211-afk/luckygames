import 'dart:async';
import 'dart:convert';

import 'package:airbridge_flutter_sdk/airbridge_flutter_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'webview_bridge.dart';

enum H5TrackingResult { submitted, duplicate, invalid, disabled, failed }

class H5TrackingEvent {
  H5TrackingEvent._(this.name, this.category, this.orderId,
      this.semanticAttributes, this.customAttributes);

  final String name;
  final String category;
  final String? orderId;
  final Map<String, dynamic> semanticAttributes;
  final Map<String, dynamic> customAttributes;

  static const categories = {
    'register': AirbridgeCategory.SIGN_UP,
    'apply': AirbridgeCategory.INITIATE_CHECKOUT,
    'purchase': AirbridgeCategory.ORDER_COMPLETED,
  };

  factory H5TrackingEvent.parse(String message) {
    if (message.length > 65536) throw const FormatException('Event too large.');
    final json = jsonDecode(message);
    if (json is! Map<String, dynamic> ||
        !categories.containsKey(json['eventName'])) {
      throw const FormatException('Unknown event.');
    }
    final name = json['eventName'] as String;
    var params = json['params'] ?? <String, dynamic>{};
    if (params is String) params = jsonDecode(params);
    if (params is! Map<String, dynamic>) {
      throw const FormatException('Invalid params.');
    }
    final id = params['orderId'] ?? params['transaction_id'];
    final String? orderId;
    if (id == null) {
      orderId = null;
    } else if (id is String &&
        id.trim().isNotEmpty &&
        id.trim().length <= 256) {
      orderId = id.trim();
    } else if (id is int && id.abs() <= 9007199254740991) {
      orderId = id.toString();
    } else {
      throw const FormatException('Invalid orderId.');
    }
    if (name == 'purchase' && orderId == null) {
      throw const FormatException('Purchase requires orderId.');
    }
    if (params['orderId'] != null &&
        params['transaction_id'] != null &&
        params['orderId'].toString().trim() !=
            params['transaction_id'].toString().trim()) {
      throw const FormatException('Conflicting order IDs.');
    }

    final custom = Map<String, dynamic>.from(params);
    final semantic = <String, dynamic>{};
    // The H5 contract uses flat params; other JSON fields remain custom attributes.
    for (final key in [
      AirbridgeAttribute.CURRENCY,
      AirbridgeAttribute.PRODUCTS,
      AirbridgeAttribute.TOTAL_QUANTITY,
      AirbridgeAttribute.ACTION,
      AirbridgeAttribute.LABEL
    ]) {
      if (custom.containsKey(key)) semantic[key] = custom.remove(key);
    }
    final hasValue = ['value', 'revenue', 'amount'].any(params.containsKey);
    final rawValue = custom.remove('value') ??
        custom.remove('revenue') ??
        custom.remove('amount');
    if (hasValue) {
      final value =
          rawValue is num ? rawValue : num.tryParse(rawValue.toString());
      if (value == null || !value.isFinite || value < 0) {
        throw const FormatException('Invalid value.');
      }
      semantic[AirbridgeAttribute.VALUE] = value;
    }
    if (semantic.containsKey(AirbridgeAttribute.CURRENCY)) {
      final currency = semantic[AirbridgeAttribute.CURRENCY];
      if (currency is! String || !RegExp(r'^[A-Za-z]{3}$').hasMatch(currency)) {
        throw const FormatException('Invalid currency.');
      }
      semantic[AirbridgeAttribute.CURRENCY] = currency.toUpperCase();
    }
    if (orderId != null) semantic[AirbridgeAttribute.TRANSACTION_ID] = orderId;
    if (!semantic.containsKey(AirbridgeAttribute.PRODUCTS) &&
        params['product_id'] != null) {
      semantic[AirbridgeAttribute.PRODUCTS] = [
        {AirbridgeAttribute.PRODUCT_ID: params['product_id'].toString()},
      ];
    }
    return H5TrackingEvent._(
        name, categories[name]!, orderId, semantic, custom);
  }

  // Different event types for the same order are distinct: checkout must not
  // suppress the subsequent completed purchase. No TTL that permits old repeats.
  String? get deduplicationKey =>
      orderId != null && (name == 'purchase' || name == 'apply')
          ? 'h5_airbridge_v1.$name.${base64Url.encode(utf8.encode(orderId!))}'
          : null;
}

class H5EventTracker {
  H5EventTracker({
    Future<SharedPreferences> Function()? preferences,
    Future<bool> Function()? isReady,
    void Function(H5TrackingEvent)? send,
  })  : _preferences = preferences ?? SharedPreferences.getInstance,
        _isReady = isReady ?? WebViewBridge.isAirbridgeReady,
        _send = send ?? _sendToAirbridge;

  // One queue for all WebViews and frames in the app's Flutter engine.
  static final instance = H5EventTracker();
  final Future<SharedPreferences> Function() _preferences;
  final Future<bool> Function() _isReady;
  final void Function(H5TrackingEvent) _send;
  Future<void> _tail = Future.value();

  Future<H5TrackingResult> submit(String message) {
    final task = _tail.then((_) async {
      try {
        final event = H5TrackingEvent.parse(message);
        if (!await _isReady()) return H5TrackingResult.disabled;
        final key = event.deduplicationKey;
        if (key != null) {
          final preferences = await _preferences();
          if (preferences.getBool(key) == true) {
            return H5TrackingResult.duplicate;
          }
          // Reserve BEFORE handing off to the SDK. Prefer no duplicate purchase
          // over replay after an ambiguous crash/delivery failure.
          if (!await preferences.setBool(key, true)) {
            return H5TrackingResult.failed;
          }
        }
        _send(event);
        return H5TrackingResult.submitted;
      } on FormatException {
        return H5TrackingResult.invalid;
      } catch (_) {
        return H5TrackingResult.failed;
      }
    });
    _tail = task.then((_) {});
    return task;
  }

  static void _sendToAirbridge(H5TrackingEvent event) {
    // SDK 4.10's public tracking API is void and exposes no delivery receipt.
    // Catch asynchronous platform errors without causing WebView/app failures.
    runZonedGuarded(() {
      Airbridge.trackEvent(
        category: event.category,
        semanticAttributes: event.semanticAttributes,
        customAttributes: event.customAttributes,
      );
    }, (_, __) => debugPrint('Airbridge event handoff failed.'));
  }
}
