import 'dart:io';

import 'package:args/args.dart';
import 'package:isolate_manager/isolate_manager.dart';
import 'package:isolate_manager_generator/src/generate_shared.dart' as shared;
import 'package:isolate_manager_generator/src/generate_single.dart' as single;
import 'package:isolate_manager_generator/src/model/exceptions.dart';
import 'package:isolate_manager_generator/src/utils.dart';
import 'package:path/path.dart';

/// A utility class for generating isolate manager workers.
class IsolateManagerGenerator {
  /// Resolves effective dart args from CLI and pubspec config.
  ///
  /// Pubspec `dart-args` are prepended so CLI dart args keep higher priority.
  static List<String> resolveDartArgs(
    Map<String, dynamic>? pubspecConfig,
    List<String> cliDartArgs,
  ) {
    final dartArgs = <String>[];
    if (pubspecConfig != null && pubspecConfig.containsKey('dart-args')) {
      final pubspecDartArgs = pubspecConfig['dart-args'];
      if (pubspecDartArgs is List) {
        dartArgs.addAll(List<String>.from(pubspecDartArgs));
      }
    }

    dartArgs.addAll(cliDartArgs);
    return dartArgs;
  }

  /// Executes the isolate manager generator with the provided arguments.
  ///
  /// Takes a list of command-line arguments, processes them, and generates
  /// the appropriate worker files based on the configuration.
  ///
  /// Returns:
  ///   0: Success
  ///   1: Compilation error
  ///   2: Unable to resolve file
  ///   3: No main function found
  ///   4: Main function has no open braces
  ///   5: File not found
  static Future<int> execute(List<String> args) async {
    try {
      await _execute(args);
    } on IMGException catch (e) {
      printDebug(() => e.message);
      switch (e) {
        case IMGCompileErrorException():
          return 1;
        case IMGUnableToResolvingFileException():
          return 2;
        case IMGNoMainFunctionFoundException():
          return 3;
        case IMGMainFunctionHasNoOpenBracesException():
          return 4;
        case IMGFileNotFoundException():
          return 5;
      }
    }
    return 0;
  }

  static Future<void> _execute(List<String> args) async {
    final parsedArgs = parseArgs(args);

    // Read pubspec `isolate_manager` node and merge into main args when not
    // explicitly provided on CLI. CLI has precedence over pubspec values.
    final pubspecConfig = readPubspecConfig();
    final mainArgs = List<String>.from(parsedArgs.mainArgs);

    bool provided(List<String> list, String long, String? short) {
      return list.any((a) => a == '-$short' || a.startsWith('--$long'));
    }

    if (pubspecConfig != null) {
      // Flags: single, shared, wasm, debug
      if (pubspecConfig.containsKey('single') &&
          !provided(mainArgs, 'single', 's')) {
        if (pubspecConfig['single'] == true) {
          mainArgs.add('--single');
        } else {
          mainArgs.add('--no-single');
        }
      }
      if (pubspecConfig.containsKey('shared') &&
          !provided(mainArgs, 'shared', null)) {
        if (pubspecConfig['shared'] == true) {
          mainArgs.add('--shared');
        } else {
          mainArgs.add('--no-shared');
        }
      }
      if (pubspecConfig.containsKey('wasm') &&
          !provided(mainArgs, 'wasm', null) &&
          pubspecConfig['wasm'] == true) {
        mainArgs.add('--wasm');
      }
      if (pubspecConfig.containsKey('debug') &&
          !provided(mainArgs, 'debug', null) &&
          pubspecConfig['debug'] == true) {
        mainArgs.add('--debug');
      }

      // Options: input, output, shared-name, obfuscate,
      // sub-path, worker-mappings-experiment
      if (pubspecConfig.containsKey('input') &&
          !provided(mainArgs, 'input', 'i')) {
        mainArgs.add('--input=${pubspecConfig['input']}');
      }
      if (pubspecConfig.containsKey('output') &&
          !provided(mainArgs, 'output', 'o')) {
        mainArgs.add('--output=${pubspecConfig['output']}');
      }
      if (pubspecConfig.containsKey('shared-name') &&
          !provided(mainArgs, 'shared-name', null)) {
        mainArgs.add('--shared-name=${pubspecConfig['shared-name']}');
      }
      if (pubspecConfig.containsKey('obfuscate') &&
          !provided(mainArgs, 'obfuscate', null)) {
        mainArgs.add('--obfuscate=${pubspecConfig['obfuscate']}');
      }
      if (pubspecConfig.containsKey('sub-path') &&
          !provided(mainArgs, 'sub-path', null)) {
        mainArgs.add('--sub-path=${pubspecConfig['sub-path']}');
      }
      if (pubspecConfig.containsKey('worker-mappings-experiment') &&
          !provided(mainArgs, 'worker-mappings-experiment', null)) {
        mainArgs.add(
          '--worker-mappings-experiment='
          '${pubspecConfig['worker-mappings-experiment']}',
        );
      }
    }

    final dartArgs = resolveDartArgs(pubspecConfig, parsedArgs.dartArgs);

    final parser = ArgParser()
      ..addFlag(
        'single',
        help: 'Generate the single Workers',
      )
      ..addFlag(
        'shared',
        help: 'Generate the shared Workers',
      )
      ..addOption(
        'input',
        abbr: 'i',
        help: 'Path of the folder to generate the Workers',
        valueHelp: 'lib',
        defaultsTo: 'lib',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Path of the folder to save the generated files',
        valueHelp: 'web',
        defaultsTo: 'web',
      )
      ..addOption(
        'shared-name',
        valueHelp: kSharedWorkerName,
        defaultsTo: kSharedWorkerName,
        help: 'Name of the generated shared Worker',
        aliases: ['name'],
      )
      ..addOption(
        'obfuscate',
        valueHelp: '4',
        defaultsTo: '4',
        help: 'JS obfuscation level (0 to 4)',
      )
      ..addFlag(
        'debug',
        help:
            'Export the debug files (including the generated Worker files '
            'and the intermediate files)',
      )
      ..addFlag(
        'wasm',
        help: 'Compile to wasm',
      )
      ..addOption(
        'worker-mappings-experiment',
        defaultsTo: '',
        help:
            '[Experiment] Generate the `workerMappings` and add it to '
            'the `main` app automatically',
      )
      ..addFlag('help', abbr: 'h', help: 'Display this help message.')
      ..addOption(
        'sub-path',
        help:
            'Sub-path of the function name when generating the '
            'worker-mappings (applies only to single functions). '
            "It's different from the `output` path.",
        defaultsTo: '',
        aliases: ['sub-dir'],
      );

    final argResults = parser.parse(mainArgs);

    if (argResults['help'] as bool) {
      printDebug(() => parser.usage);
      return;
    }

    var isSingle = argResults['single'] as bool;
    var isShared = argResults['shared'] as bool;

    if (!isSingle && !isShared) {
      isSingle = true;
      isShared = true;
    }

    final input = argResults['input'] as String;
    final dir = Directory(input);
    if (!dir.existsSync()) {
      printDebug(() => 'The command run in the wrong directory.');
      return;
    }

    final dartFiles = listDartFiles(Directory(input), []);

    if (isSingle) {
      printDebug(() => '>> Generating the single Workers...');
      await single.generate(argResults, dartArgs, dartFiles);
      printDebug(() => '>> Generated.');
    }

    if (isShared) {
      printDebug(() => '>> Generating the shared Worker...');
      await shared.generate(argResults, dartArgs, dartFiles);
      printDebug(() => '>> Generated.');
    }
  }

  /// Lists all Dart files in the given directory and its subdirectories.
  static List<File> listDartFiles(
    Directory dir,
    List<File> fileList,
  ) {
    final files = dir.listSync(recursive: true);

    for (final file in files) {
      if (file is File && extension(file.path) == '.dart') {
        fileList.add(file);
      }
    }

    return fileList;
  }
}
