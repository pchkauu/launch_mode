/// The purpose of the current isolate's launch, declared by the application.
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

/// Stores one launch mode for the lifetime of the current isolate.
///
/// Call [initialize] in each isolate's entry point before running application
/// logic. New isolates start with [LaunchModeType.unspecified]; they do not
/// inherit another isolate's mode. Moving the application to the background
/// does not change this value.
abstract final class LaunchMode {
  static LaunchModeType _current = LaunchModeType.unspecified;

  /// Initializes this isolate's launch mode synchronously.
  ///
  /// Repeating the same mode is a no-op. A different mode throws [StateError]
  /// without changing the current mode. Passing [LaunchModeType.unspecified]
  /// always throws [ArgumentError], including after initialization.
  static void initialize(LaunchModeType mode) {
    if (mode == LaunchModeType.unspecified) {
      throw ArgumentError.value(mode, 'mode', 'Must specify a launch mode.');
    }
    if (isInitialized && _current != mode) {
      throw StateError(
        'Launch mode is already initialized as ${_current.name}.',
      );
    }
    _current = mode;
  }

  /// The declared mode, or [LaunchModeType.unspecified] before initialization.
  static LaunchModeType get current => _current;

  /// Whether this isolate has a declared launch mode.
  static bool get isInitialized => _current != LaunchModeType.unspecified;

  /// Whether this isolate was initialized for the main application entry point.
  static bool get isForeground => _current == LaunchModeType.foreground;

  /// Whether this isolate was initialized for a background handler entry point.
  static bool get isBackground => _current == LaunchModeType.background;

  /// Whether this isolate was initialized for a computational worker entry point.
  static bool get isIsolate => _current == LaunchModeType.isolate;
}
