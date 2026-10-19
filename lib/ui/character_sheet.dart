import 'package:flutter/material.dart';

import '../core/entity/actor.dart';
import '../core/progression/attribute_effects.dart';
import '../core/progression/attributes.dart';
import '../core/progression/experience.dart';
import 'game_controller.dart';

/// 현재 레벨 안에서의 경험치 진행률 (0~1).
double xpProgress(Player player) {
  if (player.isMaxLevel) return 1;
  final from = Experience.totalForLevel(player.level);
  final to = Experience.totalForLevel(player.level + 1);
  return ((player.xp - from) / (to - from)).clamp(0.0, 1.0);
}

IconData attributeIcon(Attribute attribute) => switch (attribute) {
  Attribute.strength => Icons.fitness_center,
  Attribute.dexterity => Icons.air,
  Attribute.intelligence => Icons.psychology,
};

Future<void> showCharacterSheet(
  BuildContext context,
  GameController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1A1714),
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) => CharacterSheet(controller: controller),
    ),
  );
}

/// 레벨, 경험치, 능력치를 보여주고 능력치 포인트를 투자하는 화면.
class CharacterSheet extends StatelessWidget {
  const CharacterSheet({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final player = controller.game.player;
    final points = player.unspentStatPoints;
    const dim = TextStyle(color: Color(0xFF8A8478), fontSize: 13);
    final nextXp = player.isMaxLevel
        ? '최대 레벨'
        : '${player.xp} / ${Experience.totalForLevel(player.level + 1)}';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '레벨 ${player.level}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text('HP ${player.hp}/${player.maxHp}', style: dim),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: xpProgress(player),
                minHeight: 8,
                color: const Color(0xFF5B8DEF),
                backgroundColor: const Color(0xFF1C2433),
              ),
            ),
            const SizedBox(height: 4),
            Text('경험치 $nextXp', style: dim),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text(
                  '능력치',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  points > 0
                      ? '남은 포인트 $points'
                      : '${Experience.statPointInterval}레벨마다 포인트 1개',
                  style: points > 0
                      ? const TextStyle(color: Color(0xFFFFD54F), fontSize: 13)
                      : dim,
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final attribute in Attribute.values)
              _AttributeRow(
                attribute: attribute,
                value: player.attributes[attribute],
                onIncrease: points > 0
                    ? () => controller.increaseAttribute(attribute)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

/// 능력치 효과 한 줄. [active]가 false면 아직 해당 시스템이 없는 효과.
typedef AttributeEffectLine = ({String label, String value, bool active});

String _percent(double multiplier) {
  final p = ((multiplier - 1) * 100).round();
  return '${p >= 0 ? '+' : ''}$p%';
}

String _signed(num n) => '${n >= 0 ? '+' : ''}$n';

/// [attribute]가 [value]일 때 받는 효과 목록.
List<AttributeEffectLine> attributeEffectLines(Attribute attribute, int value) {
  switch (attribute) {
    case Attribute.strength:
      return [
        (
          label: '근접 피해',
          value: _percent(AttributeEffects.meleeDamageMultiplier(value)),
          active: true,
        ),
        (
          label: '방어구 이동 패널티',
          value: _percent(AttributeEffects.armorPenaltyMultiplier(value)),
          active: false,
        ),
      ];
    case Attribute.dexterity:
      return [
        (
          label: '명중',
          value: _signed(AttributeEffects.accuracyBonus(value)),
          active: true,
        ),
        (
          label: '회피',
          value: _signed(AttributeEffects.evasionBonus(value)),
          active: true,
        ),
        (
          label: '원거리 피해',
          value: _percent(AttributeEffects.rangedDamageMultiplier(value)),
          active: false,
        ),
        (
          label: '은신 효율',
          value: _percent(AttributeEffects.stealthMultiplier(value)),
          active: false,
        ),
      ];
    case Attribute.intelligence:
      return [
        (
          label: '주문 시전 시간',
          value: _percent(AttributeEffects.spellTimeMultiplier(value)),
          active: false,
        ),
        (
          label: '주문 성공률',
          value:
              '${_signed((AttributeEffects.spellSuccessBonus(value) * 100).round())}%p',
          active: false,
        ),
        (
          label: '주문 피해',
          value: _percent(AttributeEffects.spellDamageMultiplier(value)),
          active: false,
        ),
        (
          label: '마나 소모',
          value: _percent(AttributeEffects.manaCostMultiplier(value)),
          active: false,
        ),
      ];
  }
}

class _AttributeRow extends StatelessWidget {
  const _AttributeRow({
    required this.attribute,
    required this.value,
    required this.onIncrease,
  });

  final Attribute attribute;
  final int value;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(attributeIcon(attribute), color: const Color(0xFFBDB6A8)),
              const SizedBox(width: 12),
              Text(
                attribute.label,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const Spacer(),
              Text(
                '$value',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              // 포인트가 없으면 자리만 유지해 숫자 위치가 흔들리지 않게 한다.
              Visibility.maintain(
                visible: onIncrease != null,
                child: IconButton.filledTonal(
                  onPressed: onIncrease,
                  tooltip: '${attribute.label} +1',
                  icon: const Icon(Icons.add),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Wrap(
              spacing: 12,
              runSpacing: 2,
              children: [
                for (final e in attributeEffectLines(attribute, value))
                  Text(
                    e.active
                        ? '${e.label} ${e.value}'
                        : '${e.label} ${e.value} · 준비 중',
                    style: TextStyle(
                      fontSize: 12,
                      color: e.active
                          ? const Color(0xFFD8CFBF)
                          : const Color(0xFF6E685E),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
