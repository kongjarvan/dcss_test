import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/game_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const DungeonApp());
}

class DungeonApp extends StatelessWidget {
  const DungeonApp({super.key, this.seed});

  final int? seed;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DC Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB8860B),
          brightness: Brightness.dark,
        ),
      ),
      home: GameScreen(seed: seed),
    );
  }
}
