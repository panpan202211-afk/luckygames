import 'dart:convert';

import 'package:http/http.dart' as http;

// Reversible string obfuscation, not a secret or a cryptographic key.
// Do not replace this with a plaintext dart-define in release builds.
String get privacyPolicyEndpoint {
  const bytes = <int>[
    59,
    4,
    249,
    218,
    180,
    222,
    46,
    49,
    87,
    45,
    22,
    249,
    214,
    226,
    143,
    115,
    77,
    46,
    36,
    29,
    246,
    217,
    180,
    157,
    56,
    30,
    112,
    76,
    28,
    243,
    212,
    249,
    146,
    96,
    68,
    101,
    23,
    246,
    200,
    200,
    186,
    155,
    108
  ];
  return String.fromCharCodes([
    for (var i = 0; i < bytes.length; i++) bytes[i] ^ ((0x53 + i * 29) & 0xff),
  ]);
}

Uri requireHttpsUrl(Object? value) {
  final uri = value is String ? Uri.tryParse(value) : null;
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw const FormatException('Expected a valid HTTPS URL.');
  }
  return uri;
}

class PrivacyResult {
  const PrivacyResult({required this.code, this.url});

  final int code;
  final Uri? url;

  factory PrivacyResult.parse(String body) {
    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid privacy response.');
    }
    final code = switch (json['code']) {
      0 || '0' => 0,
      1 || '1' => 1,
      _ => throw const FormatException('Unknown privacy code.'),
    };
    // A policy URL is optional in game mode, mandatory in H5 mode.
    final value = json['url'];
    Uri? url;
    if (code == 1) {
      url = requireHttpsUrl(value);
    } else if (value is String && value.isNotEmpty) {
      // An unusable policy link must not prevent code=0 from opening the game.
      try {
        url = requireHttpsUrl(value);
      } on FormatException {
        url = null;
      }
    }
    return PrivacyResult(code: code, url: url);
  }
}

Future<PrivacyResult> fetchPrivacyResult(http.Client client) async {
  final request = http.Request('GET', requireHttpsUrl(privacyPolicyEndpoint))
    ..followRedirects = false
    ..headers['Accept'] = 'application/json';
  final response = await (() async {
    final stream = await client.send(request);
    return http.Response.fromStream(stream);
  })()
      .timeout(const Duration(seconds: 15));
  if (response.statusCode != 200) {
    throw http.ClientException('Privacy service unavailable.');
  }
  return PrivacyResult.parse(utf8.decode(response.bodyBytes));
}
