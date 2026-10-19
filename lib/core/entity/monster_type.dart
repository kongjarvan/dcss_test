import '../time/energy.dart';
import 'actor.dart';

/// 몬스터 종류 정의 (데이터).
class MonsterType {
  const MonsterType({
    required this.id,
    required this.name,
    required this.maxHp,
    required this.stats,
    this.speed = normalSpeed,
    this.moveDelay = autPerTurn,
    this.attackDelay = autPerTurn,
  });

  final String id;
  final String name;
  final int maxHp;
  final CombatStats stats;
  final int speed;
  final int moveDelay;
  final int attackDelay;
}

abstract final class MonsterTypes {
  static const goblin = MonsterType(
    id: 'goblin',
    name: '고블린',
    maxHp: 8,
    stats: CombatStats(accuracy: 6, maxDamage: 4, evasion: 4),
  );
}
