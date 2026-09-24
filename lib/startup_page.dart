import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'privacy_api.dart';
import 'privacy_policy_page.dart';

class StartupPage extends StatefulWidget {
  const StartupPage(
      {super.key, required this.gameBuilder, this.loader, this.webBuilder});

  final WidgetBuilder gameBuilder;
  final Future<PrivacyResult> Function()? loader;
  final Widget Function(Uri)? webBuilder;

  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage> {
  final _client = http.Client();
  late Future<PrivacyResult> _result;

  @override
  void initState() {
    super.initState();
    _result = _load();
  }

  Future<PrivacyResult> _load() async => widget.loader != null
      ? await widget.loader!()
      : await fetchPrivacyResult(_client);

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<PrivacyResult>(
        future: _result,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Scaffold(
                body: Center(
                    child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Unable to connect. Please try again.'),
                const SizedBox(height: 16),
                FilledButton(
                    onPressed: () {
                      final next = _load();
                      setState(() {
                        _result = next;
                      });
                    },
                    child: const Text('RETRY')),
              ],
            )));
          }
          final result = snapshot.requireData;
          if (result.code == 0) return widget.gameBuilder(context);
          return widget.webBuilder?.call(result.url!) ??
              PrivacyPolicyPage(initialUrl: result.url, fullPage: true);
        },
      );
}
