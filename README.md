# Isolate Manager Generator

The generator for the [isolate_manager](https://pub.dev/packages/isolate_manager).

## Pubspec configuration

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
```

When you run the generator with no flags:

```bash
dart run isolate_manager_generator
```

it will read `pubspec.yaml` from the current working directory and use values
from the `isolate_manager` node as defaults. Pass CLI flags to override any
setting from `pubspec.yaml`.

Supported keys: `input`, `output`, `single`, `shared`, `shared-name`,
`obfuscate`, `wasm`, `debug`, `sub-path`, `worker-mappings-experiment`.
