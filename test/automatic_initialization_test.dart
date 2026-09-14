import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launch_mode/launch_mode.dart';

void main() {
  final initialMode = LaunchMode.current;
  final bindingBefore = BindingBase.debugBindingType();
  // Deliberately initialize before any Flutter binding setup or test callback.
  LaunchMode.initializeAutomatically();
  final bindingAfter = BindingBase.debugBindingType();

  test('automatically initializes the root isolate synchronously', () {
    expect(initialMode, LaunchModeType.unspecified);
    expect(bindingBefore, isNull);
    expect(bindingAfter, isNull);
    expect(LaunchMode.current, LaunchModeType.foreground);
    expect(LaunchMode.isInitialized, isTrue);
    expect(LaunchMode.isForeground, isTrue);
    expect(LaunchMode.isBackground, isFalse);
    expect(LaunchMode.isIsolate, isFalse);
  });

  test('automatic initialization is idempotent', () {
    LaunchMode.initializeAutomatically();
    LaunchMode.initialize(LaunchModeType.foreground);
    expect(LaunchMode.current, LaunchModeType.foreground);
  });

  test('compute follows the actual execution platform', () async {
    final mode = await compute(_detectMode, null);
    expect(mode, kIsWeb ? LaunchModeType.foreground : LaunchModeType.isolate);
    expect(LaunchMode.current, LaunchModeType.foreground);
  });

  test('background work retains its mode across await without affecting UI', () async {
    final resume = Completer<void>();
    final work = LaunchMode.withBackgroundMode(() async {
      _expectBackground();
      await resume.future;
      _expectBackground();
      return 42;
    });

    expect(LaunchMode.current, LaunchModeType.foreground);
    expect(LaunchMode.isForeground, isTrue);
    resume.complete();
    expect(await work, 42);
    expect(LaunchMode.current, LaunchModeType.foreground);
  });

  test('nested background scopes preserve return values and the outer mode', () {
    final result = LaunchMode.withBackgroundMode(() {
      _expectBackground();
      final inner = LaunchMode.withBackgroundMode(() {
        _expectBackground();
        return 'done';
      });
      _expectBackground();
      return inner;
    });

    expect(result, 'done');
    expect(LaunchMode.current, LaunchModeType.foreground);
  });

  test('initialization inside a background scope cannot change the base mode', () {
    LaunchMode.withBackgroundMode(() {
      LaunchMode.initializeAutomatically();
      LaunchMode.initialize(LaunchModeType.background);
      expect(() => LaunchMode.initialize(LaunchModeType.foreground), throwsStateError);
      expect(() => LaunchMode.initialize(LaunchModeType.isolate), throwsStateError);
      expect(() => LaunchMode.initialize(LaunchModeType.unspecified), throwsArgumentError);
      _expectBackground();
    });

    expect(LaunchMode.current, LaunchModeType.foreground);
  });

  test('synchronous errors propagate without changing the outer mode', () {
    final error = StateError('handler failed');
    expect(
      () => LaunchMode.withBackgroundMode<void>(() => throw error),
      throwsA(same(error)),
    );
    expect(LaunchMode.current, LaunchModeType.foreground);
  });

  test('asynchronous errors propagate without changing the outer mode', () async {
    final error = StateError('async handler failed');
    final result = LaunchMode.withBackgroundMode(() async {
      await Future<void>.value();
      _expectBackground();
      throw error;
    });

    await expectLater(result, throwsA(same(error)));
    expect(LaunchMode.current, LaunchModeType.foreground);
  });

  test('work registered in the scope retains its mode after the body returns', () async {
    final resume = Completer<void>();
    final observed = Completer<LaunchModeType>();
    LaunchMode.withBackgroundMode(() {
      unawaited(resume.future.then((_) => observed.complete(LaunchMode.current)));
    });

    expect(LaunchMode.current, LaunchModeType.foreground);
    resume.complete();
    expect(await observed.future, LaunchModeType.background);
    expect(LaunchMode.current, LaunchModeType.foreground);
  });
}

LaunchModeType _detectMode(void _) {
  LaunchMode.initializeAutomatically();
  return LaunchMode.current;
}

void _expectBackground() {
  expect(LaunchMode.current, LaunchModeType.background);
  expect(LaunchMode.isInitialized, isTrue);
  expect(LaunchMode.isForeground, isFalse);
  expect(LaunchMode.isBackground, isTrue);
  expect(LaunchMode.isIsolate, isFalse);
}
