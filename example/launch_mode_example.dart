// Console output is intentional in this runnable example.
// ignore_for_file: avoid_print

import 'package:launch_mode/launch_mode.dart';

void main() {
  LaunchMode.initialize(LaunchModeType.foreground);
  print('Launch mode: ${LaunchMode.current.name}');
  print('Initialized: ${LaunchMode.isInitialized}');

  if (LaunchMode.isForeground) {
    print('Run the main application startup logic.');
  } else if (LaunchMode.isBackground) {
    print('Run the background handler logic.');
  } else if (LaunchMode.isIsolate) {
    print('Run the computational worker logic.');
  }
}
