import 'dart:io';

import 'package:args/args.dart';
import 'package:isolate_manager/isolate_manager.dart';
import 'package:isolate_manager_generator/src/model/exceptions.dart';
import 'package:isolate_manager_generator/src/utils.dart';
import 'package:path/path.dart' as p;

const _constAnnotation = 'isolateManagerSharedWorker';
final _sharedAnnotations = RegExp('@$_constAnnotation');

/// --path "path/to/generate" --obfuscate 0->4 --debug
Future<void> generate(
  ArgResults argResults,
  List<String> dartArgs,
  List<File> dartFiles,
) async {
  final input = argResults['input'] as String;
  final output = argResults['output'] as String;
  final obfuscate = switch (argResults['obfuscate']) {
    '0' => '-O0',
    '1' => '-O1',
    '2' => '-O2',
    '3' => '-O3',
    '4' => '-O4',
    _ => '-O4',
  };
  final isDebug = argResults['debug'] as bool? ?? false;
  final isWasm = argResults['wasm'] as bool? ?? false;
  final name = argResults['shared-name'] as String;
  final isWorkerMappings = argResults['worker-mappings-experiment'] as String;
  final subDir = argResults['sub-path'] as String;

  printDebug(
      () => 'Parsing the `IsolateManagerWorker` inside directory: $input...');

  final sharedIsolates = IsolateManager.createShared(
    concurrent: Platform.numberOfProcessors,
  );

  final params = <List<dynamic>>[];

  await Future.wait([
    for (final file in dartFiles)
      sharedIsolates
          .compute(_checkAndCollectAnnotatedFiles, file)
          .then((value) {
        if (value.isNotEmpty) {
          params.add([value]);
        }
      }),
  ]);

  printDebug(() => 'Total files to generate: ${params.length}');

  final anotatedFunctions = <String, String>{};
  var counter = 0;
  await Future.wait(
    [
      for (final param in params)
        sharedIsolates
            .compute(_getAndGenerateFromAnotatedFunctions, param)
            .then((value) {
          counter += value.length;
          anotatedFunctions.addAll(value);
        }),
    ],
  );

  if (anotatedFunctions.isNotEmpty) {
    await _generateFromAnnotatedFunctions(
      anotatedFunctions,
      obfuscate,
      isDebug,
      isWasm,
      output,
      name,
      dartArgs,
      isWorkerMappings,
      subDir,
    );
  }

  printDebug(() => 'Total generated functions: $counter');

  await sharedIsolates.stop();
  printDebug(() => 'Done');
}

Future<String> _checkAndCollectAnnotatedFiles(File file) async {
  final filePath = p.absolute(file.path);
  final content = file.readAsStringSync();
  if (_containsAnnotations(content)) {
    return filePath;
  }
  return '';
}

bool _containsAnnotations(String content) {
  return content.contains(_sharedAnnotations);
}

Future<Map<String, String>> _getAndGenerateFromAnotatedFunctions(
  List<dynamic> params,
) async {
  final filePath = params[0] as String;

  return _getAnnotatedFunctions(filePath);
}

Future<Map<String, String>> _getAnnotatedFunctions(String path) async {
  final annotations = await parseAnnotations(path, [_constAnnotation]);
  final relativePath = p.relative(path);

  final annotatedFunctions = <String, String>{};
  for (final entry in annotations.entries) {
    for (final functionName in entry.value) {
      annotatedFunctions[functionName] = relativePath;
    }
  }

  return annotatedFunctions;
}

Future<void> _generateFromAnnotatedFunctions(
  Map<String, String> anotatedFunctions,
  String obfuscate,
  bool isDebug,
  bool isWasm,
  String output,
  String name,
  List<String> dartArgs,
  String workerMappingsPath,
  String subPath,
) async {
  final file = File(p.join(
      p.current, '.IsolateManagerShared.${anotatedFunctions.hashCode}.dart'));
  final extension = isWasm ? 'wasm' : 'js';
  final outputPath = p.join(output, '$name.$extension');
  final outputFile = File(outputPath);
  final backupOutputData =
      outputFile.existsSync() ? await outputFile.readAsString() : '';

  try {
    final sink = file.openWrite()
      ..writeln("import 'package:isolate_manager/isolate_manager.dart';");
    for (final function in anotatedFunctions.entries) {
      final path = p.relative(function.value);
      sink.writeln("import '${path.replaceAll(p.separator, '/')}';");
    }
    sink.writeln('final Map<String, Function> map = {');
    for (final function in anotatedFunctions.entries) {
      sink.writeln("'${function.key}' : ${function.key},");
    }
    sink
      ..writeln('};')
      ..writeln('main() {')
      ..writeln('  IsolateManagerFunction.sharedWorkerFunction(map);')
      ..writeln('}');
    await sink.close();

    if (outputFile.existsSync()) {
      await outputFile.delete();
    }

    final dartPath = Platform.resolvedExecutable;
    if (dartPath.isEmpty) {
      throw const IMGFileNotFoundException('Dart SDK not found');
    }

    final process = Process.run(
      dartPath,
      [
        'compile',
        extension,
        p.normalize(file.path),
        '-o',
        p.normalize(outputPath),
        obfuscate,
        if (!isWasm) '--omit-implicit-checks',
        if (!isDebug && !isWasm) '--no-source-maps',
        ...dartArgs,
      ],
    );

    if (isDebug) {
      process.asStream().listen((data) {
        printDebug(() => data.stdout);
      });
    }

    final result = await process;

    if (outputFile.existsSync()) {
      printDebug(() => 'Compiled: ${p.relative(outputPath)}');
      if (!isDebug) {
        if (isWasm) {
          await File(p.join(output, '$name.unopt.wasm')).delete();
        } else {
          await File(p.join(output, '$name.js.deps')).delete();
        }
      }
    } else {
      printDebug(() => 'Compile ERROR: ${p.relative(outputPath)}');
      final r = result.stdout.toString().split('\n');
      for (final element in r) {
        printDebug(() => '   > $element');
      }
      throw const IMGCompileErrorException();
    }

    if (workerMappingsPath.isNotEmpty) {
      printDebug(() => 'Generate the `workerMappings`...');
      for (final function in anotatedFunctions.entries) {
        await addWorkerMappingToSourceFile(
          workerMappingsPath,
          p.absolute(function.value),
          function.key,
          subPath,
        );
      }
      printDebug(() => 'Done.');
    }
  } catch (e) {
    // Restore the backup data if the compilation fails
    if (backupOutputData.isNotEmpty && !outputFile.existsSync()) {
      await outputFile.writeAsString(backupOutputData);
    }
    rethrow;
  } finally {
    if (!isDebug) {
      await file.delete();
    }
  }
}
