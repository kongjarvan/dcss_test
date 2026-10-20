import 'package:flutter/material.dart';

import '../core/progression/attribute_effects.dart';
import '../core/progression/attributes.dart';
import '../core/progression/skills.dart';
import '../core/progression/species.dart';
import 'character_sheet.dart';
import 'job_select_screen.dart';

/// 적성 +2 이상은 "뛰어난 적성", -2 이하는 "약한 적성"으로 요약.
List<Widget> _aptitudeLines(Species species) {
  String list(bool Function(int) test) => Skill.values
      .where((s) => test(species.aptitude(s)))
      .map((s) => s.label)
      .join(', ');
  final strong = list((a) => a >= 2);
  final weak = list((a) => a <= -2);
  if (strong.isEmpty && weak.isEmpty) {
    return const [
      Text(
        '적성  모든 숙련도가 고르다',
        style: TextStyle(color: Color(0xFFD8CFBF), fontSize: 13),
      ),
    ];
  }
  return [
    if (strong.isNotEmpty)
      Text(
        '뛰어난 적성  $strong',
        style: const TextStyle(color: Color(0xFF7BC67B), fontSize: 13),
      ),
    if (weak.isNotEmpty)
      Text(
        '약한 적성  $weak',
        style: const TextStyle(color: Color(0xFFE57373), fontSize: 13),
      ),
  ];
}

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

  /// 모든 화면을 닫고 종족 선택부터 다시 시작한다 (새 게임/다시 시작).
  static void open(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SpeciesSelectScreen()),
      (_) => false,
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
                // 직업 선택으로. 뒤로 가기로 종족을 다시 고를 수 있다.
                onSelect: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        JobSelectScreen(species: species, seed: seed),
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
              AttributeGrid(valueOf: species.baseValue),
              const SizedBox(height: 10),
              ..._aptitudeLines(species),
            ],
          ),
        ),
      ),
    );
  }
}

/// 능력치 값 표시. 기준값(10)보다 높으면 초록, 낮으면 빨강.
/// [bonus]가 있으면 값 옆에 (+3)처럼 보정치를 함께 표시한다.
class AttributeValueChip extends StatelessWidget {
  const AttributeValueChip({
    super.key,
    required this.attribute,
    required this.value,
    this.bonus = 0,
  });

  final Attribute attribute;
  final int value;
  final int bonus;

  @override
  Widget build(BuildContext context) {
    // 기준값(10)보다 높으면 초록, 낮으면 빨강.
    final color = value > AttributeEffects.neutral
        ? const Color(0xFF7BC67B)
        : value < AttributeEffects.neutral
        ? const Color(0xFFE57373)
        : const Color(0xFFD8CFBF);
    // 좁은 화면에서는 넘치지 않게 글자를 줄인다.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
          if (bonus != 0)
            Text(
              ' (${bonus > 0 ? '+' : ''}$bonus)',
              style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 11),
            ),
        ],
      ),
    );
  }
}

/// 능력치를 2 × 2로 표시. 한 줄에 4개는 휴대폰 화면에서 좁다.
class AttributeGrid extends StatelessWidget {
  const AttributeGrid({super.key, required this.valueOf, this.bonusOf});

  final int Function(Attribute) valueOf;

  /// 값 옆에 표시할 보정치 (예: 직업 보정).
  final int Function(Attribute)? bonusOf;

  @override
  Widget build(BuildContext context) {
    const values = Attribute.values;
    return Column(
      children: [
        for (var i = 0; i < values.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                for (final a in values.skip(i).take(2))
                  Expanded(
                    child: AttributeValueChip(
                      attribute: a,
                      value: valueOf(a),
                      bonus: bonusOf?.call(a) ?? 0,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
