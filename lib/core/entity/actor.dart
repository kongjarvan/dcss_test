import 'dart:math' as math;

import '../geometry.dart';
import '../items/item.dart';
import 'status.dart';
import '../progression/attribute_effects.dart';
import '../progression/attributes.dart';
import '../progression/experience.dart';
import '../progression/job.dart';
import '../progression/skill_effects.dart';
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

  /// 맨손(또는 몬스터 기본) 공격 1회에 드는 시간 (aut).
  int attackDelay;

  /// 실제 근접 공격 1회 시간 (aut). 플레이어는 무기·숙련도에 따라 달라진다.
  int get meleeDelay => attackDelay;

  /// 받은 공격을 막을 확률 (0~1).
  double get blockChance => 0;

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
        // 맨손 기준 수치. 무기·갑옷은 [stats]에서 더한다.
        baseStats: const CombatStats(accuracy: 10, maxDamage: 3, evasion: 5),
      ) {
    for (final type in job?.startingItems ?? const <ItemType>[]) {
      final item = Item(type);
      addItem(item);
      if (type is EquipmentType) equip(item);
    }
  }

  // ── 소지품 / 장비 ──
  static const inventoryCapacity = 20;

  final List<Item> inventory = [];
  final Map<EquipSlot, Item> _equipped = {};

  Item? equipped(EquipSlot slot) => _equipped[slot];
  bool isEquipped(Item item) => switch (item.type) {
    EquipmentType(:final slot) => _equipped[slot] == item,
    _ => false,
  };
  bool get isInventoryFull => inventory.length >= inventoryCapacity;

  /// 소지품에 넣는다. 물약은 같은 종류와 겹친다. 자리가 없으면 false.
  bool addItem(Item item) {
    for (final owned in inventory) {
      if (owned.canStackWith(item)) {
        owned.quantity += item.quantity;
        return true;
      }
    }
    if (isInventoryFull) return false;
    inventory.add(item);
    return true;
  }

  /// [item]을 [count]개 소지품에서 뺀다 (다 쓰면 칸이 비워진다).
  void consume(Item item, [int count = 1]) {
    item.quantity -= count;
    if (item.quantity <= 0) inventory.remove(item);
  }

  WeaponType? get weaponType =>
      _equipped[EquipSlot.weapon]?.type as WeaponType?;
  ArmourType? get armourType =>
      _equipped[EquipSlot.armour]?.type as ArmourType?;
  ShieldType? get shieldType =>
      _equipped[EquipSlot.shield]?.type as ShieldType?;

  /// 근접 공격에 쓰는 무기. 활은 근접에 못 쓰므로 맨손(null).
  WeaponType? get meleeWeapon => weaponType?.ranged == true ? null : weaponType;

  /// 근접 공격이 닿는 거리 (맨손·일반 무기 1, 장병기 2).
  int get reach => meleeWeapon?.reach ?? 1;

  /// 장착한 활. 없으면 null.
  WeaponType? get launcher => weaponType?.ranged == true ? weaponType : null;

  /// [item]을 장착할 수 없는 이유. 장착 가능하면 null.
  String? equipProblem(Item item) {
    final type = item.type;
    if (type is! EquipmentType) return '장착할 수 없는 아이템이다.';
    if (type is WeaponType && type.twoHanded && shieldType != null) {
      return '양손 무기를 들려면 먼저 방패를 벗어야 한다.';
    }
    if (type is ShieldType && weaponType?.twoHanded == true) {
      return '양손 무기를 든 채로는 방패를 들 수 없다.';
    }
    return null;
  }

  /// 같은 부위의 장비는 바꿔 낀다. 소지품에 있는 아이템이어야 한다.
  void equip(Item item) {
    assert(inventory.contains(item));
    _equipped[(item.type as EquipmentType).slot] = item;
  }

  // ── 상태 효과 ──
  /// 상태 효과와 남은 시간 (aut).
  final Map<Status, int> statuses = {};

  /// 중독 피해 누적 (10 aut마다 HP 1).
  int poisonProgress = 0;

  bool has(Status status) => statuses.containsKey(status);

  /// 상태 효과를 건다. 이미 걸려 있으면 시간이 늘어난다 (상한 있음).
  void addStatus(Status status, int aut) {
    statuses[status] = math.min(
      Status.maxDuration,
      (statuses[status] ?? 0) + aut,
    );
  }

  /// 상태 효과까지 반영한 능력치. 전투·재생 계산은 모두 이 값을 쓴다.
  int attribute(Attribute a) =>
      attributes[a] +
      statuses.keys.where((s) => s.boosts == a).length * Status.attributeBoost;

  Attributes get effectiveAttributes => Attributes(
    strength: attribute(Attribute.strength),
    dexterity: attribute(Attribute.dexterity),
    intelligence: attribute(Attribute.intelligence),
    faith: attribute(Attribute.faith),
  );

  /// 행동 시간 배율: 가속 ×0.5, 둔화 ×1.5 (둘 다면 상쇄).
  double get actionTimeMultiplier =>
      switch ((has(Status.haste), has(Status.slow))) {
        (true, false) => 0.5,
        (false, true) => 1.5,
        _ => 1.0,
      };

  Item? unequip(EquipSlot slot) => _equipped.remove(slot);

  int get _encumbrance =>
      (armourType?.encumbrance ?? 0) + (shieldType?.encumbrance ?? 0);

  int _skill(Skill skill) => skills.level(skill);

  /// 근접 무기(없으면 맨손격투) 숙련도.
  int get _meleeSkill => _skill(meleeWeapon?.skill ?? Skill.unarmed);

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
      AttributeEffects.pietyCost(baseCost, attribute(Attribute.faith));

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
                attribute(Attribute.dexterity),
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

  /// 근접 전투 수치 = 기본 + 민첩 + 무기 + 갑옷 + 숙련도.
  @override
  CombatStats get stats {
    final s = AttributeEffects.applyTo(baseStats, effectiveAttributes);
    final weapon = meleeWeapon;
    final armour = armourType;
    return CombatStats(
      accuracy: math.max(
        1,
        s.accuracy +
            (weapon?.accuracy ?? 0) +
            SkillEffects.weaponAccuracy(_meleeSkill),
      ),
      maxDamage:
          weapon?.damage ??
          s.maxDamage + SkillEffects.unarmedDamageBonus(_meleeSkill),
      evasion: math.max(
        0,
        s.evasion +
            SkillEffects.dodgingBonus(_skill(Skill.dodging)) -
            armourEvasionPenalty,
      ),
      armor:
          s.armor +
          (armour == null
              ? 0
              : SkillEffects.armourAc(armour.ac, _skill(Skill.armour))),
    );
  }

  /// 힘 × 무기 숙련도 → 근접 피해
  @override
  double get meleeDamageMultiplier =>
      AttributeEffects.meleeDamageMultiplier(attribute(Attribute.strength)) *
      SkillEffects.weaponDamageMultiplier(_meleeSkill);

  @override
  int get meleeDelay =>
      SkillEffects.attackDelay(meleeWeapon?.delay ?? attackDelay, _meleeSkill);

  /// 갑옷·방패 무게로 인한 회피 감소. 힘이 높을수록 덜 줄어든다.
  int get armourEvasionPenalty => AttributeEffects.armourEvasionPenalty(
    SkillEffects.encumbranceEvasionPenalty(_encumbrance),
    attribute(Attribute.strength),
  );

  @override
  double get blockChance =>
      SkillEffects.blockChance(shieldType?.block ?? 0, _skill(Skill.shield));

  // ── 원거리 (활) ──
  /// 원거리 전투 수치. 활이 없으면 null.
  CombatStats? get rangedStats {
    final bow = launcher;
    if (bow == null) return null;
    final s = stats;
    return CombatStats(
      accuracy: math.max(
        1,
        AttributeEffects.applyTo(baseStats, effectiveAttributes).accuracy +
            bow.accuracy +
            SkillEffects.weaponAccuracy(_skill(bow.skill)),
      ),
      maxDamage: bow.damage,
      evasion: s.evasion,
      armor: s.armor,
    );
  }

  /// 민첩 × 활 숙련도 → 원거리 피해
  double get rangedDamageMultiplier =>
      AttributeEffects.rangedDamageMultiplier(attribute(Attribute.dexterity)) *
      SkillEffects.weaponDamageMultiplier(_skill(launcher?.skill ?? Skill.bow));

  int get rangedDelay => SkillEffects.attackDelay(
    launcher?.delay ?? attackDelay,
    _skill(launcher?.skill ?? Skill.bow),
  );

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
