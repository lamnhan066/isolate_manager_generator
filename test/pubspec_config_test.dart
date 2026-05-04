import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'Uses pubspec isolate_manager node for defaults',
    () async {
      final tmp = await Directory.systemTemp.createTemp('img_pubspec_test');
      final repoRoot = Directory.current.path;
      try {
        // Write pubspec.yaml with isolate_manager node
        const pubspec = '''
name: temp_project

environment:
  sdk: '>=2.18.0 <4.0.0'

dependencies:
  isolate_manager: ^6.1.2

isolate_manager:
  input: lib
  output: out
  single: true
  shared: false
  dart-args:
    - --no-source-maps
''';
        await File(p.join(tmp.path, 'pubspec.yaml')).writeAsString(pubspec);

        // Fetch dependencies so the analyzer can resolve
        // `package:isolate_manager` imports
        final pubGet = await Process.run(
          Platform.resolvedExecutable,
          ['pub', 'get'],
          workingDirectory: tmp.path,
        );
        if (pubGet.exitCode != 0) {
          // Fail early with output for debugging
          throw Exception('pub get failed: ${pubGet.stdout}\n${pubGet.stderr}');
        }

        // Create lib/functions.dart (copied from test/functions.dart)
        final libDir = Directory(p.join(tmp.path, 'lib'))
          ..createSync(recursive: true);
        const functionsContent = r"""
// This is a test file for isolate_manager annotations.
// ignore_for_file: avoid_print

import 'package:isolate_manager/isolate_manager.dart';

@isolateManagerWorker
void myWorkerFunction(String message) {
  print(r'Received: $message');
}

void notAWorkerFunction() {
  print('Not a worker.');
}
""";
        await File(
          p.join(libDir.path, 'functions.dart'),
        ).writeAsString(functionsContent);

        final process = await Process.run(
          Platform.resolvedExecutable,
          ['run', p.join(repoRoot, 'bin', 'isolate_manager_generator.dart')],
          workingDirectory: tmp.path,
        );

        expect(
          process.exitCode,
          0,
          reason: 'stdout:\n${process.stdout}\nstderr:\n${process.stderr}',
        );

        final outDir = Directory(p.join(tmp.path, 'out'));
        final generated = File(p.join(outDir.path, 'myWorkerFunction.js'));
        expect(generated.existsSync(), isTrue);
      } finally {
        if (tmp.existsSync()) {
          tmp.deleteSync(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
