# Lucky Games

A colorful match-3 game built with Flutter:

- 3 difficulty maps with 10 levels each: Easy, Hard, and Hell
- 5 unique candy designs
- Animated swaps, matches, cascades, and combos
- Moves, 10x target scores, stars, and persistent level progression
- Distinct map mechanics: power combos, breakable ice, and a star bomb timer

## Run locally

启动时请求隐私接口：`code=0` 显示游戏，`code=1` 显示返回 `url` 的整页 H5（HTTPS，无原生标题栏）。支持数字及字符串 code。网络错误、未知 code 或 H5 地址无效时显示重试；不会自动进入游戏。

接口地址在 `lib/privacy_api.dart` 中按字节混淆并在运行时还原，不再作为完整明文字符串保存。这是可逆混淆，不能防止运行时逆向或隐藏网络连接的域名；传输使用 HTTPS 和系统证书校验，不包含客户端私钥，不跳过证书验证，不接受接口重定向或明文 HTTP 页面。

### H5 相册、外部 App 与 iframe

- Android 的 `<input type="file" accept="image/*">` 使用系统照片选择器（Android 13+），旧版或其他文件类型使用系统文档选择器；支持 `multiple`，取消选择返回空列表。iOS 保留 WKWebView 原生相册/文件选择流程。H5 请使用文件输入框，不使用 `capture` 或 `getUserMedia` 请求相机。
- App 不新增相册、存储、相机、麦克风权限，不新增 App 查询白名单。选文件仅能读取用户选中的内容，不提供遍历整个相册的能力。
- `weixin://`、`alipays://`、`tel:` 等自定义协议交给系统打开目标 App；Android 同时支持 `intent://`，仅采用其目标 URI 和包名，不转发任意组件或附加授权。未安装时提示用户；主页面的 Android intent 可回退到经过校验的 HTTPS `browser_fallback_url`。普通 HTTPS 链接继续在 WebView 中打开。
- 支持 HTTPS iframe、`about:blank`/`srcdoc`、iframe 内 blob/data 文档；子框架不会被强制加载为整个页面，子框架错误也不会遮挡父页面。Android 开启第三方 Cookie 以兼容 iframe 登录，并补充子框架内 App scheme 跳转。很旧的 Android System WebView 若缺少 `GET_WEB_VIEW_CLIENT` 能力，仍能显示 iframe，但需更新系统 WebView 才能处理 iframe 内的 App scheme。
- iframe 仍遵循站点的 `X-Frame-Options`、CSP `frame-ancestors`、`sandbox`、Cookie SameSite 和 iOS WebKit 隐私规则；不绕过网站的嵌入限制，不开放 HTTP 混合内容。

真机验收：分别在主页面、同源与跨域 iframe 中测试图片单选/多选/取消、文件上传、已安装/未安装 App 的 scheme、`target="_blank"` 链接、iframe 登录；iOS 需在 macOS/Xcode 构建后验证。

参考：[Android 系统文件选择](https://developer.android.com/guide/topics/providers/document-provider)、[Apple 直接打开外部 URL](https://developer.apple.com/documentation/uikit/uiapplication/open(_:options:completionhandler:))。

### 混淆发布

将 Flutter 和 Dart 加入 PATH 后，在项目根目录执行：

```bash
dart run tool/build_release.dart apk
dart run tool/build_release.dart appbundle
# macOS + Xcode:
dart run tool/build_release.dart ipa
```

脚本为 Android/iOS 的 Dart 代码添加 `--release --obfuscate --split-debug-info`。Android release 另开启 R8 代码混淆和资源压缩。iOS 此处混淆的是 Dart 代码，不包含 Swift/Objective-C 类名重写。直接使用普通 `flutter build` 不会自动启用 Dart 混淆，请使用上述脚本。

每次构建的 Dart 符号保存在独立的 `release-symbols/<target>/<build-id>/`，请与发布包一起私下归档；Android 另保留 `build/app/outputs/mapping/release/mapping.txt`，iOS 保留 Xcode archive/dSYM。符号文件不提交 Git，也不要放入应用资源。

参考：[Flutter 混淆说明](https://docs.flutter.dev/deployment/obfuscate)、[Android R8 配置](https://developer.android.com/topic/performance/app-optimization/enable-app-optimization)。

```bash
flutter run
```

Flutter is installed at `D:\SDK\flutter` and added to the user PATH. Open a new terminal before using the `flutter` command.

On Windows, double-click `run_web.bat` to preview the game in Chrome. Building the iOS version requires macOS with Xcode.

## Airbridge attribution

### H5 事件桥接

当前 H5 的 `window.AndroidAirbridge.trackEvent(eventName, JSON.stringify(params))` 也已在 Android/iOS 共用桥中支持，原 `track(...)` 布尔返回接口继续保留。例如：

```javascript
window.AndroidAirbridge.trackEvent('purchase', JSON.stringify({
  transaction_id: 'ORDER-001', revenue: 19.99, currency: 'USD', product_id: 'product-1'
}));
```

`transaction_id` 与原 `orderId` 共用同一持久化去重记录，切换字段不会重复提交。两字段同时存在时必须一致。`revenue` 映射到收入 `value`，`product_id` 映射到 `products[].productID`，`user_id` 保留为事件自定义属性（不会自动切换 SDK 用户身份）。金额字段优先级为 `value`、`revenue`、`amount`。

`trackEvent` 同步返回字符串：`ok` 表示消息已交给桥通道排队，其他值如 `invalid_event`、`invalid_params`、`invalid_order_id`、`conflicting_order_id`、`invalid_value`、`invalid_currency`、`bridge_unavailable` 表示前置检查失败。iOS WKWebView 原生通信异步，`ok` 不代表原生去重通过或 Airbridge 上报成功；H5 日志建议改成“桥接消息已提交”，重复订单仍可能返回 `ok`，随后由原生侧去重。属性访问必须写 `window.AndroidAirbridge`，不要写 `window\.AndroidAirbridge`。

Android 和 iOS 的 H5 使用同一个接口，`params` 支持普通 JSON 对象或 JSON 字符串：

```javascript
AndroidAirbridge.track('register', { source: 'signup_page' });
AndroidAirbridge.track('apply', { orderId: 'ORDER-001', value: 19.99, currency: 'USD' });
// 仅在业务确认支付成功后调用；orderId 必须是稳定的唯一订单号。
AndroidAirbridge.track('purchase', { orderId: 'ORDER-001', value: 19.99, currency: 'USD' });
```

| H5 eventName | Airbridge 标准事件 | SDK category |
| --- | --- | --- |
| `register` | Sign-up | `airbridge.user.signup` |
| `apply` | Initiate Checkout | `airbridge.initiateCheckout` |
| `purchase` | Order Complete | `airbridge.ecommerce.order.completed` |

`orderId` 会映射到 Airbridge 的 `transactionID`；`value`（也兼容 `amount`）、`currency`、`products`、`totalQuantity`、`action`、`label` 作为语义属性，其他字段作为自定义属性。货币代码使用三位字母。金额按货币单位传递，例如 19.99 美元传 `19.99`。长订单号请用字符串，避免 JavaScript 数字精度丢失。

桥接脚本通过 Android document-start API / iOS WKUserScript 在网页执行前注入，覆盖主页面和 iframe，页面刷新后仍有效。极旧的 Android System WebView 不支持 document-start 时，会在主页面生命周期回调中补充注入；此时早期脚本和跨域 iframe 需更新系统 WebView，或让 H5 在业务脚本前加载 `assets/airbridge_bridge.js`（前提是 `LuckyAirbridgeEvents` 原生通道存在）。桥接就绪会触发 `window` 上的 `AndroidAirbridgeReady` 事件。

**去重规则：** `purchase` 必须有非空 `transaction_id` 或 `orderId`，同一订单只向 SDK 提交一次；带订单号的 `apply` 也按订单去重，但与 `purchase` 分开计算。无订单号的 `apply`、`register` 按每次调用提交。所有页面和 iframe 共用一个串行队列；订单标记保存在 SharedPreferences，刷新、重建 WebView、正常重启后仍保留，无时间过期。SDK 未配置或禁用时不会占用订单标记；持久化失败时不提交购买事件。

去重优先采用“保存标记后提交 SDK”：保存后若崩溃或 SDK 接收失败，该订单不会自动重报，以免重复计数。`track` 返回 `true` 只表示消息已交给原生通道，不是服务端回执；非法格式/未知事件/缺少购买订单号返回 `false`。客户端去重不能覆盖清除应用数据、其他设备、Web SDK 或服务端的独立上报。在 App 内，这三个业务事件只调用本桥，不要再同时调用 Airbridge Web SDK 或另一套原生埋点。

测试：`flutter test`；纯 JavaScript 桥接测试可运行 `node test/airbridge_bridge_test.js`。还需用真实 H5 和 Airbridge 实时日志做真机联调；单元测试不发送真实归因事件。

标准事件参考：[Airbridge Flutter SDK](https://help.airbridge.io/en/developers/flutter-sdk-v4)、[标准事件分类](https://help.airbridge.io/en/developers/airbridge-event)。

The official Airbridge Flutter SDK is configured from the root-level `airbridge.json` file. On iOS 14 and later, the app requests App Tracking Transparency permission and does not initialize or start Airbridge unless the user grants permission. On older iOS versions and Android, platform-specific startup behavior applies.

Set the credentials from Airbridge Dashboard **Settings > Tokens**:

```json
{
  "appName": "YOUR_AIRBRIDGE_APP_NAME",
  "appToken": "YOUR_AIRBRIDGE_APP_SDK_TOKEN",
  "autoStartTrackingEnabled": false
}
```

Use the **App SDK Token**, not an Airbridge API token. Placeholder or empty credentials safely disable attribution until configured.

Gighub

git add .
git commit -m "1.0.11"
git push
