import 'package:flutter/material.dart';

import '../core/progression/job.dart';
import '../core/progression/species.dart';
import 'game_screen.dart';
import 'species_select_screen.dart';

IconData jobIcon(Job job) => switch (job) {
  Job.fighter => Icons.shield,
  Job.wizard => Icons.auto_fix_high,
  Job.hunter => Icons.track_changes,
};

/// 종족을 고른 뒤 직업을 고르는 화면.
/// 각 직업 카드에 "종족 + 직업 보정"을 합친 최종 시작 능력치를 보여준다.
class JobSelectScreen extends StatelessWidget {
  const JobSelectScreen({super.key, required this.species, this.seed});

  final Species species;
  final int? seed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0C0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E0C0A),
        title: Text('${species.name} · 직업 선택'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final job in Job.values) ...[
              _JobCard(
                species: species,
                job: job,
                // 게임 시작. 선택 화면들은 모두 닫는다.
                onSelect: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) =>
                        GameScreen(seed: seed, species: species, job: job),
                  ),
                  (_) => false,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.species,
    required this.job,
    required this.onSelect,
  });

  final Species species;
  final Job job;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final attributes = startingAttributes(species, job);
    return Card(
      color: const Color(0xFF1A1714),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(jobIcon(job), size: 28, color: const Color(0xFFD8B04A)),
                  const SizedBox(width: 12),
                  Text(
                    job.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                job.description,
                style: const TextStyle(color: Color(0xFFBDB6A8), fontSize: 14),
              ),
              const SizedBox(height: 12),
              AttributeGrid(
                valueOf: (a) => attributes[a],
                bonusOf: job.adjustment,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
