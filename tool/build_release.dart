import 'dart:io';

// Run with: dart run tool/build_release.dart apk|appbundle|ipa [Flutter flags]
Future<void> main(List<String> args) async {
  if (args.isEmpty || !{'apk', 'appbundle', 'ipa'}.contains(args.first)) {
    stderr.writeln(
        'Usage: dart run tool/build_release.dart apk|appbundle|ipa [Flutter flags]');
    exitCode = 64;
    return;
  }
  if (args.first == 'ipa' && !Platform.isMacOS) {
    stderr.writeln('iOS releases require macOS and Xcode.');
    exitCode = 64;
    return;
  }
  if (args.skip(1).any((arg) =>
      arg == '--debug' ||
      arg == '--profile' ||
      arg == '--no-obfuscate' ||
      arg.startsWith('--split-debug-info'))) {
    stderr.writeln(
        'Release mode, obfuscation and symbol output are managed by this script.');
    exitCode = 64;
    return;
  }
  final root = File.fromUri(Platform.script).parent.parent.path;
  final buildId = DateTime.now().toUtc().microsecondsSinceEpoch;
  final symbols = 'release-symbols/${args.first}/$buildId';
  final process = await Process.start(
    Platform.isWindows ? 'flutter.bat' : 'flutter',
    [
      'build',
      args.first,
      ...args.skip(1),
      '--release',
      '--obfuscate',
      '--split-debug-info=$symbols'
    ],
    workingDirectory: root,
    runInShell: Platform.isWindows,
    mode: ProcessStartMode.inheritStdio,
  );
  exitCode = await process.exitCode;
  if (exitCode == 0) {
    stdout
        .writeln('Archive $symbols with this release for crash symbolication.');
  }
}
