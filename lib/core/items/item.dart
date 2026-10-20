import '../progression/skills.dart';

enum EquipSlot {
  weapon('무기'),
  armour('갑옷'),
  shield('방패');

  const EquipSlot(this.label);

  final String label;
}

/// 아이템 종류(데이터). 실제 아이템 하나하나는 [Item].
sealed class ItemType {
  const ItemType({required this.id, required this.name});

  final String id;
  final String name;
}

/// 장착하는 아이템: 무기·갑옷·방패.
sealed class EquipmentType extends ItemType {
  const EquipmentType({required super.id, required super.name});

  EquipSlot get slot;

  /// 장착/해제에 드는 시간 (aut).
  int get equipTime;
}

/// 물약. 효과는 [Potion]에 정의되어 있다.
class PotionType extends ItemType {
  PotionType._(this.potion) : super(id: potion.name, name: potion.label);

  final Potion potion;

  static final Map<Potion, PotionType> _all = {
    for (final p in Potion.values) p: PotionType._(p),
  };

  /// 물약 종류마다 하나뿐인 인스턴스 (같은 물약끼리 겹치기 위해).
  static PotionType of(Potion potion) => _all[potion]!;
}

class WeaponType extends EquipmentType {
  const WeaponType({
    required super.id,
    required super.name,
    required this.skill,
    required this.damage,
    required this.accuracy,
    required this.delay,
    this.twoHanded = false,
    this.ranged = false,
    this.reach = 1,
  });

  /// 이 무기를 다루는 숙련도.
  final Skill skill;

  /// 최대 피해 (1 ~ damage).
  final int damage;

  /// 명중 보정.
  final int accuracy;

  /// 숙련도 0일 때 공격 1회 시간 (aut). 숙련도가 오르면 줄어든다.
  final int delay;

  final bool twoHanded;

  /// 활처럼 멀리 쏘는 무기. 근접 공격에는 쓸 수 없다 (맨손으로 친다).
  final bool ranged;

  /// 근접 공격이 닿는 거리. 장병기는 2칸 (사이 칸이 막히면 안 됨).
  final int reach;

  @override
  EquipSlot get slot => EquipSlot.weapon;

  @override
  int get equipTime => 5;
}

class ArmourType extends EquipmentType {
  const ArmourType({
    required super.id,
    required super.name,
    required this.ac,
    required this.encumbrance,
  });

  /// 방어력.
  final int ac;

  /// 무게. 회피가 줄어든다 (힘으로 줄일 수 있음).
  final int encumbrance;

  @override
  EquipSlot get slot => EquipSlot.armour;

  /// 갑옷은 입고 벗는 데 5턴 (DCSS와 같음).
  @override
  int get equipTime => 50;
}

class ShieldType extends EquipmentType {
  const ShieldType({
    required super.id,
    required super.name,
    required this.block,
    required this.encumbrance,
  });

  /// 막기 수치. 높을수록 공격을 자주 막는다.
  final int block;

  final int encumbrance;

  @override
  EquipSlot get slot => EquipSlot.shield;

  @override
  int get equipTime => 10;
}

/// 아이템 하나 (물약은 여러 개가 한 묶음). 나중에 강화 수치 등이 여기에 붙는다.
class Item {
  Item(this.type, {this.quantity = 1});

  final ItemType type;

  /// 겹친 개수. 장비는 항상 1.
  int quantity;

  /// 식별 여부와 관계없는 진짜 이름. 화면에는 [Game.nameOf]를 쓴다.
  String get name => type.name;

  bool get stackable => type is PotionType;

  bool canStackWith(Item other) => stackable && other.type == type;
}

/// 물약 종류.
enum Potion {
  curing('치유 물약', 'HP를 조금 회복하고 독을 없앤다.', weight: 10),
  healWounds('상처 치료 물약', 'HP를 크게 회복한다.', weight: 6),
  magic('마나 물약', 'MP를 회복한다.', weight: 5),
  haste('가속 물약', '한동안 모든 행동이 두 배 빨라진다.', weight: 4),
  might('힘 물약', '한동안 힘이 5 오른다.', weight: 4),
  agility('민첩 물약', '한동안 민첩이 5 오른다.', weight: 4),
  brilliance('지능 물약', '한동안 지능이 5 오른다.', weight: 4),
  slowing('둔화 물약', '한동안 모든 행동이 느려진다.', weight: 3, harmful: true),
  poison('독 물약', '한동안 독에 걸려 매 턴 HP가 줄어든다.', weight: 3, harmful: true),
  experience('경험 물약', '즉시 레벨이 하나 오른다.', weight: 1),
  enlightenment('깨달음 물약', '이 층의 지도 전체가 머릿속에 떠오른다.', weight: 2);

  const Potion(
    this.label,
    this.description, {
    required this.weight,
    this.harmful = false,
  });

  final String label;
  final String description;

  /// 바닥에 생길 때의 상대 빈도.
  final int weight;

  final bool harmful;
}

/// 아이템 목록. 수치는 DCSS를 참고했다.
abstract final class ItemTypes {
  // ── 둔기 ──
  static const club = WeaponType(
    id: 'club',
    name: '몽둥이',
    skill: Skill.mace,
    damage: 5,
    accuracy: 4,
    delay: 13,
  );
  static const mace = WeaponType(
    id: 'mace',
    name: '철퇴',
    skill: Skill.mace,
    damage: 8,
    accuracy: 3,
    delay: 14,
  );

  // ── 검 ──
  static const dagger = WeaponType(
    id: 'dagger',
    name: '단검',
    skill: Skill.sword,
    damage: 4,
    accuracy: 6,
    delay: 10,
  );
  static const shortSword = WeaponType(
    id: 'short_sword',
    name: '숏소드',
    skill: Skill.sword,
    damage: 6,
    accuracy: 4,
    delay: 11,
  );
  static const longSword = WeaponType(
    id: 'long_sword',
    name: '롱소드',
    skill: Skill.sword,
    damage: 10,
    accuracy: 1,
    delay: 14,
  );

  // ── 도끼 ──
  static const handAxe = WeaponType(
    id: 'hand_axe',
    name: '손도끼',
    skill: Skill.axe,
    damage: 7,
    accuracy: 3,
    delay: 13,
  );
  static const warAxe = WeaponType(
    id: 'war_axe',
    name: '전투도끼',
    skill: Skill.axe,
    damage: 11,
    accuracy: 0,
    delay: 15,
  );

  // ── 장병기 ──
  static const spear = WeaponType(
    id: 'spear',
    name: '창',
    skill: Skill.polearm,
    damage: 6,
    accuracy: 4,
    delay: 11,
    reach: 2,
  );
  static const halberd = WeaponType(
    id: 'halberd',
    name: '할버드',
    skill: Skill.polearm,
    damage: 13,
    accuracy: -3,
    delay: 15,
    twoHanded: true,
    reach: 2,
  );

  // ── 활 ──
  static const shortbow = WeaponType(
    id: 'shortbow',
    name: '단궁',
    skill: Skill.bow,
    damage: 8,
    accuracy: 2,
    delay: 13,
    twoHanded: true,
    ranged: true,
  );
  static const longbow = WeaponType(
    id: 'longbow',
    name: '장궁',
    skill: Skill.bow,
    damage: 14,
    accuracy: 0,
    delay: 17,
    twoHanded: true,
    ranged: true,
  );

  // ── 갑옷 ──
  static const robe = ArmourType(id: 'robe', name: '로브', ac: 2, encumbrance: 0);
  static const leatherArmour = ArmourType(
    id: 'leather_armour',
    name: '가죽 갑옷',
    ac: 3,
    encumbrance: 4,
  );
  static const ringMail = ArmourType(
    id: 'ring_mail',
    name: '고리 갑옷',
    ac: 5,
    encumbrance: 7,
  );
  static const scaleMail = ArmourType(
    id: 'scale_mail',
    name: '비늘 갑옷',
    ac: 6,
    encumbrance: 11,
  );
  static const chainMail = ArmourType(
    id: 'chain_mail',
    name: '사슬 갑옷',
    ac: 8,
    encumbrance: 15,
  );
  static const plateArmour = ArmourType(
    id: 'plate_armour',
    name: '판금 갑옷',
    ac: 10,
    encumbrance: 18,
  );

  // ── 방패 ──
  static const buckler = ShieldType(
    id: 'buckler',
    name: '버클러',
    block: 3,
    encumbrance: 1,
  );
  static const kiteShield = ShieldType(
    id: 'kite_shield',
    name: '카이트 실드',
    block: 8,
    encumbrance: 4,
  );
  static const towerShield = ShieldType(
    id: 'tower_shield',
    name: '타워 실드',
    block: 13,
    encumbrance: 8,
  );

  static const List<ItemType> all = [
    club,
    mace,
    dagger,
    shortSword,
    longSword,
    handAxe,
    warAxe,
    spear,
    halberd,
    shortbow,
    longbow,
    robe,
    leatherArmour,
    ringMail,
    scaleMail,
    chainMail,
    plateArmour,
    buckler,
    kiteShield,
    towerShield,
  ];
}
