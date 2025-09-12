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

  print('Parsing the `IsolateManagerWorker` inside directory: $input...');

  final sharedIsolates = IsolateManager.createShared(
    concurrent: Platform.numberOfProcessors,
  );

  final params = <List<dynamic>>[];

  await Future.wait([
    for (final file in dartFiles)
      sharedIsolates.compute(checkAndCollectAnnotatedFiles, file).then((value) {
        if (value.isNotEmpty) {
          params.add([value]);
        }
      }),
  ]);

  print('Total files to generate: ${params.length}');

  final anotatedFunctions = <String, String>{};
  int counter = 0;
  await Future.wait(
    [
      for (final param in params)
        sharedIsolates
            .compute(getAndGenerateFromAnotatedFunctions, param)
            .then((value) {
          counter += value.length;
          anotatedFunctions.addAll(value);
        }),
    ],
  );

  if (anotatedFunctions.isNotEmpty) {
    await generateFromAnotatedFunctions(
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

  print('Total generated functions: $counter');

  await sharedIsolates.stop();
  print('Done');
}

Future<String> checkAndCollectAnnotatedFiles(File file) async {
  final filePath = p.absolute(file.path);
  final content = file.readAsStringSync();
  if (containsAnnotations(content)) {
    return filePath;
  }
  return '';
}

bool containsAnnotations(String content) {
  return content.contains(_sharedAnnotations);
}

Future<Map<String, String>> getAndGenerateFromAnotatedFunctions(
  List<dynamic> params,
) async {
  final String filePath = params[0];

  return getAnotatedFunctions(filePath);
}

Future<Map<String, String>> getAnotatedFunctions(String path) async {
  final annotations = await parseAnnotations(path, [_constAnnotation]);
  final relativePath = p.relative(path);

  final annotatedFunctions = <String, String>{};
  for (final entry in annotations.entries) {
    for (var functionName in entry.value) {
      annotatedFunctions[functionName] = relativePath;
    }
  }

  return annotatedFunctions;
}

Future<void> generateFromAnotatedFunctions(
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
      await outputFile.exists() ? await outputFile.readAsString() : '';

  try {
    final sink = file.openWrite();
    sink.writeln("import 'package:isolate_manager/isolate_manager.dart';");
    for (final function in anotatedFunctions.entries) {
      final path = p.relative(function.value);
      sink.writeln("import '${path.replaceAll(p.separator, '/')}';");
    }
    sink.writeln('final Map<String, Function> map = {');
    for (final function in anotatedFunctions.entries) {
      sink.writeln("'${function.key}' : ${function.key},");
    }
    sink.writeln('};');
    sink.writeln('main() {');
    sink.writeln('  IsolateManagerFunction.sharedWorkerFunction(map);');
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
        print(data.stdout);
      });
    }

    final result = await process;

    if (await outputFile.exists()) {
      print('Compiled: ${p.relative(outputPath)}');
      if (!isDebug) {
        if (isWasm) {
          await File(p.join(output, '$name.unopt.wasm')).delete();
        } else {
          await File(p.join(output, '$name.js.deps')).delete();
        }
      }
    } else {
      print('Compile ERROR: ${p.relative(outputPath)}');
      final r = result.stdout.toString().split('\n');
      for (var element in r) {
        print('   > $element');
      }
      throw IMGCompileErrorException();
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
    if (backupOutputData.isNotEmpty && !await outputFile.exists()) {
      await outputFile.writeAsString(backupOutputData);
    }
    rethrow;
  } finally {
    if (!isDebug) {
      await file.delete();
    }
  }
}
