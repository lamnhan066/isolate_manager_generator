import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:isolate_manager_generator/src/model/exceptions.dart';
import 'package:path/path.dart' as p;

/// Prints debug information if in debug mode
void printDebug(Object? Function() log) {
  // Print the log message
  // ignore: avoid_print
  print(log());
}

/// Reads the content of a file and returns it as a list of lines
Future<List<String>> readFileLines(String path) async {
  final file = File(path);
  if (!file.existsSync()) {
    throw IMGFileNotFoundException(path);
  }
  return file.readAsLines();
}

/// Writes content to a file
Future<void> writeFile(String path, List<String> content) async {
  final file = File(path);
  await file.writeAsString('${content.join('\n')}\n');
}

/// Adds import statements to content if they don't already exist
List<String> addImportStatements(
  List<String> content,
  String sourceFilePath,
  String mainPath,
) {
  final result = List<String>.from(content);
  var lastImportIndex = -1;
  for (var i = 0; i < result.length; i++) {
    if (result[i].startsWith('import ')) {
      lastImportIndex = i;
    }
  }

  const newImportLine =
      "import 'package:isolate_manager/isolate_manager.dart';";
  if (!result.contains(newImportLine)) {
    result.insert(++lastImportIndex, newImportLine);
  }

  final newFunctionSourceImport = p.relative(sourceFilePath, from: 'lib');
  final newFunctionSourceImportRelativeFromMain =
      p.relative(sourceFilePath, from: p.dirname(mainPath));

  // Convert paths to use forward slashes for import statements
  final platformIndependentSourceImport =
      newFunctionSourceImport.replaceAll(p.separator, '/');
  final platformIndependentSourceImportRelative =
      newFunctionSourceImportRelativeFromMain.replaceAll(p.separator, '/');

  final containsSourceImport =
      result.any((line) => line.contains(platformIndependentSourceImport));
  final containsSourceImportRelativeFromMain = result
      .any((line) => line.contains(platformIndependentSourceImportRelative));

  if (p.absolute(sourceFilePath) != mainPath &&
      !containsSourceImport &&
      !containsSourceImportRelativeFromMain) {
    result.insert(++lastImportIndex,
        "import '$platformIndependentSourceImportRelative';");
  }

  return result;
}

/// Adds the worker mappings call to the main function
List<String> addWorkerMappingsCall(List<String> content) {
  final result = List<String>.from(content);
  var mainIndex = -1;
  for (var i = 0; i < result.length; i++) {
    if (result[i].contains('void main(') ||
        result[i].contains('Future<void> main(')) {
      mainIndex = i;
      break;
    }
  }

  if (mainIndex == -1) {
    throw const IMGNoMainFunctionFoundException();
  }

  var insertionIndex = mainIndex;
  while (insertionIndex < result.length &&
      !result[insertionIndex].trim().endsWith('{')) {
    insertionIndex++;
  }

  if (insertionIndex == result.length) {
    throw const IMGMainFunctionHasNoOpenBracesException();
  }

  const addWorkerMappingsCall = '  _addWorkerMappings();';
  if (!result.any((line) => line.contains('_addWorkerMappings();'))) {
    result.insert(insertionIndex + 1, addWorkerMappingsCall);
  }

  return result;
}

/// Adds or updates the _addWorkerMappings function
List<String> addOrUpdateWorkerMappingsFunction(
  List<String> content,
  String functionName,
  String subPath,
) {
  final result = List<String>.from(content);
  // We don't need to set the right separator here, the `IsolateManager.addWorkerMapping`
  // method will handle it.
  final functionPath = subPath == '' ? functionName : '$subPath/$functionName';
  final newWorkerMappingLine =
      "  IsolateManager.addWorkerMapping($functionName, '$functionPath');";

  final addWorkerMappingsIndex = result.indexWhere((line) =>
      line.replaceAll(' ', '').startsWith('void_addWorkerMappings()'));

  if (addWorkerMappingsIndex == -1) {
    // Add new function
    result
      ..add('')
      ..add('/// This method MUST be stored at the end of the file to avoid')
      ..add('/// issues when generating.')
      ..add('void _addWorkerMappings() {')
      ..add(newWorkerMappingLine)
      ..add('}')
      ..add('');
  } else {
    // Update existing function
    final containsFunctionPath = result.any(
        (line) => line.contains(RegExp('(\'$functionPath\'|"$functionPath")')));

    if (!containsFunctionPath) {
      final line = result[addWorkerMappingsIndex].replaceAll(' ', '');
      if (line.startsWith('void_addWorkerMappings(){}')) {
        result[addWorkerMappingsIndex] = 'void _addWorkerMappings() {';
        result
          ..insert(addWorkerMappingsIndex + 1, newWorkerMappingLine)
          ..insert(addWorkerMappingsIndex + 2, '}');
      } else {
        // Find the closing brace of the function
        var closingBraceIndex = addWorkerMappingsIndex + 1;
        while (closingBraceIndex < result.length &&
            !result[closingBraceIndex].trim().startsWith('}')) {
          closingBraceIndex++;
        }
        result.insert(closingBraceIndex, newWorkerMappingLine);
      }
    }
  }

  return result;
}

/// Adds a worker mapping to the specified source file.
Future<void> addWorkerMappingToSourceFile(
  String workerMappingsPath,
  String sourceFilePath,
  String functionName,
  String subDir,
) async {
  final mainPath = workerMappingsPath.isNotEmpty
      ? p.absolute(workerMappingsPath)
      : p.absolute(p.join('lib', 'main.dart'));

  final content = await readFileLines(mainPath);
  if (content.isEmpty) return;

  var updatedContent = addImportStatements(content, sourceFilePath, mainPath);
  updatedContent = addWorkerMappingsCall(updatedContent);
  updatedContent =
      addOrUpdateWorkerMappingsFunction(updatedContent, functionName, subDir);

  await writeFile(mainPath, updatedContent);

  printDebug(
    () =>
        'Updated source file: $sourceFilePath with new import, worker mapping call, and addWorkerMappings function.',
  );
}

/// Parses command-line arguments into main arguments and Dart VM arguments.
({List<String> mainArgs, List<String> dartArgs}) parseArgs(List<String> args) {
  var effectiveArgs = List<String>.from(args);
  final separator = effectiveArgs.indexOf('--');
  var dartArgs = <String>[];
  if (separator != -1) {
    dartArgs = effectiveArgs.sublist(separator + 1);
    effectiveArgs = effectiveArgs.sublist(0, separator);
  }

  return (mainArgs: effectiveArgs, dartArgs: dartArgs);
}

/// Parses a Dart file to find methods annotated with specific annotations.
Future<Map<String, List<String>>> parseAnnotations(
  String filePath,
  List<String> annotations,
) async {
  final effectivePath = p.absolute(filePath);

  // Check if the file exists.
  if (!File(effectivePath).existsSync()) {
    throw FileSystemException('File not found at: $effectivePath');
  }

  final result = await resolveFile(path: effectivePath);

  // Ensure the result is a ResolvedUnitResult and not an error.
  if (result is! ResolvedUnitResult) {
    throw Exception('Could not resolve the unit for analysis.');
  }

  final annotatedMethods = <String, List<String>>{};
  final library = result.libraryElement;

  // Iterate over all top-level functions in the library's defining unit.
  for (final function in library.topLevelFunctions) {
    final foundAnnotations = _containedAnnotations(
      function.metadata.annotations,
      annotations,
    );
    for (final annotation in foundAnnotations) {
      annotatedMethods
          .putIfAbsent(annotation, () => [])
          .add(function.name.toString());
    }
  }

  // Iterate over all classes in the library's defining unit.
  for (final classElement in library.classes) {
    // Iterate over all methods within the class.
    for (final method in classElement.methods) {
      final foundAnnotations = _containedAnnotations(
        method.metadata.annotations,
        annotations,
      );
      for (final annotation in foundAnnotations) {
        annotatedMethods
            .putIfAbsent(annotation, () => [])
            .add('${classElement.name}.${method.name}');
      }
    }
  }

  return annotatedMethods;
}

/// Helper method to check for the `@isolateManagerWorker` annotation.
List<String> _containedAnnotations(
  List<ElementAnnotation> metadata,
  List<String> classAnnotations,
) {
  for (final annotation in metadata) {
    final constantValue = annotation.computeConstantValue();
    if (constantValue != null) {
      // We check only the variable name to avoid issues with different import paths.
      // Not use this type check: `e == constantValue.type?.element?.name`
      final foundAnnotation =
          classAnnotations.where((e) => e == constantValue.variable?.name);

      return foundAnnotation.toList();
    }
  }
  return [];
}
