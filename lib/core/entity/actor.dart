import '../geometry.dart';
import '../time/energy.dart';
import 'monster_type.dart';

class CombatStats {
  const CombatStats({
    required this.accuracy,
    required this.maxDamage,
    required this.evasion,
    this.armor = 0,
  });

  /// 명중 판정: accuracy / (accuracy + 상대 evasion)
  final int accuracy;

  /// 피해: 1 ~ maxDamage, 상대 armor만큼 랜덤 감소
  final int maxDamage;
  final int evasion;
  final int armor;
}

abstract class Actor {
  Actor({
    required this.name,
    required this.pos,
    required this.maxHp,
    required this.stats,
    this.moveDelay = autPerTurn,
    this.attackDelay = autPerTurn,
  }) : hp = maxHp;

  final String name;
  Pos pos;
  final int maxHp;
  int hp;
  CombatStats stats;

  /// 이동 1칸에 드는 시간 (aut).
  int moveDelay;

  /// 공격 1회에 드는 시간 (aut). 무기에 따라 달라진다.
  int attackDelay;

  bool get isAlive => hp > 0;
  bool get isPlayer;
}

class Player extends Actor {
  Player({required super.pos})
    : super(
        name: '당신',
        maxHp: 30,
        stats: const CombatStats(
          accuracy: 10,
          maxDamage: 6,
          evasion: 5,
          armor: 1,
        ),
        // 임시 무기: 숏소드 (공격 1.2턴)
        attackDelay: 12,
      );

  /// 이 시간(aut)이 지날 때마다 HP 1 회복.
  static const autPerRegen = 60;
  int regenProgress = 0;

  @override
  bool get isPlayer => true;
}

class Monster extends Actor {
  Monster(this.type, {required super.pos})
    : super(
        name: type.name,
        maxHp: type.maxHp,
        stats: type.stats,
        moveDelay: type.moveDelay,
        attackDelay: type.attackDelay,
      );

  final MonsterType type;

  int get speed => type.speed;

  /// 행동력. [EnergyScheduler] 참고.
  int energy = 0;

  /// 플레이어를 발견해 추적 중인지.
  bool awake = false;

  /// 마지막으로 플레이어를 본 위치.
  Pos? lastKnownPlayerPos;

  @override
  bool get isPlayer => false;
}
