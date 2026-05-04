import 'dart:io';

import 'package:isolate_manager_generator/isolate_manager_generator.dart';
import 'package:test/test.dart';

void main() {
  group('Main test', () {
    test('listDartFiles', () {
      final files = <File>[];
      final dartFiles = IsolateManagerGenerator.listDartFiles(
        Directory('test'),
        files,
      );

      expect(dartFiles.length, greaterThan(1));
    });

    test('resolveDartArgs prepends pubspec args before CLI args', () {
      final result = IsolateManagerGenerator.resolveDartArgs(
        {
          'dart-args': ['--no-source-maps', '--enable-asserts'],
        },
        ['--enable-asserts'],
      );

      expect(
        result,
        equals(['--no-source-maps', '--enable-asserts', '--enable-asserts']),
      );
    });

    test('resolveDartArgs falls back to pubspec config', () {
      final result = IsolateManagerGenerator.resolveDartArgs(
        {
          'dart-args': ['--no-source-maps'],
        },
        [],
      );

      expect(result, equals(['--no-source-maps']));
    });
  });
}
