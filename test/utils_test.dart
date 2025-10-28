import 'dart:io';

import 'package:isolate_manager_generator/src/model/exceptions.dart';
import 'package:isolate_manager_generator/src/utils.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('printDebug', () {
    test('prints message', () {
      expect(
        () => printDebug(() => 'debug message'),
        prints('debug message\n'),
      );
    });

    test('handles null message', () {
      expect(() => printDebug(() => null), prints('null\n'));
    });
  });

  group('readFileLines', () {
    late Directory tempDir;
    late String tempFilePath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('test_utils_');
      tempFilePath = p.join(tempDir.path, 'test.txt');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('throws exception if file does not exist', () async {
      expect(
        () async => readFileLines('non_existent_file.txt'),
        throwsA(
          isA<IMGFileNotFoundException>().having(
            (e) => e.filePath,
            'path',
            'non_existent_file.txt',
          ),
        ),
      );
    });

    test('reads file content as lines', () async {
      final file = File(tempFilePath);
      await file.writeAsString('line1\nline2\nline3');

      expect(
        await readFileLines(tempFilePath),
        equals(['line1', 'line2', 'line3']),
      );
    });

    test('handles empty file', () async {
      final file = File(tempFilePath);
      await file.writeAsString('');

      expect(await readFileLines(tempFilePath), isEmpty);
    });
  });

  group('writeFile', () {
    late Directory tempDir;
    late String tempFilePath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('test_utils_');
      tempFilePath = p.join(tempDir.path, 'test.txt');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('writes content to file with newline', () async {
      await writeFile(tempFilePath, ['line1', 'line2', 'line3']);

      final content = await File(tempFilePath).readAsString();
      expect(content, equals('line1\nline2\nline3\n'));
    });

    test('handles empty content', () async {
      await writeFile(tempFilePath, []);

      final content = await File(tempFilePath).readAsString();
      expect(content, equals('\n'));
    });

    test('overwrites existing file', () async {
      final file = File(tempFilePath);
      await file.writeAsString('original content');

      await writeFile(tempFilePath, ['new content']);

      final content = await File(tempFilePath).readAsString();
      expect(content, equals('new content\n'));
    });
  });

  group('addImportStatements', () {
    test('adds isolate_manager import when not present', () {
      final content = ['import "dart:io";', 'void main() {}'];
      final result = addImportStatements(
        content,
        'lib/src/file.dart',
        'lib/main.dart',
      );

      expect(
        result,
        contains("import 'package:isolate_manager/isolate_manager.dart';"),
      );
    });

    test('does not add duplicate isolate_manager import', () {
      final content = [
        'import "dart:io";',
        "import 'package:isolate_manager/isolate_manager.dart';",
        'void main() {}',
      ];
      final result = addImportStatements(
        content,
        'lib/src/file.dart',
        'lib/main.dart',
      );

      expect(
        result
            .where(
              (l) =>
                  l == "import 'package:isolate_manager/isolate_manager.dart';",
            )
            .length,
        equals(1),
      );
    });

    test('adds source file import when necessary', () {
      final content = ['import "dart:io";', 'void main() {}'];
      final result = addImportStatements(
        content,
        'lib/src/worker.dart',
        'lib/main.dart',
      );

      expect(result, contains("import 'src/worker.dart';"));
    });

    test('does not add source file import when source is main', () {
      final content = ['import "dart:io";', 'void main() {}'];
      final result = addImportStatements(
        content,
        p.absolute('lib/main.dart'),
        p.absolute('lib/main.dart'),
      );

      expect(result.any((l) => l.contains("import 'main.dart';")), isFalse);
    });

    test('handles content with no imports', () {
      final content = ['void main() {}'];
      final result = addImportStatements(
        content,
        'lib/src/file.dart',
        'lib/main.dart',
      );

      expect(
        result[0],
        equals("import 'package:isolate_manager/isolate_manager.dart';"),
      );
    });

    test('preserves order of existing imports', () {
      final content = [
        'import "dart:io";',
        'import "dart:async";',
        'void main() {}',
      ];
      final result = addImportStatements(
        content,
        'lib/src/file.dart',
        'lib/main.dart',
      );

      expect(result[0], equals('import "dart:io";'));
      expect(result[1], equals('import "dart:async";'));
      expect(
        result[2],
        equals("import 'package:isolate_manager/isolate_manager.dart';"),
      );
    });

    test('relative import from `lib`', () {
      final content = ['import "dart:io";', 'void main() {}'];
      const sourceFilePath = 'lib/src/worker.dart';
      const mainPath = 'lib/main.dart';

      final result = addImportStatements(content, sourceFilePath, mainPath);

      expect(result.contains("import 'src/worker.dart';"), isTrue);
      expect(result.contains("import '../src/worker.dart';"), isFalse);
    });

    test('relative import from non-lib directory', () {
      final content = ['import "dart:io";', 'void main() {}'];
      const sourceFilePath = 'lib/src/worker.dart';
      const mainPath = 'lib/pages/main.dart';

      final result = addImportStatements(content, sourceFilePath, mainPath);

      expect(result.contains("import '../src/worker.dart';"), isTrue);
    });

    test('does not add source file import when already present', () {
      final content = [
        'import "dart:io";',
        "import 'src/worker.dart';",
        'void main() {}',
      ];
      final result = addImportStatements(
        content,
        'lib/src/worker.dart',
        'lib/main.dart',
      );

      expect(
        result.where((l) => l.contains("import 'src/worker.dart';")).length,
        equals(1),
      );
    });
  });

  group('addWorkerMappingsCall', () {
    test('adds call to _addWorkerMappings in main function', () {
      final content = ['void main() {', '  print("hello");', '}'];
      final result = addWorkerMappingsCall(content);

      expect(result[1], equals('  _addWorkerMappings();'));
    });

    test('does not add duplicate call', () {
      final content = [
        'void main() {',
        '  _addWorkerMappings();',
        '  print("hello");',
        '}',
      ];
      final result = addWorkerMappingsCall(content);

      expect(
        result.where((l) => l.contains('_addWorkerMappings();')).length,
        equals(1),
      );
    });

    test('handles multi-line main function declaration', () {
      final content = ['void main(', '  ) {', '  print("hello");', '}'];
      final result = addWorkerMappingsCall(content);

      expect(result[2], equals('  _addWorkerMappings();'));
    });

    test('throws error if no main function found', () async {
      final content = ['class MyClass {}'];

      expect(
        () => addWorkerMappingsCall(content),
        throwsA(
          isA<IMGNoMainFunctionFoundException>(),
        ),
      );
    });

    test('throw error if no open braces in main function', () {
      final content = ['void main()'];

      expect(
        () => addWorkerMappingsCall(content),
        throwsA(
          isA<IMGMainFunctionHasNoOpenBracesException>(),
        ),
      );
    });

    test('handles main function with arguments', () {
      final content = [
        'void main(List<String> args) {',
        '  print("hello");',
        '}',
      ];
      final result = addWorkerMappingsCall(content);

      expect(result[1], equals('  _addWorkerMappings();'));
    });

    test('handles async main function', () {
      final content = ['Future<void> main() async {', '  print("hello");', '}'];
      final result = addWorkerMappingsCall(content);

      expect(result[1], equals('  _addWorkerMappings();'));
    });
  });

  group('addOrUpdateWorkerMappingsFunction', () {
    test('adds new worker mappings function if none exists', () {
      final content = ['void main() {}'];
      final result = addOrUpdateWorkerMappingsFunction(
        content,
        'myFunction',
        'subDir',
      );

      expect(result, contains('void _addWorkerMappings() {'));
      expect(
        result,
        contains(
          "  IsolateManager.addWorkerMapping(myFunction, 'subDir/myFunction');",
        ),
      );
    });

    test('updates existing empty worker mappings function', () {
      final content = ['void main() {}', 'void _addWorkerMappings() {}'];
      final result = addOrUpdateWorkerMappingsFunction(
        content,
        'myFunction',
        '',
      );

      expect(
        result.join('\n'),
        contains(
          "void _addWorkerMappings() {\n  IsolateManager.addWorkerMapping(myFunction, 'myFunction');",
        ),
      );
    });

    test('adds to existing worker mappings function', () {
      final content = [
        'void main() {}',
        'void _addWorkerMappings() {',
        "  IsolateManager.addWorkerMapping(existingFunction, 'existingFunction');",
        '}',
      ];
      final result = addOrUpdateWorkerMappingsFunction(
        content,
        'myFunction',
        '',
      );

      expect(
        result,
        contains(
          "  IsolateManager.addWorkerMapping(myFunction, 'myFunction');",
        ),
      );
      expect(
        result,
        contains(
          "  IsolateManager.addWorkerMapping(existingFunction, 'existingFunction');",
        ),
      );
    });

    test('does not add duplicate mapping', () {
      final content = [
        'void main() {}',
        'void _addWorkerMappings() {',
        "  IsolateManager.addWorkerMapping(myFunction, 'myFunction');",
        '}',
      ];
      final result = addOrUpdateWorkerMappingsFunction(
        content,
        'myFunction',
        '',
      );

      expect(result.where((l) => l.contains("'myFunction'")).length, equals(1));
    });

    test('does not add duplicate mapping with available subDir', () {
      final content = [
        'void main() {}',
        'void _addWorkerMappings() {',
        "  IsolateManager.addWorkerMapping(myFunction, 'workers/myFunction');",
        '}',
      ];
      final result = addOrUpdateWorkerMappingsFunction(
        content,
        'myFunction',
        'workers',
      );

      expect(
        result.where((l) => l.contains("'workers/myFunction'")).length,
        equals(1),
      );
    });

    test('handles function with double quotes', () {
      final content = [
        'void main() {}',
        'void _addWorkerMappings() {',
        '  IsolateManager.addWorkerMapping(existingFunction, "existingFunction");',
        '}',
      ];
      final result = addOrUpdateWorkerMappingsFunction(
        content,
        'myFunction',
        '',
      );

      expect(
        result,
        contains(
          "  IsolateManager.addWorkerMapping(myFunction, 'myFunction');",
        ),
      );
    });

    test('preserves comments in existing function', () {
      final content = [
        'void main() {}',
        'void _addWorkerMappings() {',
        '  // Add worker mappings here',
        "  IsolateManager.addWorkerMapping(existingFunction, 'existingFunction');",
        '}',
      ];
      final result = addOrUpdateWorkerMappingsFunction(
        content,
        'myFunction',
        '',
      );

      expect(result, contains('  // Add worker mappings here'));
    });

    test('adds correct documentation comments to new function', () {
      final content = ['void main() {}'];
      final result = addOrUpdateWorkerMappingsFunction(
        content,
        'myFunction',
        '',
      );

      expect(
        result,
        contains(
          '/// This method MUST be stored at the end of the file to avoid',
        ),
      );
      expect(result, contains('/// issues when generating.'));
    });
  });

  group('addWorkerMappingToSourceFile integration', () {
    late Directory tempDir;
    late String tempMainPath;
    late String tempSourcePath;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('test_utils_');
      tempMainPath = p.join(tempDir.path, 'main.dart');
      tempSourcePath = p.join(tempDir.path, 'source.dart');

      await File(tempMainPath).writeAsString('void main() {\n}\n');
      await File(tempSourcePath).writeAsString('void worker() {}\n');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('integrates all required changes', () async {
      await addWorkerMappingToSourceFile(
        tempMainPath,
        tempSourcePath,
        'worker',
        'sub_path',
      );

      final content = await File(tempMainPath).readAsLines();
      expect(
        content,
        contains("import 'package:isolate_manager/isolate_manager.dart';"),
      );
      expect(content, contains("import 'source.dart';"));
      expect(content, contains('  _addWorkerMappings();'));
      expect(
        content,
        contains(
          "  IsolateManager.addWorkerMapping(worker, 'sub_path/worker');",
        ),
      );
    });
  });

  group('parseArgs', () {
    test('returns empty lists for empty input', () {
      final parsed = parseArgs([]);

      expect(parsed.mainArgs, isEmpty);
      expect(parsed.dartArgs, isEmpty);
    });

    test('splits args at "--" separator', () {
      final result = parseArgs(['arg1', 'arg2', '--', 'dart1', 'dart2']);
      expect(result.mainArgs, equals(['arg1', 'arg2']));
      expect(result.dartArgs, equals(['dart1', 'dart2']));
    });

    test('handles no separator', () {
      final result = parseArgs(['arg1', 'arg2']);
      expect(result.mainArgs, equals(['arg1', 'arg2']));
      expect(result.dartArgs, isEmpty);
    });

    test('handles separator at start', () {
      final result = parseArgs(['--', 'dart1', 'dart2']);
      expect(result.mainArgs, isEmpty);
      expect(result.dartArgs, equals(['dart1', 'dart2']));
    });

    test('handles separator at end', () {
      final result = parseArgs(['arg1', 'arg2', '--']);
      expect(result.mainArgs, equals(['arg1', 'arg2']));
      expect(result.dartArgs, isEmpty);
    });

    test('handles multiple separators (uses first one)', () {
      final result = parseArgs(['arg1', '--', 'dart1', '--', 'dart2']);
      expect(result.mainArgs, equals(['arg1']));
      expect(result.dartArgs, equals(['dart1', '--', 'dart2']));
    });
  });
}
