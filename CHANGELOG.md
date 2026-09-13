# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-09-14

### Added

- `LaunchModeType` with `unspecified`, `foreground`, `background`, and `isolate` modes.
- Synchronous `LaunchMode.initialize` with one mode per isolate. Repeating the same
  mode is allowed; conflicting modes throw `StateError`, and `unspecified` throws
  `ArgumentError` without changing the current mode.
- `LaunchMode.current`, `isInitialized`, `isForeground`, `isBackground`, and
  `isIsolate` for selecting application logic by launch mode.
- A pure Dart library compatible with Flutter and Web, with no runtime dependencies.
- Entry point examples, lifecycle and Web guidance, strict analyzer configuration,
  and regression tests for initialization and isolate independence.

[Unreleased]: https://github.com/pchkauu/launch_mode/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/pchkauu/launch_mode/tree/v0.1.0
