import 'dart:async';
import 'dart:ui' show RootIsolateToken;

import 'package:flutter/foundation.dart' show kIsWeb;

/// The purpose of the current launch or scoped background work.
///
/// A mode does not detect lifecycle changes or guarantee access to UI or plugins.
enum LaunchModeType {
  /// No launch mode has been initialized.
  unspecified,

  /// The main application entry point intended to run the UI.
  foreground,

  /// A background handler entry point.
  background,

  /// A separate computational worker entry point.
  isolate,
}

/// Stores a base launch mode per isolate with scoped background overrides.
///
/// Call [initializeAutomatically] or [initialize] in each isolate's entry point.
/// Wrap background handler bodies with [withBackgroundMode], including handlers
/// that share an isolate with the UI. New isolates do not inherit the base mode
/// or background overrides. Application lifecycle changes do not alter a mode.
abstract final class LaunchMode {
  static LaunchModeType _current = LaunchModeType.unspecified;
  static final Object _backgroundModeKey = Object();

  /// Initializes the mode synchronously without creating Flutter bindings.
  ///
  /// Preserves an existing manual mode or background override. Otherwise, Flutter
  /// Web and native root isolates become [LaunchModeType.foreground]; native
  /// child isolates become [LaunchModeType.isolate].
  ///
  /// A headless root FlutterEngine cannot be distinguished from a UI engine by
  /// its root token. Its handler must use [withBackgroundMode] before this call.
  static void initializeAutomatically() {
    if (!isInitialized) {
      initialize(_detectMode());
    }
  }

  /// Runs [body] with a background mode for its synchronous and async work.
  ///
  /// The override belongs to a Dart zone; the isolate's base mode is unchanged.
  /// Work registered in the zone retains the override, including work that
  /// completes after [body] returns. Values and errors propagate normally.
  ///
  /// This does not create an isolate or schedule an operating system task.
  static T withBackgroundMode<T>(T Function() body) => runZoned<T>(
        body,
        zoneValues: {_backgroundModeKey: LaunchModeType.background},
      );

  /// Initializes this isolate's launch mode synchronously.
  ///
  /// Repeating the same mode is a no-op. A different mode throws [StateError]
  /// without changing the current mode. Passing [LaunchModeType.unspecified]
  /// always throws [ArgumentError], including after initialization.
  ///
  /// Inside [withBackgroundMode], initializing background is a no-op and any
  /// other mode conflicts with the override. Neither changes the base mode.
  static void initialize(LaunchModeType mode) {
    if (mode == LaunchModeType.unspecified) {
      throw ArgumentError.value(mode, 'mode', 'Must specify a launch mode.');
    }
    if (isInitialized) {
      if (current != mode) {
        throw StateError('Launch mode is already initialized as ${current.name}.');
      }
      return;
    }
    _current = mode;
  }

  /// The background override, base mode, or [LaunchModeType.unspecified].
  static LaunchModeType get current => Zone.current[_backgroundModeKey] as LaunchModeType? ?? _current;

  /// Whether the current context has a background override or initialized mode.
  static bool get isInitialized => current != LaunchModeType.unspecified;

  /// Whether the current context has a foreground mode.
  static bool get isForeground => current == LaunchModeType.foreground;

  /// Whether the current context has a background mode.
  static bool get isBackground => current == LaunchModeType.background;

  /// Whether the current context has a computational worker mode.
  static bool get isIsolate => current == LaunchModeType.isolate;

  static LaunchModeType _detectMode() {
    if (kIsWeb) {
      return LaunchModeType.foreground;
    }
    return RootIsolateToken.instance == null ? LaunchModeType.isolate : LaunchModeType.foreground;
  }
}
