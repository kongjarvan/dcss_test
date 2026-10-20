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
  Attribute.faith => Icons.church,
};

/// 캐릭터 창을 연다.
///
/// [requireSpend]가 true면 (레벨업 직후) 능력치 포인트를 모두 쓸 때까지
/// 닫을 수 없고, 다 쓰면 자동으로 닫힌다.
Future<void> showCharacterSheet(BuildContext context, GameController controller, {bool requireSpend = false}) async {
  final navigator = Navigator.of(context);
  var closed = false;
  void closeWhenSpent() {
    if (closed || controller.hasStatPoints) return;
    closed = true;
    navigator.pop();
  }

  if (requireSpend) controller.addListener(closeWhenSpent);
  try {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1714),
      isScrollControlled: true,
      showDragHandle: !requireSpend,
      isDismissible: !requireSpend,
      enableDrag: !requireSpend,
      builder: (context) => PopScope(
        // 뒤로 가기 버튼도 막는다.
        canPop: !requireSpend,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => CharacterSheet(controller: controller, requireSpend: requireSpend),
        ),
      ),
    );
  } finally {
    closed = true;
    controller.removeListener(closeWhenSpent);
  }
}

/// 레벨, 경험치, 능력치를 보여주고 능력치 포인트를 투자하는 화면.
class CharacterSheet extends StatelessWidget {
  const CharacterSheet({super.key, required this.controller, this.requireSpend = false});

  final GameController controller;

  /// 레벨업 직후 강제 선택 모드.
  final bool requireSpend;

  @override
  Widget build(BuildContext context) {
    final player = controller.game.player;
    final points = player.unspentStatPoints;
    const dim = TextStyle(color: Color(0xFF8A8478), fontSize: 13);
    final nextXp = player.isMaxLevel ? '최대 레벨' : '${player.xp} / ${Experience.totalForLevel(player.level + 1)}';

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, requireSpend ? 20 : 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (requireSpend) ...[
              Row(
                children: [
                  const Icon(Icons.arrow_circle_up, color: Color(0xFFFFD54F)),
                  const SizedBox(width: 8),
                  Text(
                    points > 1 ? '레벨 업! 능력치를 $points개 올리세요' : '레벨 업! 올릴 능력치를 고르세요',
                    style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Text(
                  '${[player.species.name, ?player.job?.name].join(' ')} · 레벨 ${player.level}',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text('HP ${player.hp}/${player.maxHp} · MP ${player.mp}/${player.maxMp}', style: dim),
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
            const SizedBox(height: 12),
            _PietyRow(piety: player.piety, rank: player.pietyRank),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text(
                  '능력치',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  points > 0 ? '남은 포인트 $points' : '레벨업마다 포인트 ${Experience.statPointsPerLevel}개',
                  style: points > 0 ? const TextStyle(color: Color(0xFFFFD54F), fontSize: 13) : dim,
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final attribute in Attribute.values)
              _AttributeRow(
                attribute: attribute,
                value: player.attributes[attribute],
                onIncrease: points > 0 ? () => controller.increaseAttribute(attribute) : null,
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

/// 능력치를 1 올릴 때 얻는 것. 예) "올리면 HP +1, MP +3"
String increaseGainText(Attribute attribute) {
  final g = AttributeEffects.gainOnIncrease(attribute);
  final parts = [if (g.hp > 0) 'HP +${g.hp}', if (g.mp > 0) 'MP +${g.mp}'];
  return parts.isEmpty ? '증가량 미정' : parts.join(', ');
}

String _signed(num n) => '${n >= 0 ? '+' : ''}$n';

/// [attribute]가 [value]일 때 받는 효과 목록.
List<AttributeEffectLine> attributeEffectLines(Attribute attribute, int value) {
  switch (attribute) {
    case Attribute.strength:
      return [
        (label: '근접 피해', value: _percent(AttributeEffects.meleeDamageMultiplier(value)), active: true),
        (label: '방어구 회피 패널티', value: _percent(AttributeEffects.armorPenaltyMultiplier(value)), active: true),
      ];
    case Attribute.dexterity:
      return [
        (label: '체력 재생', value: _percent(AttributeEffects.hpRegenMultiplier(value)), active: true),
        (label: '명중', value: _signed(AttributeEffects.accuracyBonus(value)), active: true),
        (label: '회피', value: _signed(AttributeEffects.evasionBonus(value)), active: true),
        (label: '원거리 피해', value: _percent(AttributeEffects.rangedDamageMultiplier(value)), active: false),
        (label: '은신 효율', value: _percent(AttributeEffects.stealthMultiplier(value)), active: false),
      ];
    case Attribute.intelligence:
      return [
        (label: '주문 시전 시간', value: _percent(AttributeEffects.spellTimeMultiplier(value)), active: false),
        (label: '주문 성공률', value: '${_signed((AttributeEffects.spellSuccessBonus(value) * 100).round())}%p', active: false),
        (label: '주문 피해', value: _percent(AttributeEffects.spellDamageMultiplier(value)), active: false),
        (label: '마나 소모', value: _percent(AttributeEffects.manaCostMultiplier(value)), active: false),
      ];
    case Attribute.faith:
      return [
        (label: '권능 위력', value: _percent(AttributeEffects.invocationPowerMultiplier(value)), active: false),
        (label: '권능 성공률', value: '${_signed((AttributeEffects.invocationSuccessBonus(value) * 100).round())}%p', active: false),
        (label: '신앙심 소모', value: _percent(AttributeEffects.pietyCostMultiplier(value)), active: false),
      ];
  }
}

class _AttributeRow extends StatelessWidget {
  const _AttributeRow({required this.attribute, required this.value, required this.onIncrease});

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
              Text(attribute.label, style: const TextStyle(color: Colors.white, fontSize: 16)),
              const Spacer(),
              Text(
                '$value',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              // 포인트가 없으면 자리만 유지해 숫자 위치가 흔들리지 않게 한다.
              Visibility.maintain(
                visible: onIncrease != null,
                child: IconButton.filledTonal(onPressed: onIncrease, tooltip: '${attribute.label} +1', icon: const Icon(Icons.add)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Wrap(
              spacing: 12,
              runSpacing: 2,
              children: [
                Text(increaseGainText(attribute), style: const TextStyle(fontSize: 12, color: Color(0xFFFFD54F))),
                for (final e in attributeEffectLines(attribute, value))
                  Text(
                    e.active ? '${e.label} ${e.value}' : '${e.label} ${e.value} · 준비 중',
                    style: TextStyle(fontSize: 12, color: e.active ? const Color(0xFFD8CFBF) : const Color(0xFF6E685E)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 신앙심을 DCSS처럼 ★ 6단계로 표시.
class _PietyRow extends StatelessWidget {
  const _PietyRow({required this.piety, required this.rank});

  final int piety;
  final int rank;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('신앙심', style: TextStyle(color: Color(0xFF8A8478), fontSize: 13)),
        const SizedBox(width: 8),
        for (var i = 0; i < Player.pietyRankThresholds.length; i++)
          Icon(
            i < rank ? Icons.star : Icons.star_border,
            size: 18,
            color: i < rank ? const Color(0xFFFFD54F) : const Color(0xFF4A453E),
          ),
        const SizedBox(width: 8),
        Text('$piety / ${Player.maxPiety}', style: const TextStyle(color: Color(0xFF8A8478), fontSize: 13)),
      ],
    );
  }
}
