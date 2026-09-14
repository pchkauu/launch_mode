import 'package:flutter/material.dart';
import 'package:launch_mode/launch_mode.dart';

void main() {
  LaunchMode.initializeAutomatically();
  runApp(const LaunchModeExample());
}

class LaunchModeExample extends StatelessWidget {
  const LaunchModeExample({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Launch mode')),
          body: Center(child: Text('Current mode: ${LaunchMode.current.name}')),
        ),
      );
}
