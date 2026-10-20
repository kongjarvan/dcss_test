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

  EquipSlot get slot;

  /// 장착/해제에 드는 시간 (aut).
  int get equipTime;
}

class WeaponType extends ItemType {
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

class ArmourType extends ItemType {
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

class ShieldType extends ItemType {
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

/// 아이템 하나. 나중에 강화 수치 등이 여기에 붙는다.
class Item {
  Item(this.type);

  final ItemType type;

  String get name => type.name;
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
