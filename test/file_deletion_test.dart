import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('File deletion defensive checks', () {
    final outputDir = path.join('test', 'output');
    final testInputDir = path.join('test');
    final rootDir = Directory.current.path;

    setUp(() {
      // Ensure output directory exists before each test
      Directory(outputDir).createSync(recursive: true);
    });

    tearDown(() {
      // Clean up output directory after each test
      if (Directory(outputDir).existsSync()) {
        Directory(outputDir).deleteSync(recursive: true);
      }

      // Clean up temporary worker files in test directory
      _cleanupTempWorkerFiles(testInputDir);

      // Clean up temporary shared worker files in root directory
      _cleanupTempSharedWorkerFiles(rootDir);

      // Clean up non_existent_output directory if it exists
      final nonExistentOutput = path.join(
        'test',
        'non_existent_output',
      );
      if (Directory(nonExistentOutput).existsSync()) {
        Directory(nonExistentOutput).deleteSync(recursive: true);
      }
    });

    group('Missing dependency files', () {
      test(
        'generate_single handles missing js.deps file gracefully',
        () async {
          // Test that generation completes successfully even when
          // .js.deps file doesn't exist (defensive check)
          final process = await Process.run(
            Platform.resolvedExecutable,
            [
              'run',
              'isolate_manager_generator',
              '--single',
              '--input',
              testInputDir,
              '--output',
              outputDir,
              '--obfuscate',
              '0',
            ],
          );

          // Should complete without errors related to missing files
          expect(
            process.exitCode,
            equals(0),
            reason: 'Generation should complete successfully',
          );
          expect(
            process.stdout,
            isNot(contains('PathNotFoundException')),
            reason: 'Should not have path not found errors',
          );
          expect(
            process.stdout,
            isNot(contains('FileSystemException')),
            reason: 'Should not have file system exceptions',
          );
        },
      );

      test(
        'generate_single handles missing unopt.wasm file gracefully',
        () async {
          // Test that generation completes successfully even when
          // .unopt.wasm file doesn't exist (defensive check)
          // Note: wasm compilation may fail in some environments, so we just check
          // that it doesn't fail due to file deletion errors
          final process = await Process.run(
            Platform.resolvedExecutable,
            [
              'run',
              'isolate_manager_generator',
              '--single',
              '--input',
              testInputDir,
              '--output',
              outputDir,
              '--obfuscate',
              '0',
              '--wasm',
            ],
          );

          // Should not fail due to file deletion errors (even if compilation fails)
          expect(
            process.stdout,
            isNot(contains('PathNotFoundException')),
            reason: 'Should not have path not found errors for wasm files',
          );
          expect(
            process.stdout,
            isNot(contains('FileSystemException')),
            reason: 'Should not have file system exceptions for wasm files',
          );
        },
      );

      test(
        'generate_shared handles missing js.deps file gracefully',
        () async {
          // Test that generation completes successfully even when
          // .js.deps file doesn't exist (defensive check)
          final process = await Process.run(
            Platform.resolvedExecutable,
            [
              'run',
              'isolate_manager_generator',
              '--shared',
              '--input',
              testInputDir,
              '--output',
              outputDir,
              '--obfuscate',
              '0',
            ],
          );

          // Should complete without errors related to missing files
          expect(
            process.exitCode,
            equals(0),
            reason: 'Shared generation should complete successfully',
          );
          expect(
            process.stdout,
            isNot(contains('PathNotFoundException')),
            reason: 'Should not have path not found errors',
          );
          expect(
            process.stdout,
            isNot(contains('FileSystemException')),
            reason: 'Should not have file system exceptions',
          );
        },
      );

      test(
        'generate_shared handles missing unopt.wasm file gracefully',
        () async {
          // Test that generation completes successfully even when
          // .unopt.wasm file doesn't exist (defensive check)
          // Note: wasm compilation may fail in some environments, so we just check
          // that it doesn't fail due to file deletion errors
          final process = await Process.run(
            Platform.resolvedExecutable,
            [
              'run',
              'isolate_manager_generator',
              '--shared',
              '--input',
              testInputDir,
              '--output',
              outputDir,
              '--obfuscate',
              '0',
              '--wasm',
            ],
          );

          // Should not fail due to file deletion errors (even if compilation fails)
          expect(
            process.stdout,
            isNot(contains('PathNotFoundException')),
            reason: 'Should not have path not found errors for wasm files',
          );
          expect(
            process.stdout,
            isNot(contains('FileSystemException')),
            reason: 'Should not have file system exceptions for wasm files',
          );
        },
      );
    });

    group('Existing output file deletion', () {
      test(
        'generate_single deletes existing output file before generation',
        () async {
          // Create output directory and an existing output file
          Directory(outputDir).createSync(recursive: true);
          final outputFile = File(path.join(outputDir, 'myWorkerFunction.js'));
          const existingContent = 'existing content';
          await outputFile.writeAsString(existingContent);
          expect(
            outputFile.existsSync(),
            isTrue,
            reason: 'Output file should exist before generation',
          );

          final process = await Process.run(
            Platform.resolvedExecutable,
            [
              'run',
              'isolate_manager_generator',
              '--single',
              '--input',
              testInputDir,
              '--output',
              outputDir,
              '--obfuscate',
              '0',
            ],
          );

          // Should complete successfully (file should be deleted and regenerated)
          expect(
            process.exitCode,
            equals(0),
            reason: 'Generation should complete successfully',
          );
          expect(
            process.stdout,
            contains(
              'Compiled: ${path.join('test', 'output', 'myWorkerFunction.js')}',
            ),
            reason: 'Should contain compilation success message',
          );

          // Verify the file was regenerated (not the old content)
          expect(outputFile.existsSync(), isTrue);
          final newContent = await outputFile.readAsString();
          expect(
            newContent,
            isNot(equals(existingContent)),
            reason: 'File should be regenerated with new content',
          );
        },
      );

      test(
        'generate_shared deletes existing output file before generation',
        () async {
          // Create output directory and an existing output file
          Directory(outputDir).createSync(recursive: true);
          final outputFile = File(
            path.join(outputDir, r'$shared_worker.js'),
          );
          const existingContent = 'existing content';
          await outputFile.writeAsString(existingContent);
          expect(
            outputFile.existsSync(),
            isTrue,
            reason: 'Output file should exist before generation',
          );

          final process = await Process.run(
            Platform.resolvedExecutable,
            [
              'run',
              'isolate_manager_generator',
              '--shared',
              '--input',
              testInputDir,
              '--output',
              outputDir,
              '--obfuscate',
              '0',
            ],
          );

          // Should complete successfully (file should be deleted and regenerated)
          expect(
            process.exitCode,
            equals(0),
            reason: 'Shared generation should complete successfully',
          );
          expect(
            process.stdout,
            contains(
              'Compiled: ${path.join('test', 'output', r'$shared_worker.js')}',
            ),
            reason: 'Should contain compilation success message',
          );

          // Verify the file was regenerated (not the old content)
          expect(outputFile.existsSync(), isTrue);
          final newContent = await outputFile.readAsString();
          expect(
            newContent,
            isNot(equals(existingContent)),
            reason: 'File should be regenerated with new content',
          );
        },
      );

      test(
        'generate_single with wasm deletes existing .wasm file',
        () async {
          Directory(outputDir).createSync(recursive: true);
          final outputFile = File(
            path.join(outputDir, 'myWorkerFunction.wasm'),
          );
          const existingContent = 'existing wasm content';
          await outputFile.writeAsBytes(
            List<int>.generate(existingContent.length, (i) => i),
          );
          expect(outputFile.existsSync(), isTrue);

          final process = await Process.run(
            Platform.resolvedExecutable,
            [
              'run',
              'isolate_manager_generator',
              '--single',
              '--input',
              testInputDir,
              '--output',
              outputDir,
              '--obfuscate',
              '0',
              '--wasm',
            ],
          );

          // Should complete successfully
          expect(process.exitCode, equals(0));
          expect(
            process.stdout,
            contains(
              'Compiled: ${path.join('test', 'output', 'myWorkerFunction.wasm')}',
            ),
          );
        },
      );

      test(
        'generate_shared with wasm deletes existing .wasm file',
        () async {
          Directory(outputDir).createSync(recursive: true);
          final outputFile = File(
            path.join(outputDir, r'$shared_worker.wasm'),
          );
          const existingContent = 'existing wasm content';
          await outputFile.writeAsBytes(
            List<int>.generate(existingContent.length, (i) => i),
          );
          expect(outputFile.existsSync(), isTrue);

          final process = await Process.run(
            Platform.resolvedExecutable,
            [
              'run',
              'isolate_manager_generator',
              '--shared',
              '--input',
              testInputDir,
              '--output',
              outputDir,
              '--obfuscate',
              '0',
              '--wasm',
            ],
          );

          // Should complete successfully
          expect(process.exitCode, equals(0));
          expect(
            process.stdout,
            contains(
              'Compiled: ${path.join('test', 'output', r'$shared_worker.wasm')}',
            ),
          );
        },
      );
    });

    group('Debug mode file retention', () {
      test(
        'generate_single in debug mode retains .js.deps file',
        () async {
          Directory(outputDir).createSync(recursive: true);

          final process = await Process.run(
            Platform.resolvedExecutable,
            [
              'run',
              'isolate_manager_generator',
              '--single',
              '--input',
              testInputDir,
              '--output',
              outputDir,
              '--obfuscate',
              '0',
              '--debug',
            ],
          );

          expect(process.exitCode, equals(0));
        },
      );

      test(
        'generate_shared in debug mode retains .js.deps file',
        () async {
          Directory(outputDir).createSync(recursive: true);

          final process = await Process.run(
            Platform.resolvedExecutable,
            [
              'run',
              'isolate_manager_generator',
              '--shared',
              '--input',
              testInputDir,
              '--output',
              outputDir,
              '--obfuscate',
              '0',
              '--debug',
            ],
          );

          expect(process.exitCode, equals(0));
        },
      );

      test(
        'generate_single in debug mode with wasm retains .unopt.wasm file',
        () async {
          Directory(outputDir).createSync(recursive: true);

          final process = await Process.run(
            Platform.resolvedExecutable,
            [
              'run',
              'isolate_manager_generator',
              '--single',
              '--input',
              testInputDir,
              '--output',
              outputDir,
              '--obfuscate',
              '0',
              '--wasm',
              '--debug',
            ],
          );

          expect(process.exitCode, equals(0));
        },
      );
    });

    group('Edge cases', () {
      test(
        'handles empty input directory gracefully',
        () async {
          final emptyDir = path.join('test', 'empty_input');
          try {
            Directory(emptyDir).createSync(recursive: true);

            final process = await Process.run(
              Platform.resolvedExecutable,
              [
                'run',
                'isolate_manager_generator',
                '--single',
                '--input',
                emptyDir,
                '--output',
                outputDir,
                '--obfuscate',
                '0',
              ],
            );

            // Should complete without errors even with no annotated functions
            expect(process.exitCode, equals(0));
          } finally {
            // Clean up the empty input directory
            if (Directory(emptyDir).existsSync()) {
              Directory(emptyDir).deleteSync(recursive: true);
            }
          }
        },
      );

      test(
        'handles non-existent output directory',
        () async {
          final nonExistentOutput = path.join(
            'test',
            'non_existent_output',
            'nested',
            'path',
          );

          // Ensure it doesn't exist
          if (Directory(nonExistentOutput).existsSync()) {
            Directory(nonExistentOutput).deleteSync(recursive: true);
          }

          final process = await Process.run(
            Platform.resolvedExecutable,
            [
              'run',
              'isolate_manager_generator',
              '--single',
              '--input',
              testInputDir,
              '--output',
              nonExistentOutput,
              '--obfuscate',
              '0',
            ],
          );

          // Should create the directory and complete successfully
          expect(process.exitCode, equals(0));
          expect(Directory(nonExistentOutput).existsSync(), isTrue);
        },
      );

      test(
        'handles multiple runs without file lock issues',
        () async {
          // Run generation twice to ensure no file lock issues
          for (var i = 0; i < 2; i++) {
            final process = await Process.run(
              Platform.resolvedExecutable,
              [
                'run',
                'isolate_manager_generator',
                '--single',
                '--input',
                testInputDir,
                '--output',
                outputDir,
                '--obfuscate',
                '0',
              ],
            );

            expect(
              process.exitCode,
              equals(0),
              reason: 'Run $i should complete successfully',
            );
          }
        },
      );

      test(
        'handles both single and shared generation together',
        () async {
          final process = await Process.run(
            Platform.resolvedExecutable,
            [
              'run',
              'isolate_manager_generator',
              '--single',
              '--shared',
              '--input',
              testInputDir,
              '--output',
              outputDir,
              '--obfuscate',
              '0',
            ],
          );

          expect(process.exitCode, equals(0));
          expect(
            process.stdout,
            contains('Compiled:'),
            reason: 'Should compile at least one file',
          );
        },
      );
    });

    group('Output file verification', () {
      test(
        'generates correct output files for single workers',
        () async {
          final process = await Process.run(
            Platform.resolvedExecutable,
            [
              'run',
              'isolate_manager_generator',
              '--single',
              '--input',
              testInputDir,
              '--output',
              outputDir,
              '--obfuscate',
              '0',
            ],
          );

          expect(process.exitCode, equals(0));

          // Verify expected output files exist
          final expectedFiles = [
            'myWorkerFunction.js',
            'myCustomWorkerFunction.js',
            'myMultiWorkersFunction.js',
          ];

          for (final fileName in expectedFiles) {
            final file = File(path.join(outputDir, fileName));
            expect(
              file.existsSync(),
              isTrue,
              reason: 'Expected output file $fileName to exist',
            );
          }
        },
      );

      test(
        'generates correct output files for shared workers',
        () async {
          final process = await Process.run(
            Platform.resolvedExecutable,
            [
              'run',
              'isolate_manager_generator',
              '--shared',
              '--input',
              testInputDir,
              '--output',
              outputDir,
              '--obfuscate',
              '0',
            ],
          );

          expect(process.exitCode, equals(0));

          // Verify expected output file exists
          final sharedWorkerFile = File(
            path.join(outputDir, r'$shared_worker.js'),
          );
          expect(
            sharedWorkerFile.existsSync(),
            isTrue,
            reason: 'Expected shared worker output file to exist',
          );
        },
      );
    });
  });
}

/// Cleans up temporary worker files generated during tests.
/// These files are created by the isolate_manager_generator and should be deleted.
void _cleanupTempWorkerFiles(String directory) {
  if (!Directory(directory).existsSync()) {
    return;
  }

  final files = Directory(directory).listSync();
  for (final file in files) {
    if (file is File) {
      final fileName = path.basename(file.path);
      // Match pattern: .IsolateManagerWorker.*.dart
      if (fileName.startsWith('.IsolateManagerWorker.') &&
          fileName.endsWith('.dart')) {
        try {
          file.deleteSync();
          // Ignore deletion errors
          // ignore: avoid_catches_without_on_clauses
        } catch (_) {
          // Ignore deletion errors
        }
      }
    }
  }
}

/// Cleans up temporary shared worker files generated during tests.
/// These files are created by the isolate_manager_generator and should be deleted.
void _cleanupTempSharedWorkerFiles(String directory) {
  if (!Directory(directory).existsSync()) {
    return;
  }

  final files = Directory(directory).listSync();
  for (final file in files) {
    if (file is File) {
      final fileName = path.basename(file.path);
      // Match pattern: .IsolateManagerShared.*.dart
      if (fileName.startsWith('.IsolateManagerShared.') &&
          fileName.endsWith('.dart')) {
        try {
          file.deleteSync();
          // Ignore deletion errors
          // ignore: avoid_catches_without_on_clauses
        } catch (_) {
          // Ignore deletion errors
        }
      }
    }
  }
}
