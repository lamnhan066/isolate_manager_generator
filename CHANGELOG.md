## 0.1.1

* Update analyzer dependency to ^7.7.1.
* Fix issue preventing the generator from producing expected output.
* Use `very_good_analysis`.

## 0.1.0

* Update analyzer dependency to ^7.0.0.

## 0.0.13

* Fixed issue with incorrect parsing of Dart defines.

## 0.0.12

* Able to execute `dart run isolate_manager_generator`.
* Return non-zero exit code when errors occur during the `execute` command execution for better error handling in CI/CD pipelines.
* Update tests.

## 0.0.11

* Fix function path generation to handle empty subPath case.

## 0.0.10

* Use the same separator for the generated function name across platforms. The `IsolateManager` will handle the sepecifics.

## 0.0.9

* Fix import path separator issue when generate the shared worker.

## 0.0.8

* Fix dart file extension check issue.

## 0.0.7

* Use `sub-path` to replace `sub-dir` for consistency.

## 0.0.6

* Add `sub-dir` option to add sub directory for the workers.

## 0.0.5

* Refactor worker mapping functions for improved readability and functionality
* Add unit tests for utility functions in utils_test.dart
* Update file path handling to use the `path` package for improved cross-platform compatibility
* Add GitHub Actions workflows for continuous integration and automated testing

## 0.0.4

* Add support for `IsolateManagerCustomWorker` class generation
* Refactor generator functions to use shared IsolateManager for improved performance
* Rename command flag from `--name` to `--shared-name` for better clarity
* Add `--help`/`-h` flag to display command usage information

## 0.0.3

* Remove the temp files event when issue occurs.
* Refactor output file handling to include backup restoration on compilation failure.

## 0.0.2

* Ensure newline at the end of file when writing modified content.
* Update README.

## 0.0.1

* Initial release.
