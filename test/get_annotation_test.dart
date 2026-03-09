import 'dart:io';

import 'package:isolate_manager_generator/src/utils.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  test('Get annotations test', () async {
    final annotations = await parseAnnotations(
      path.join('test', 'functions.dart'),
      [
        'isolateManagerWorker',
        'isolateManagerCustomWorker',
        'isolateManagerSharedWorker',
      ],
    );

    expect(
      annotations,
      equals({
        'isolateManagerWorker': [
          'myWorkerFunction',
          'myMultiWorkersFunction',
          'MyService.myWorkerMethod',
          'MyService.myMultiWorkersFunction',
        ],
        'isolateManagerCustomWorker': [
          'myCustomWorkerFunction',
          'myMultiWorkersFunction',
          'MyService.myCustomWorkerFunction',
          'MyService.myMultiWorkersFunction',
        ],
        'isolateManagerSharedWorker': [
          'mySharedWorkerFunction',
          'myMultiWorkersFunction',
          'MyService.mySharedWorkerFunction',
          'MyService.myMultiWorkersFunction',
        ],
      }),
    );
  });

  test('Generate js', () async {
    final outputDir = path.join('test', 'img_test_output');

    try {
      final process = await Process.run(
        Platform.resolvedExecutable,
        [
          'run',
          'isolate_manager_generator',
          '--input',
          'test',
          '--output',
          outputDir,
        ],
      );

      expect(
        process.stdout,
        contains(
          'Compiled: ${path.join(outputDir, 'myCustomWorkerFunction.js')}',
        ),
      );
      expect(
        process.stdout,
        contains(
          'Compiled: ${path.join(outputDir, 'MyService.myCustomWorkerFunction.js')}',
        ),
      );
      expect(
        process.stdout,
        contains(
          'Compiled: ${path.join(outputDir, 'myWorkerFunction.js')}',
        ),
      );
      expect(
        process.stdout,
        contains(
          'Compiled: ${path.join(outputDir, 'MyService.myWorkerMethod.js')}',
        ),
      );
      expect(
        process.stdout,
        contains(
          'Compiled: ${path.join(outputDir, 'myMultiWorkersFunction.js')}',
        ),
      );
      expect(
        process.stdout,
        contains(
          'Compiled: ${path.join(outputDir, 'MyService.myMultiWorkersFunction.js')}',
        ),
      );
      expect(
        process.stdout,
        isNot(
          contains(
            'Compiled: ${path.join(outputDir, 'notAWorkerFunction.js')}',
          ),
        ),
      );

      for (final fileName in [
        'myCustomWorkerFunction.js',
        'MyService.myCustomWorkerFunction.js',
        'myWorkerFunction.js',
        'MyService.myWorkerMethod.js',
        'myMultiWorkersFunction.js',
        'MyService.myMultiWorkersFunction.js',
      ]) {
        expect(File(path.join(outputDir, fileName)).existsSync(), isTrue);
      }
    } finally {
      if (Directory(outputDir).existsSync()) {
        Directory(outputDir).deleteSync(recursive: true);
      }
    }
  });
}
