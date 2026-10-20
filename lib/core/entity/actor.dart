import '../geometry.dart';
import '../progression/attribute_effects.dart';
import '../progression/attributes.dart';
import '../progression/experience.dart';
import '../progression/job.dart';
import '../progression/skills.dart';
import '../progression/species.dart';
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
    required this.baseStats,
    this.moveDelay = autPerTurn,
    this.attackDelay = autPerTurn,
  }) : hp = maxHp;

  final String name;
  Pos pos;
  int maxHp;
  int hp;

  /// 장비·능력치 반영 전 기본 전투 수치.
  CombatStats baseStats;

  /// 실제 전투에 쓰는 수치.
  CombatStats get stats => baseStats;

  /// 근접 피해 배율.
  double get meleeDamageMultiplier => 1.0;

  /// 이동 1칸에 드는 시간 (aut).
  int moveDelay;

  /// 공격 1회에 드는 시간 (aut). 무기에 따라 달라진다.
  int attackDelay;

  bool get isAlive => hp > 0;
  bool get isPlayer;
}

class Player extends Actor {
  Player({required super.pos, this.species = Species.human, this.job})
    : attributes = startingAttributes(species, job),
      skills = SkillSet(
        aptitudes: species.aptitudes,
        startingLevels: job?.startingSkills ?? const {},
      ),
      super(
        name: '당신',
        maxHp: baseHp,
        baseStats: const CombatStats(
          accuracy: 10,
          maxDamage: 6,
          evasion: 5,
          armor: 1,
        ),
        // 임시 무기: 숏소드 (공격 1.2턴)
        attackDelay: 12,
      );

  /// 시작 HP / MP (종족 무관).
  static const baseHp = 30;
  static const baseMp = 5;

  /// 민첩 10일 때 이 시간(aut)마다 HP 1 회복. 민첩이 높을수록 빨라진다.
  static const baseAutPerHpRegen = 60;

  /// 이 시간(aut)마다 MP 1 회복.
  static const autPerMpRegen = 90;

  int maxMp = baseMp;
  int mp = baseMp;

  /// 신앙심 최대치 (DCSS와 같음).
  static const maxPiety = 200;

  /// ★ 단계 기준값. 이 값 이상이면 ★1 … ★6 (DCSS와 같음).
  static const pietyRankThresholds = [30, 50, 75, 100, 120, 160];

  /// 신앙심. 권능을 쓸 때 소모한다.
  int piety = 0;

  /// 신앙심 ★ 단계 (0~6).
  int get pietyRank => pietyRankThresholds.where((t) => piety >= t).length;

  void gainPiety(int amount) => piety = (piety + amount).clamp(0, maxPiety);

  /// 권능 사용 시 실제 소모되는 신앙심. 신앙이 높을수록 적다.
  int pietyCostFor(int baseCost) =>
      AttributeEffects.pietyCost(baseCost, attributes[Attribute.faith]);

  /// 권능 비용([baseCost])만큼 신앙심을 소모. 부족하면 false.
  bool spendPiety(int baseCost) {
    final cost = pietyCostFor(baseCost);
    if (piety < cost) return false;
    piety -= cost;
    return true;
  }

  int hpRegenProgress = 0;
  int mpRegenProgress = 0;

  int get autPerHpRegen =>
      (baseAutPerHpRegen /
              AttributeEffects.hpRegenMultiplier(
                attributes[Attribute.dexterity],
              ))
          .round();

  int level = 1;

  /// 누적 경험치.
  int xp = 0;

  final Species species;

  /// 직업. 테스트 등에서 직업 없이 만들 때는 null.
  final Job? job;

  /// 숙련도. 얻는 경험치가 훈련 중인 숙련도에 나뉘어 쌓인다.
  final SkillSet skills;
  final Attributes attributes;

  /// 아직 투자하지 않은 능력치 포인트.
  int unspentStatPoints = 0;

  bool get isMaxLevel => level >= Experience.maxLevel;

  /// 민첩 → 명중·회피
  @override
  CombatStats get stats => AttributeEffects.applyTo(baseStats, attributes);

  /// 힘 → 근접 피해
  @override
  double get meleeDamageMultiplier =>
      AttributeEffects.meleeDamageMultiplier(attributes[Attribute.strength]);

  /// 경험치를 얻고, 레벨이 오르면 오른 레벨들을 순서대로 반환한다.
  List<int> gainXp(int amount) {
    xp += amount;
    final gained = <int>[];
    while (!isMaxLevel && xp >= Experience.totalForLevel(level + 1)) {
      level++;
      unspentStatPoints += Experience.statPointsPerLevel;
      gained.add(level);
    }
    return gained;
  }

  /// 능력치 포인트 1개를 [attribute]에 투자. 포인트가 없으면 false.
  bool spendStatPoint(Attribute attribute) {
    if (unspentStatPoints <= 0) return false;
    unspentStatPoints--;
    attributes.increase(attribute);
    final gain = AttributeEffects.gainOnIncrease(attribute);
    maxHp += gain.hp;
    hp += gain.hp;
    maxMp += gain.mp;
    mp += gain.mp;
    return true;
  }

  @override
  bool get isPlayer => true;
}

class Monster extends Actor {
  Monster(this.type, {required super.pos})
    : super(
        name: type.name,
        maxHp: type.maxHp,
        baseStats: type.stats,
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
