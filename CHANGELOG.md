## 0.4.2

* Supports pubspec configuration:

    You can provide default configuration for the generator in your project's
    `pubspec.yaml` under a top-level `isolate_manager` node. CLI flags always take
    precedence over values in `pubspec.yaml`.

    Example (commented schema):

    ```yaml
    # Top-level node for generator defaults
    isolate_manager:
        # Path to scan for source files (defaults to "./lib")
        input: ./lib

        # Output folder for generated files (defaults to "web")
        output: ./web

        # Generate single workers (true/false)
        single: true

        # Generate shared worker (true/false)
        shared: true

        # Name of the generated shared Worker
        shared-name: shared_worker

        # JS obfuscation level (0..4)
        obfuscate: 4

        # Compile to wasm instead of JS
        wasm: false

        # Export debug/intermediate files
        debug: false

        # Sub-path of the function name when generating worker-mappings
        sub-path: workers

        # Path to the main/source file to inject workerMappings (optional)
        worker-mappings-experiment: lib/main.dart

        # Extra Dart args passed to dart compile before CLI dart args
        dart-args:
            - --no-source-maps
    ```

    When you run the generator with no flags:

    ```bash
    dart run isolate_manager_generator
    ```

    it will read `pubspec.yaml` from the current working directory and use values
    from the `isolate_manager` node as defaults. Pass CLI flags to override any
    setting from `pubspec.yaml`.

    Supported keys: `input`, `output`, `single`, `shared`, `shared-name`,
    `obfuscate`, `wasm`, `debug`, `sub-path`, `worker-mappings-experiment`,
    `dart-args`.


## 0.4.1

* Refactor file writing in annotated function generation to use a list for content accumulation.
* Ensure the Dart temp files are existed before running the JS generator.

## 0.4.0

* BREAKING CHANGE: Removed `--omit-implicit-checks` option.
    Before (the option is added automatically):

    ```dart
    dart run isolate_manager_generator
    ```

    After (the option is added manually):

    ```dart
    dart run isolate_manager_generator -- --omit-implicit-checks
    ```

* BREAKING CHANGE: Removed unused source map generation and cleanup logic.
    Before (the option is added automatically):

    ```dart
    dart run isolate_manager_generator
    ```

    After (the option is added manually):

    ```dart
    dart run isolate_manager_generator -- --no-source-maps
    ```

* BREAKING CHANGE: The `js.deps` files are no longer removed automatically, and there is no helper available for this change.
* Bump the dart analyzer to `^10.0.0`.

## 0.3.1

* Improve the deletion logic to check for file existence before deletion.
* Refactor the code to completely satisfy with `very_good_analysis: ^10.0.0`.
* Improve the tests.

## 0.3.0

* Update to support Dart SDK `^3.9.0`.
* Update `analyzer` dependency to `^8.4.0`.
* Update `isolate_manager` to `^6.1.2`.
* Update `very_good_analysis` to `^10.0.0` in dev dependencies.

## 0.2.0

* Update analyzer dependency to `^8.1.0`.
* Fix issue preventing the generator from producing expected output.
* Use `very_good_analysis`.

## 0.2.0-rc **Avoid Using This Version**

* Update analyzer dependency to ^8.0.0.

## 0.1.0 **Avoid Using This Version**

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
