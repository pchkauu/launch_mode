# launch_mode

An explicit launch mode for each Dart isolate. Initialize it in an entry point,
then let application methods choose their logic using the declared mode.

Pure Dart, compatible with Flutter, with no runtime dependencies. Requires Dart
3.0 or later.

## Installation

Until the package is published, use a local path dependency:

```yaml
dependencies:
  launch_mode:
    path: ../launch_mode
```

Adjust the path to your checkout, then run `dart pub get` or `flutter pub get`.

## Main application entry point

```dart
import 'package:launch_mode/launch_mode.dart';

void main() {
  LaunchMode.initialize(LaunchModeType.foreground);

  print(LaunchMode.current.name); // foreground
  print(LaunchMode.isInitialized); // true
  print(LaunchMode.isForeground); // true

  // Continue application initialization and call runApp in a Flutter app.
}
```

## Modes and initialization

| Mode | Meaning |
| --- | --- |
| `unspecified` | No mode has been initialized. |
| `foreground` | Main application entry point intended to run the UI. |
| `background` | Background handler entry point. |
| `isolate` | Separate computational worker entry point. |

`LaunchMode.initialize(mode)` returns `void` and sets the value synchronously.
Calling it again with the same mode is a no-op. A different mode throws
`StateError` and leaves the first mode unchanged. Passing `unspecified` always
throws `ArgumentError`, even after initialization.

Before initialization, `LaunchMode.current` is `LaunchModeType.unspecified` and
`isInitialized`, `isForeground`, `isBackground`, and `isIsolate` are all `false`.
Use `LaunchMode.current.name` for the lowercase enum name and
`!LaunchMode.isForeground` for its negation. The latter is also `true` before
initialization, so it does not imply a known background or worker mode.

## Background handler entry point

Initialize the mode before running the handler's application logic:

```dart
import 'package:launch_mode/launch_mode.dart';

@pragma('vm:entry-point')
Future<void> backgroundEntryPoint() async {
  LaunchMode.initialize(LaunchModeType.background);

  // Initialize the services required by this handler, then do its work.
}
```

Adapt the callback signature and registration to your background integration.
This example assumes an entry point in an isolate that has not already been
initialized with another mode. Calling a background callback inside an existing
foreground isolate does not create a separate launch mode; attempting to set
`background` there throws `StateError`.

## Computational worker

Each new isolate starts as `unspecified`, even when its parent has initialized a
mode. Initialize the worker independently:

```dart
import 'dart:isolate';

import 'package:launch_mode/launch_mode.dart';

Future<void> main() async {
  LaunchMode.initialize(LaunchModeType.foreground);

  final workerMode = await Isolate.run(() {
    LaunchMode.initialize(LaunchModeType.isolate);
    return LaunchMode.current;
  });

  print(workerMode.name); // isolate
  print(LaunchMode.current.name); // foreground
}
```

All Dart code, including the main application, runs in an isolate. The `isolate`
mode specifically labels a computational worker; it does not detect the runtime
isolate type. Static values are local to each isolate and are not shared between
them. See [concurrency in Dart](https://dart.dev/language/concurrency).

## Choose application logic

```dart
void reportProgress(String message) {
  if (!LaunchMode.isInitialized) {
    throw StateError('Initialize the launch mode before reporting progress.');
  }

  if (LaunchMode.isForeground) {
    print('Application progress: $message');
  } else if (LaunchMode.isBackground) {
    print('Background progress: $message');
  } else if (LaunchMode.isIsolate) {
    print('Worker progress: $message');
  }
}
```

Replace these branches with your application's reporting policy. A mode declares
the purpose of a launch; it does not confirm access to UI, platform channels, or
any particular plugin. Those capabilities depend on the environment and its
initialization.

## Lifecycle and Web

The value remains in memory for the lifetime of the isolate. It is not persisted
between launches. Moving the application to the background or returning to the
foreground does not change it. The package does not observe Flutter lifecycle
events, initialize plugins, or provide a reset API.

The library has no platform-specific imports and can be used on Web. The
`Isolate.run` example above is for native platforms. Flutter's `compute` executes
in the current isolate on Web. Initializing it with a different mode there
conflicts with the existing mode. See
[Flutter's isolate documentation](https://docs.flutter.dev/perf/isolates).

## Example and checks

```sh
dart pub get
dart run example/launch_mode_example.dart
dart analyze
dart test
dart format --output=none --set-exit-if-changed lib test example
mkdir -p build
dart compile js example/launch_mode_example.dart -o build/launch_mode_example.js
```

Tests run on the Dart VM and use fresh isolates instead of resetting shared state.
JavaScript compilation checks that the library and the basic example compile for
Web; it does not verify browser behavior or Flutter plugin availability.
