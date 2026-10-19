import 'dart:math';

import 'package:dc_test/core/action/action.dart';
import 'package:dc_test/core/entity/actor.dart';
import 'package:dc_test/core/entity/monster_type.dart';
import 'package:dc_test/core/game.dart';
import 'package:dc_test/core/geometry.dart';
import 'package:dc_test/core/progression/attribute_effects.dart';
import 'package:dc_test/core/progression/attributes.dart';
import 'package:dc_test/core/world/dungeon_map.dart';
import 'package:dc_test/core/world/tile.dart';
import 'package:dc_test/ui/character_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

typedef E = AttributeEffects;

void main() {
  group('기준값 10에서는 효과 없음', () {
    test('모든 배율 1.0, 보너스 0', () {
      expect(E.meleeDamageMultiplier(10), 1.0);
      expect(E.armorPenaltyMultiplier(10), 1.0);
      expect(E.rangedDamageMultiplier(10), 1.0);
      expect(E.accuracyBonus(10), 0);
      expect(E.evasionBonus(10), 0);
      expect(E.stealthMultiplier(10), 1.0);
      expect(E.spellTimeMultiplier(10), 1.0);
      expect(E.spellSuccessBonus(10), 0);
      expect(E.spellDamageMultiplier(10), 1.0);
      expect(E.manaCostMultiplier(10), 1.0);
    });
  });

  group('힘', () {
    test('근접 피해 1포인트당 +3%', () {
      expect(E.meleeDamageMultiplier(20), closeTo(1.30, 1e-9));
    });

    test('방어구 이동 패널티: 힘 20이면 절반, 30 이상이면 없음', () {
      expect(E.armorMovePenalty(4, 20), 2);
      expect(E.armorMovePenalty(4, 30), 0);
      expect(E.armorMovePenalty(4, 40), 0);
      expect(E.armorMovePenalty(4, 10), 4);
    });
  });

  group('민첩', () {
    test('명중 1포인트당 +1, 회피 2포인트당 +1', () {
      expect(E.accuracyBonus(15), 5);
      expect(E.evasionBonus(15), 2);
      expect(E.evasionBonus(16), 3);
    });

    test('원거리 피해 +3%, 은신 +4% (1포인트당)', () {
      expect(E.rangedDamageMultiplier(20), closeTo(1.30, 1e-9));
      expect(E.stealthMultiplier(15), closeTo(1.20, 1e-9));
    });
  });

  group('지능', () {
    test('주문 시전 시간 -2%, 최대 50%까지', () {
      expect(E.spellCastTime(10, 20), 8);
      expect(E.spellCastTime(10, 100), 5);
    });

    test('성공률 +2%p, 주문 피해 +3%', () {
      expect(E.spellSuccessBonus(15), closeTo(0.10, 1e-9));
      expect(E.spellDamageMultiplier(20), closeTo(1.30, 1e-9));
    });

    test('마나 소모 -2%, 최소 1', () {
      expect(E.manaCost(10, 20), 8);
      expect(E.manaCost(10, 100), 5);
      expect(E.manaCost(1, 100), 1);
    });
  });

  group('전투에 적용', () {
    test('민첩이 플레이어 명중·회피에 반영된다', () {
      final p = Player(pos: const Pos(0, 0));
      final base = p.baseStats;
      p.attributes.increase(Attribute.dexterity, 6);
      expect(p.stats.accuracy, base.accuracy + 6);
      expect(p.stats.evasion, base.evasion + 3);
      expect(p.stats.maxDamage, base.maxDamage);
    });

    test('힘이 높을수록 근접 평균 피해가 커진다', () {
      double averageDamage(int strength) {
        const trials = 4000;
        var total = 0;
        final rng = Random(7);
        for (var i = 0; i < trials; i++) {
          final map = DungeonMap(5, 3)..[const Pos(1, 1)] = TileType.floor;
          map[const Pos(2, 1)] = TileType.floor;
          final player = Player(pos: const Pos(1, 1))
            ..baseStats = const CombatStats(
              accuracy: 1000,
              maxDamage: 6,
              evasion: 0,
            );
          player.attributes.increase(Attribute.strength, strength - 10);
          final target = Monster(MonsterTypes.goblin, pos: const Pos(2, 1))
            ..hp = 1000;
          final game = Game(
            rng: Random(rng.nextInt(1 << 30)),
            map: map,
            player: player,
            monsters: [target],
          );
          AttackAction(target).perform(game, player);
          total += 1000 - target.hp;
        }
        return total / trials;
      }

      final normal = averageDamage(10); // 1d6 평균 3.5
      final strong = averageDamage(20); // × 1.3 → 4.55
      expect(normal, closeTo(3.5, 0.15));
      expect(strong, closeTo(3.5 * 1.3, 0.2));
    });
  });

  test('캐릭터 화면 효과 문구', () {
    final str = attributeEffectLines(Attribute.strength, 15);
    expect(str.first, (label: '근접 피해', value: '+15%', active: true));
    final intel = attributeEffectLines(Attribute.intelligence, 15);
    expect(intel.every((e) => !e.active), isTrue);
    expect(intel[1].value, '+10%p');
    expect(intel[3].value, '-10%'); // 마나 소모 감소
  });
}
