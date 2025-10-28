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
    final process = await Process.run(
      Platform.resolvedExecutable,
      [
        'run',
        'isolate_manager_generator',
        '--input',
        'test',
        '--output',
        path.join('test', 'output'),
      ],
    );

    expect(
      process.stdout,
      contains(
        'Compiled: ${path.join('test', 'output', 'myCustomWorkerFunction.js')}',
      ),
    );
    expect(
      process.stdout,
      contains(
        'Compiled: ${path.join('test', 'output', 'MyService.myCustomWorkerFunction.js')}',
      ),
    );
    expect(
      process.stdout,
      contains(
        'Compiled: ${path.join('test', 'output', 'myWorkerFunction.js')}',
      ),
    );
    expect(
      process.stdout,
      contains(
        'Compiled: ${path.join('test', 'output', 'MyService.myWorkerMethod.js')}',
      ),
    );
    expect(
      process.stdout,
      contains(
        'Compiled: ${path.join('test', 'output', 'myMultiWorkersFunction.js')}',
      ),
    );
    expect(
      process.stdout,
      contains(
        'Compiled: ${path.join('test', 'output', 'MyService.myMultiWorkersFunction.js')}',
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
      expect(File(path.join('test', 'output', fileName)).existsSync(), isTrue);
    }

    Directory(path.join('test', 'output')).deleteSync(recursive: true);
  });
}
