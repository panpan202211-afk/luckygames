// Run with Node.js: node test/airbridge_bridge_test.js
function runBridgeTests(source) {
  var install = new Function('window', 'Event', source);
  function setup() {
    var messages = [], events = [];
    var window = {
      LuckyAirbridgeEvents: {postMessage: function (m) { messages.push(JSON.parse(m)); }},
      dispatchEvent: function (event) { events.push(event.type); }
    };
    function Event(type) { this.type = type; }
    install(window, Event);
    return { window: window, messages: messages, events: events, Event: Event };
  }
  function assert(value, message) { if (!value) throw new Error(message); }
  var s = setup(), track = s.window.AndroidAirbridge.track;
  assert(track('register', {}) === true, 'register object');
  assert(track('apply', '{"orderId":"a"}') === true, 'apply JSON string');
  assert(track('purchase', {orderId: 'a', value: 10}) === true, 'purchase object');
  assert(s.messages.length === 3 && s.messages[2].params.orderId === 'a', 'payload forwarding');
  assert(!track('purchase', {}), 'missing orderId');
  assert(!track('purchase', {orderId: 9007199254740992}), 'unsafe numeric orderId');
  assert(!track('purchase', '{bad json}'), 'malformed JSON');
  assert(!track('purchase', []), 'array params');
  assert(!track('unknown', {}), 'unknown event');
  assert(!track('register', {data: 'x'.repeat(65537)}), 'oversized message');
  var cyclic = {}; cyclic.self = cyclic;
  assert(!track('register', cyclic), 'cyclic params');
  install(s.window, s.Event);
  assert(s.events.length === 1, 'idempotent injection');
  assert(track('purchase', {orderId: 'b'}), 'bridge still works after reinjection');
  var frame = setup();
  assert(frame.window.AndroidAirbridge.track('purchase', '{"orderId":"frame"}'), 'independent iframe context');
  delete frame.window.LuckyAirbridgeEvents;
  assert(!frame.window.AndroidAirbridge.track('register', {}), 'missing native channel');
  var current = setup(), trackEvent = current.window.AndroidAirbridge.trackEvent;
  assert(typeof trackEvent === 'function', 'H5 hasBridge detection');
  assert(trackEvent('register', JSON.stringify({user_id: 'u1'})) === 'ok', 'H5 register');
  assert(trackEvent('apply', JSON.stringify({product_id: 'p1', amount: 12})) === 'ok', 'H5 apply');
  assert(trackEvent('purchase', JSON.stringify({transaction_id: 'tx1', revenue: 12, currency: 'USD', product_id: 'p1'})) === 'ok', 'H5 purchase');
  assert(current.messages[2].params.transaction_id === 'tx1' && current.messages[2].params.revenue === 12, 'H5 payload preserved');
  assert(trackEvent('purchase', '{}') === 'invalid_order_id', 'H5 missing transaction');
  assert(trackEvent('purchase', '{bad}') === 'invalid_params', 'H5 invalid JSON status');
  assert(trackEvent('purchase', {orderId: 'a', transaction_id: 'b'}) === 'conflicting_order_id', 'alias conflict');
  assert(trackEvent('purchase', {transaction_id: 'a', revenue: null}) === 'invalid_value', 'NaN serialized as null');
  delete current.window.LuckyAirbridgeEvents;
  assert(trackEvent('register', '{}') === 'bridge_unavailable', 'no false ok without native bridge');
  var nativeCalls = [];
  var native = {
    trackEvent: function (name, json) { nativeCalls.push([name, JSON.parse(json)]); return 'ok'; },
    sdkStatus: function () { return 'initialized'; }
  };
  var android = {AndroidAirbridge: native, dispatchEvent: function () {}};
  assert(typeof android.AndroidAirbridge.trackEvent === 'function', 'native detection before script');
  install(android, s.Event);
  assert(android.AndroidAirbridge.trackEvent('register', '{}') === 'ok', 'native transport without plugin channel');
  assert(android.AndroidAirbridge.track('apply', {amount: 12}), 'legacy object through native transport');
  assert(nativeCalls.length === 2 && nativeCalls[1][1].amount === 12, 'one native submit per call');
  assert(android.AndroidAirbridge.sdkStatus() === 'initialized', 'native SDK status retained');
  var locked = {dispatchEvent: function () {}};
  Object.defineProperty(locked, 'AndroidAirbridge', {value: native, configurable: false});
  install(locked, s.Event);
  assert(locked.AndroidAirbridge.trackEvent('register', '{}') === 'ok', 'non-configurable native bridge retained');
  return '31 JavaScript bridge checks passed';
}
if (typeof module !== 'undefined' && require.main === module) {
  var fs = require('node:fs'), path = require('node:path');
  console.log(runBridgeTests(fs.readFileSync(path.join(__dirname, '../assets/airbridge_bridge.js'), 'utf8')));
}
