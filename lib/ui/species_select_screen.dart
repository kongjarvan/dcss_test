import 'package:flutter/material.dart';

import '../core/progression/attribute_effects.dart';
import '../core/progression/attributes.dart';
import '../core/progression/species.dart';
import 'character_sheet.dart';
import 'game_screen.dart';

IconData speciesIcon(Species species) => switch (species) {
  Species.human => Icons.person,
  Species.elf => Icons.forest,
  Species.dwarf => Icons.hardware,
};

/// 새 게임 시작 시 종족을 고르는 화면.
class SpeciesSelectScreen extends StatelessWidget {
  const SpeciesSelectScreen({super.key, this.seed});

  /// 고정 시드 (테스트/디버깅용).
  final int? seed;

  /// 현재 화면을 종족 선택 화면으로 교체한다 (새 게임/다시 시작).
  static void open(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SpeciesSelectScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0C0A),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
          children: [
            const Text(
              '종족 선택',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            for (final species in Species.values) ...[
              _SpeciesCard(
                species: species,
                onSelect: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => GameScreen(seed: seed, species: species),
                  ),
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

class _SpeciesCard extends StatelessWidget {
  const _SpeciesCard({required this.species, required this.onSelect});

  final Species species;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
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
                  Icon(
                    speciesIcon(species),
                    size: 28,
                    color: const Color(0xFFD8B04A),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    species.name,
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
                species.description,
                style: const TextStyle(color: Color(0xFFBDB6A8), fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final a in Attribute.values)
                    Expanded(
                      child: _StatChip(
                        attribute: a,
                        value: species.baseValue(a),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.attribute, required this.value});

  final Attribute attribute;
  final int value;

  @override
  Widget build(BuildContext context) {
    // 기준값(10)보다 높으면 초록, 낮으면 빨강.
    final color = value > AttributeEffects.neutral
        ? const Color(0xFF7BC67B)
        : value < AttributeEffects.neutral
        ? const Color(0xFFE57373)
        : const Color(0xFFD8CFBF);
    return Row(
      children: [
        Icon(
          attributeIcon(attribute),
          size: 16,
          color: const Color(0xFF8A8478),
        ),
        const SizedBox(width: 4),
        Text(
          '${attribute.label} ',
          style: const TextStyle(color: Color(0xFF8A8478), fontSize: 13),
        ),
        Text(
          '$value',
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
