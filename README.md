# launch_mode

Launch modes for Flutter entry points and background handlers. Initialize the
mode automatically, then let application methods choose their logic using the
current mode. Background scopes keep concurrent UI work in its original mode.

Supports Android, iOS, macOS, Windows, Linux, and Flutter Web. Requires Flutter
3.10.0 or later and Dart 3.0 or later. Version 0.2.0 requires the Flutter SDK;
standalone Dart programs can continue using 0.1.0.

## Installation

To use version 0.2.0 from GitHub, depend on the release tag:

```yaml
dependencies:
  launch_mode:
    git:
      url: https://github.com/pchkauu/launch_mode.git
      ref: v0.2.0
```

Run `flutter pub get` after adding the dependency.

## Main application entry point

```dart
import 'package:flutter/material.dart';
import 'package:launch_mode/launch_mode.dart';

void main() {
  LaunchMode.initializeAutomatically();
  // current == foreground; Flutter bindings are not required by this call.

  runApp(const MaterialApp(home: Scaffold(body: Text('Hello, foreground!'))));
}
```

`initializeAutomatically()` is synchronous and returns `void`. It preserves an
existing mode, including a background scope. Otherwise, Flutter Web becomes
`foreground` without reading `RootIsolateToken`. On native platforms,
`RootIsolateToken.instance != null` selects `foreground`; `null` selects `isolate`.
The method does not create Flutter bindings.

**A background root FlutterEngine must enter through `withBackgroundMode`.**
Without that scope, automatic initialization classifies it as `foreground`.
A root token identifies the root isolate, not whether its engine has a UI.

## Modes and manual initialization

| Mode | Meaning |
| --- | --- |
| `unspecified` | No mode has been initialized in this context. |
| `foreground` | Main application entry point intended to run the UI. |
| `background` | Background handler context. |
| `isolate` | Separate computational worker entry point. |

Manual initialization remains available:

```dart
LaunchMode.initialize(LaunchModeType.foreground);
LaunchMode.initializeAutomatically(); // Preserves foreground.
```

`initialize(mode)` returns `void` and sets the base mode synchronously. Repeating
the same mode is a no-op. A different mode throws `StateError` and leaves the
mode unchanged. Passing `unspecified` always throws `ArgumentError`.

Before initialization, outside a background scope, `current` is `unspecified`
and `isInitialized`, `isForeground`, `isBackground`, and `isIsolate` are all
`false`. Reading a getter does not trigger automatic initialization. Use
`LaunchMode.current.name` for the enum name and `!LaunchMode.isForeground` for
negation; the latter is also `true` before initialization.

## Background scopes

```dart
final result = await LaunchMode.withBackgroundMode(() async {
  // current == background; isInitialized == true.
  await Future<void>.delayed(const Duration(milliseconds: 1));
  return LaunchMode.current.name; // background
});
// The surrounding context still has its original mode.
```

`withBackgroundMode<T>(T Function() body)` uses a Dart zone. The override survives
`await` and async work registered inside the scope, even after the callback
returns. Values and synchronous or asynchronous errors propagate unchanged.
Nested scopes remain `background`.

The isolate's base mode never changes through the scope. Concurrent work outside
it continues to see its original mode. Inside a scope, `initialize(background)`
and `initializeAutomatically()` are no-ops; another explicit mode throws
`StateError`, and `unspecified` throws `ArgumentError`. These calls do not
initialize an otherwise uninitialized base mode.

The wrapper marks execution context. It does not create an isolate, schedule an
operating system task, or initialize plugins.

### Firebase Messaging

Keep the registered handler as a top-level function with the entry-point pragma.
Wrap its body, including application initialization:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:launch_mode/launch_mode.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) =>
    LaunchMode.withBackgroundMode(() async {
      await Firebase.initializeApp(); // Supply your project's options if needed.
      // Process message here; current == background, including after await.
    });

// In main(), after Firebase initialization:
// FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
```

This also works when the handler shares the application's foreground isolate.
Follow [Firebase's background message setup](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages)
for platform requirements and initialization options. Firebase Web Service
Workers run outside the Flutter engine and are outside this package's scope.

### Workmanager

Keep the dispatcher as a top-level entry point and wrap each task callback body:

```dart
import 'package:launch_mode/launch_mode.dart';
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) =>
      LaunchMode.withBackgroundMode(() async {
        // Initialize task services and perform the work here.
        // current == background, including after await.
        return true;
      }));
}

// In main():
// Workmanager().initialize(callbackDispatcher);
```

Put task initialization inside the wrapper. If the dispatcher itself runs shared
application initialization, wrap that work too, before any call to
`initializeAutomatically()`. See [Workmanager's setup](https://docs.page/fluttercommunity/flutter_workmanager/quickstart)
for task registration and platform configuration. Firebase and Workmanager are
application dependencies; this package does not depend on either.

## Computational worker

On native platforms, each new isolate starts as `unspecified`. Neither the
parent's base mode nor its background zone is inherited:

```dart
import 'dart:isolate';

import 'package:launch_mode/launch_mode.dart';

Future<LaunchModeType> checkWorkerMode() => Isolate.run(() {
      LaunchMode.initializeAutomatically();
      return LaunchMode.current; // isolate
    });
```

Initialize the application entry point separately. Its mode is unchanged when
the worker completes. See [concurrency in Dart](https://dart.dev/language/concurrency).

Flutter's `compute` executes in the current isolate on Web. Automatic
initialization preserves that context's mode, or selects `foreground` if it is
uninitialized. It does not turn Web computation into `isolate` mode. Explicitly
initializing a conflicting mode still throws `StateError`. See
[Flutter's isolate documentation](https://docs.flutter.dev/perf/isolates).

## Choose application logic

```dart
String progressChannel() => switch (LaunchMode.current) {
      LaunchModeType.foreground => 'screen',
      LaunchModeType.background => 'background-log',
      LaunchModeType.isolate => 'worker-result',
      LaunchModeType.unspecified => throw StateError('Initialize the launch mode.'),
    };
```

A mode labels the purpose of execution. It does not guarantee access to UI,
platform channels, or any particular plugin. The base mode lives only in the
current isolate's memory. App lifecycle changes do not change it. There is no
reset API, lifecycle observer, window inspection, isolate-name heuristic, or
stack-trace detection.

## Example and checks

The minimal Flutter Web application in `example/` uses the Flutter Web bootstrap
introduced in Flutter 3.22. Its own minimum SDK is Flutter 3.22 / Dart 3.4; the
library's minimum remains Flutter 3.10 / Dart 3.0.

From the package root:

```sh
flutter pub get
flutter analyze
flutter test
flutter test --platform chrome
dart format --output=none --set-exit-if-changed lib test example/lib
```

Run or build the example:

```sh
cd example
flutter pub get
flutter run -d chrome
flutter build web --release
```

Manual initialization tests use fresh native isolates without a reset API.
Browser tests cover automatic initialization, Web `compute`, and background
scopes. Tests of the wrappers do not verify Firebase delivery, Workmanager task
execution, or plugin capabilities on physical devices.
