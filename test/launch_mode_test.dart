@TestOn('vm')
library;

import 'dart:isolate';

import 'package:launch_mode/launch_mode.dart';
import 'package:test/test.dart';

const _uninitialized = (
  mode: LaunchModeType.unspecified,
  initialized: false,
  foreground: false,
  background: false,
  isolate: false,
);

const _states = {
  LaunchModeType.foreground: (
    mode: LaunchModeType.foreground,
    initialized: true,
    foreground: true,
    background: false,
    isolate: false,
  ),
  LaunchModeType.background: (
    mode: LaunchModeType.background,
    initialized: true,
    foreground: false,
    background: true,
    isolate: false,
  ),
  LaunchModeType.isolate: (
    mode: LaunchModeType.isolate,
    initialized: true,
    foreground: false,
    background: false,
    isolate: true,
  ),
};

void main() {
  test('starts unspecified with all checks false', () async {
    expect(await Isolate.run(_snapshot), _uninitialized);
  });

  test('rejects unspecified without preventing later initialization', () async {
    final result = await Isolate.run(() {
      final error = _initializationError(LaunchModeType.unspecified);
      final before = _snapshot();
      LaunchMode.initialize(LaunchModeType.foreground);
      return (error: error, before: before, after: _snapshot());
    });

    expect(result.error, isA<ArgumentError>());
    expect(result.before, _uninitialized);
    expect(result.after, _states[LaunchModeType.foreground]);
  });

  for (final entry in _states.entries) {
    final mode = entry.key;
    final expected = entry.value;

    group(mode.name, () {
      test('initializes synchronously with the expected checks', () async {
        final result = await Isolate.run(() {
          LaunchMode.initialize(mode);
          return _snapshot();
        });

        expect(result, expected);
      });

      test('allows repeated initialization with the same mode', () async {
        final result = await Isolate.run(() {
          LaunchMode.initialize(mode);
          LaunchMode.initialize(mode);
          return _snapshot();
        });

        expect(result, expected);
      });

      test('rejects unspecified and preserves the current mode', () async {
        final result = await Isolate.run(() {
          LaunchMode.initialize(mode);
          return (
            error: _initializationError(LaunchModeType.unspecified),
            state: _snapshot(),
          );
        });

        expect(result.error, isA<ArgumentError>());
        expect(result.state, expected);
      });

      for (final other in _states.keys.where((value) => value != mode)) {
        test('rejects ${other.name} and preserves the current mode', () async {
          final result = await Isolate.run(() {
            LaunchMode.initialize(mode);
            return (error: _initializationError(other), state: _snapshot());
          });

          expect(result.error, isA<StateError>());
          expect(result.state, expected);
        });
      }
    });
  }

  test('parent and child isolates keep independent modes', () async {
    final result = await Isolate.run(() async {
      LaunchMode.initialize(LaunchModeType.foreground);
      final before = _snapshot();
      final child = await Isolate.run(() {
        final before = _snapshot();
        LaunchMode.initialize(LaunchModeType.isolate);
        return (before: before, after: _snapshot());
      });
      return (before: before, child: child, after: _snapshot());
    });

    expect(result.before, _states[LaunchModeType.foreground]);
    expect(result.child.before, _uninitialized);
    expect(result.child.after, _states[LaunchModeType.isolate]);
    expect(result.after, _states[LaunchModeType.foreground]);
    expect(_snapshot(), _uninitialized);
  });
}

({
  LaunchModeType mode,
  bool initialized,
  bool foreground,
  bool background,
  bool isolate,
}) _snapshot() => (
      mode: LaunchMode.current,
      initialized: LaunchMode.isInitialized,
      foreground: LaunchMode.isForeground,
      background: LaunchMode.isBackground,
      isolate: LaunchMode.isIsolate,
    );

Object? _initializationError(LaunchModeType mode) {
  try {
    LaunchMode.initialize(mode);
    return null;
  } on Object catch (error) {
    return error;
  }
}
