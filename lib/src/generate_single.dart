import 'dart:io';

import 'package:args/args.dart';
import 'package:isolate_manager/isolate_manager.dart';
import 'package:isolate_manager_generator/src/model/exceptions.dart';
import 'package:isolate_manager_generator/src/utils.dart';
import 'package:path/path.dart' as p;

const constAnnotation = 'isolateManagerWorker';
const constCustomWorkerAnnotation = 'isolateManagerCustomWorker';
final _singlePattern = RegExp(
  '(@$constAnnotation|@$constCustomWorkerAnnotation)',
);

final sharedIsolates = IsolateManager.createShared(
  concurrent: Platform.numberOfProcessors,
);

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
  final isWorkerMappings = argResults['worker-mappings-experiment'] as String;
  final subPath = argResults['sub-path'] as String;

  print('Parsing the `IsolateManagerWorker` inside directory: $input...');

  final params = <List<dynamic>>[];

  await Future.wait(
    [
      for (final file in dartFiles)
        sharedIsolates
            .compute(checkAndCollectAnnotatedFiles, file)
            .then((value) {
          if (value.isNotEmpty) {
            params.add([
              value,
              obfuscate,
              isDebug,
              isWasm,
              output,
              dartArgs,
              isWorkerMappings,
              subPath,
            ]);
          }
        }),
    ],
  );

  print('Total files to generate: ${params.length}');

  int counter = 0;
  await Future.wait([
    for (final param in params)
      sharedIsolates
          .compute(getAndGenerateFromAnotatedFunctions, param)
          .then((value) => counter += value),
  ]);

  print('Total generated functions: $counter');

  await sharedIsolates.stop();
  print('Done');
}

Future<String> checkAndCollectAnnotatedFiles(File file) async {
  final filePath = p.absolute(file.path);
  final content = await file.readAsString();
  if (containsAnnotations(content)) {
    return filePath;
  }
  return '';
}

bool containsAnnotations(String content) {
  return content.contains(_singlePattern);
}

Future<int> getAndGenerateFromAnotatedFunctions(List<dynamic> params) async {
  final filePath = params[0] as String;

  final anotatedFunctions = await parseAnnotations(filePath, [
    constAnnotation,
    constCustomWorkerAnnotation,
  ]);

  final map = <String, bool>{};
  for (final entry in anotatedFunctions.entries) {
    if (entry.key == constAnnotation) {
      for (var functionName in entry.value) {
        map[functionName] = false;
      }
    } else if (entry.key == constCustomWorkerAnnotation) {
      for (var functionName in entry.value) {
        map[functionName] = true;
      }
    }
  }

  if (anotatedFunctions.isNotEmpty) {
    await generateFromAnotatedFunctions(params, map);
  }

  return anotatedFunctions.length;
}

Future<void> generateFromAnotatedFunctions(
  List<dynamic> params,
  Map<String, bool> anotatedFunctions,
) async {
  final sourceFilePath = params[0] as String;
  final isWorkerMappings = params[6] as String;
  final subPath = params[7] as String;

  await Future.wait(
    [
      for (final function in anotatedFunctions.entries)
        generateFromAnotatedFunction([
          params,
          function,
        ]),
    ],
  );

  for (final function in anotatedFunctions.entries) {
    if (isWorkerMappings.isNotEmpty) {
      printDebug(() => 'Generate the `workerMappings`...');
      await addWorkerMappingToSourceFile(
        isWorkerMappings,
        sourceFilePath,
        function.key,
        subPath,
      );

      printDebug(() => 'Done.');
    }
  }
}

Future<void> generateFromAnotatedFunction(List<dynamic> params) async {
  final sourceFilePath = params[0][0] as String;
  final obfuscate = params[0][1] as String;
  final isDebug = params[0][2] as bool;
  final isWasm = params[0][3] as bool;
  final output = params[0][4] as String;
  final dartArgs = params[0][5] as List<String>;
  final MapEntry<String, bool> function = params[1];

  final inputPath = p.absolute(
    p.join(
      p.dirname(sourceFilePath),
      '.IsolateManagerWorker.${function.key}.${function.hashCode}.dart',
    ),
  );
  final file = File(inputPath);
  final extension = isWasm ? 'wasm' : 'js';
  final name = function.key;
  final outputPath = p.join(output, '$name.$extension');
  final outputFile = File(outputPath);
  final backupOutputData =
      await outputFile.exists() ? await outputFile.readAsString() : '';

  try {
    final sink = file.openWrite();
    sink.writeln("import '${p.basename(sourceFilePath)}';");
    sink.writeln("import 'package:isolate_manager/isolate_manager.dart';");
    sink.writeln();
    sink.writeln('main() {');
    if (function.value) {
      sink.writeln(
        '  IsolateManagerFunction.customWorkerFunction(${function.key});',
      );
    } else {
      sink.writeln('  IsolateManagerFunction.workerFunction(${function.key});');
    }
    sink.writeln('}');
    await sink.close();

    if (await outputFile.exists()) {
      await outputFile.delete();
    }

    final dartPath = Platform.resolvedExecutable;
    if (dartPath.isEmpty) {
      throw IMGFileNotFoundException('Dart SDK not found');
    }

    final process = Process.run(
      dartPath,
      [
        'compile',
        extension,
        inputPath,
        '-o',
        outputPath,
        obfuscate,
        if (!isWasm) '--omit-implicit-checks',
        if (!isDebug && !isWasm) '--no-source-maps',
        ...dartArgs,
      ],
    );

    if (isDebug) {
      process.asStream().listen((data) {
        print(data.stdout);
      });
    }

    final result = await process;

    if (await outputFile.exists()) {
      print(
        'Path: ${p.relative(sourceFilePath)} => '
        'Function: ${function.key} => Compiled: ${p.relative(outputPath)}',
      );
      if (!isDebug) {
        if (isWasm) {
          await File(p.join(output, '$name.unopt.wasm')).delete();
        } else {
          await File(p.join(output, '$name.js.deps')).delete();
        }
      }
    } else {
      print(
        'Path: ${p.relative(sourceFilePath)} => Function: '
        '${function.key} => Compile ERROR: ${p.relative(outputPath)}',
      );
      final r = result.stdout.toString().split('\n');
      for (var element in r) {
        print('   > $element');
      }
      throw IMGCompileErrorException();
    }
  } catch (e) {
    // Restore the backup data if the compilation fails
    if (backupOutputData.isNotEmpty && !await outputFile.exists()) {
      await outputFile.writeAsString(backupOutputData);
    }
    rethrow;
  } finally {
    if (!isDebug && await file.exists()) {
      await file.delete();
    }
  }
}
