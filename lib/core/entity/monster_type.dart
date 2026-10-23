import 'dart:math';

import '../items/item.dart';
import '../time/energy.dart';
import 'actor.dart';

/// 몬스터가 생성될 때 [type]을 [chance] 확률로 장착한다.
/// 같은 부위는 목록에서 먼저 성공한 것 하나만 장착한다.
class GearChance {
  const GearChance(this.type, this.chance);

  final EquipmentType type;
  final double chance;
}

/// 몬스터 종류 정의 (데이터).
class MonsterType {
  const MonsterType({
    required this.id,
    required this.name,
    required this.maxHp,
    required this.stats,
    required this.xp,
    this.gear = const [],
    this.minDepth = 1,
    this.spawnWeight = 10,
    this.speed = normalSpeed,
    this.moveDelay = autPerTurn,
    this.attackDelay = autPerTurn,
  });

  final String id;
  final String name;
  final int maxHp;
  final CombatStats stats;

  /// 처치 시 얻는 경험치.
  final int xp;

  /// 생성 시 장비 확률. 무기가 없으면 [stats]의 맨손 수치로 공격한다.
  final List<GearChance> gear;

  /// 이 층부터 나온다.
  final int minDepth;

  /// 출현 빈도 (나올 수 있는 종류끼리의 상대값).
  final int spawnWeight;
  final int speed;
  final int moveDelay;
  final int attackDelay;
}

abstract final class MonsterTypes {
  static const goblin = MonsterType(
    id: 'goblin',
    name: '고블린',
    maxHp: 8,
    // 맨손 수치. 무기를 들면 무기의 피해·명중을 쓴다.
    stats: CombatStats(accuracy: 6, maxDamage: 3, evasion: 4),
    xp: 6,
    gear: [
      GearChance(ItemTypes.club, 0.4),
      GearChance(ItemTypes.dagger, 0.3),
      GearChance(ItemTypes.shortSword, 0.1),
      GearChance(ItemTypes.leatherArmour, 0.15),
    ],
  );

  static const orc = MonsterType(
    id: 'orc',
    name: '오크',
    maxHp: 12,
    stats: CombatStats(accuracy: 8, maxDamage: 4, evasion: 3),
    xp: 10,
    minDepth: 2,
    spawnWeight: 6,
    gear: [
      GearChance(ItemTypes.handAxe, 0.3),
      GearChance(ItemTypes.club, 0.25),
      GearChance(ItemTypes.spear, 0.15),
      GearChance(ItemTypes.shortSword, 0.1),
      GearChance(ItemTypes.ringMail, 0.15),
      GearChance(ItemTypes.leatherArmour, 0.25),
    ],
  );

  /// 출현할 수 있는 모든 몬스터. 새 몬스터는 여기에 추가한다.
  static const all = [goblin, orc];

  /// [depth]층에 나올 수 있는 몬스터 중 하나를 출현 빈도에 따라 고른다.
  static MonsterType randomFor(int depth, Random rng) {
    final pool = all.where((t) => t.minDepth <= depth).toList();
    var roll = rng.nextInt(pool.fold(0, (sum, t) => sum + t.spawnWeight));
    for (final t in pool) {
      roll -= t.spawnWeight;
      if (roll < 0) return t;
    }
    return pool.last;
  }
}
