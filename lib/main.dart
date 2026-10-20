import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/progression/job.dart';
import 'core/progression/species.dart';
import 'ui/game_screen.dart';
import 'ui/species_select_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const DungeonApp());
}

class DungeonApp extends StatelessWidget {
  const DungeonApp({super.key, this.seed, this.species, this.job});

  final int? seed;

  /// 지정하면 종족 선택을 건너뛰고 바로 게임을 시작한다 (테스트용).
  final Species? species;

  final Job? job;

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
      home: species == null
          ? SpeciesSelectScreen(seed: seed)
          : GameScreen(seed: seed, species: species!, job: job),
    );
  }
}
