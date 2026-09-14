import 'package:flutter_test/flutter_test.dart';
import 'package:launch_mode/launch_mode.dart';

void main() {
  test('background initialization leaves the base mode available for a manual choice', () async {
    expect(LaunchMode.current, LaunchModeType.unspecified);
    expect(LaunchMode.isInitialized, isFalse);

    final result = LaunchMode.withBackgroundMode(() async {
      expect(LaunchMode.current, LaunchModeType.background);
      expect(LaunchMode.isInitialized, isTrue);
      expect(LaunchMode.isForeground, isFalse);
      expect(LaunchMode.isBackground, isTrue);
      expect(LaunchMode.isIsolate, isFalse);
      LaunchMode.initialize(LaunchModeType.background);
      LaunchMode.initializeAutomatically();
      expect(() => LaunchMode.initialize(LaunchModeType.foreground), throwsStateError);
      expect(() => LaunchMode.initialize(LaunchModeType.isolate), throwsStateError);
      expect(() => LaunchMode.initialize(LaunchModeType.unspecified), throwsArgumentError);
      await Future<void>.value();
      return LaunchMode.current;
    });

    expect(LaunchMode.current, LaunchModeType.unspecified);
    expect(await result, LaunchModeType.background);
    expect(LaunchMode.current, LaunchModeType.unspecified);
    expect(LaunchMode.isInitialized, isFalse);
    expect(LaunchMode.isBackground, isFalse);

    LaunchMode.initialize(LaunchModeType.background);
    LaunchMode.initializeAutomatically();
    expect(LaunchMode.current, LaunchModeType.background);
  });
}
