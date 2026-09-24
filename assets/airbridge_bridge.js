(function () {
  'use strict';
  if (window.AndroidAirbridge && window.AndroidAirbridge.__luckyBridge === 1) return;
  var nativeBridge = window.AndroidAirbridge;

  function trackEvent(eventName, params) {
    try {
      if (['register', 'apply', 'purchase'].indexOf(eventName) < 0) return 'invalid_event';
      if (typeof params === 'string') params = JSON.parse(params);
      if (params == null) params = {};
      if (typeof params !== 'object' || Array.isArray(params)) return 'invalid_params';
      function normalizeId(id) {
        if (typeof id === 'string' && id.trim().length > 0 && id.trim().length <= 256) return id.trim();
        if (typeof id === 'number' && Number.isSafeInteger(id)) return String(id);
        return null;
      }
      var id = params.orderId == null ? params.transaction_id : params.orderId;
      if ((id != null || eventName === 'purchase') && normalizeId(id) === null) return 'invalid_order_id';
      if (params.orderId != null && params.transaction_id != null &&
          normalizeId(params.orderId) !== normalizeId(params.transaction_id)) return 'conflicting_order_id';
      var amount = params.value != null ? params.value :
        (params.revenue != null ? params.revenue : params.amount);
      if (['value', 'revenue', 'amount'].some(function (key) { return key in params; }) &&
          (amount == null || (typeof amount !== 'number' && typeof amount !== 'string') ||
           String(amount).trim() === '' || !Number.isFinite(Number(amount)) || Number(amount) < 0)) return 'invalid_value';
      if ('currency' in params && (typeof params.currency !== 'string' ||
          !/^[A-Za-z]{3}$/.test(params.currency))) return 'invalid_currency';
      var message = JSON.stringify({ eventName: eventName, params: params });
      if (message.length > 65536) return 'invalid_params';
      if (nativeBridge && typeof nativeBridge.trackEvent === 'function') {
        return nativeBridge.trackEvent(eventName, JSON.stringify(params));
      }
      if (!window.LuckyAirbridgeEvents || typeof window.LuckyAirbridgeEvents.postMessage !== 'function') return 'bridge_unavailable';
      window.LuckyAirbridgeEvents.postMessage(message);
      // WKWebView messaging is asynchronous. This acknowledges enqueueing only,
      // not native deduplication, SDK acceptance or server delivery.
      return 'ok';
    } catch (_) {
      return 'invalid_params';
    }
  }

  var bridge = {
    __luckyBridge: 1,
    // true only means queued for native validation, not delivery to Airbridge.
    trackEvent: trackEvent,
    sdkStatus: function () {
      return nativeBridge && typeof nativeBridge.sdkStatus === 'function'
        ? nativeBridge.sdkStatus() : 'unknown';
    },
    track: function (eventName, params) { return trackEvent(eventName, params) === 'ok'; }
  };
  // Some WebViews expose the Java object as non-configurable. In that case
  // retain the native trackEvent API; never abort page initialization.
  try {
    Object.defineProperty(window, 'AndroidAirbridge', {
      value: Object.freeze(bridge), writable: false, configurable: false, enumerable: true
    });
  } catch (_) {
    if (!nativeBridge || typeof nativeBridge.trackEvent !== 'function') throw _;
  }
  window.dispatchEvent(new Event('AndroidAirbridgeReady'));
})();
