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
  });
}
