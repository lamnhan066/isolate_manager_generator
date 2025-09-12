/// Base exception class for all Isolate Manager Generator exceptions.
/// All specific exceptions in the library should extend this class.
sealed class IMGException implements Exception {

  /// Creates a new exception with the specified error message.
  const IMGException(this.message);
  /// The error message describing the exception.
  final String message;

  @override
  String toString() => 'IsolateManagerGeneratorException: $message';
}

/// Exception thrown when a compilation error occurs during code generation.
class IMGCompileErrorException extends IMGException {
  /// Creates a new exception indicating a compilation error.
  const IMGCompileErrorException() : super('Compile error');
}

/// Exception thrown when the generator is unable to resolve a file path.
class IMGUnableToResolvingFileException extends IMGException {
  /// Creates a new exception with the specified file path that could not be resolved.
  const IMGUnableToResolvingFileException(String filePath)
      : super('Unable to resolving file: $filePath');
}

/// Exception thrown when no main function is found in the processed source file.
class IMGNoMainFunctionFoundException extends IMGException {
  /// Creates a new exception indicating that no main function was found.
  const IMGNoMainFunctionFoundException()
      : super('No main function found in the source file.');
}

/// Exception thrown when the main function's syntax is invalid (missing opening brace).
class IMGMainFunctionHasNoOpenBracesException extends IMGException {
  /// Creates a new exception indicating that the main function is missing opening braces.
  const IMGMainFunctionHasNoOpenBracesException()
      : super('Malformed main function, no opening brace found.');
}

/// Exception thrown when a file specified in the configuration cannot be found.
class IMGFileNotFoundException extends IMGException {

  /// Creates a new exception indicating that a file was not found at the specified path.
  ///
  /// [filePath] is the path to the file that couldn't be located.
  const IMGFileNotFoundException(this.filePath)
      : super('File not found: $filePath');
  /// The path to the file that was not found.
  final String filePath;
}
