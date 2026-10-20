import 'attributes.dart';
import 'skills.dart';

/// 플레이어 종족.
///
/// 시작 능력치는 합이 같도록(40) 맞춰 성향만 다르게 한다.
/// 적성(기술별 숙련 속도)은 적성 시스템을 만들 때 여기에 항목을 추가한다.
enum Species {
  human(
    name: '인간',
    description: '모든 능력치가 고르다. 어떤 길이든 무난하게 걸을 수 있다.',
    strength: 10,
    dexterity: 10,
    intelligence: 10,
    faith: 10,
    // 인간: 모든 적성 0
    aptitudes: {},
  ),
  elf(
    name: '엘프',
    description: '날렵하고 총명하지만 몸이 약하다. 활과 마법에 어울린다.',
    strength: 6,
    dexterity: 12,
    intelligence: 12,
    faith: 10,
    aptitudes: {
      Skill.mace: -2,
      Skill.sword: 1,
      Skill.axe: -2,
      Skill.polearm: -1,
      Skill.unarmed: -1,
      Skill.bow: 1,
      Skill.throwing: 1,
      Skill.armour: -2,
      Skill.dodging: 1,
      Skill.stealth: 1,
      Skill.shield: -2,
      Skill.arcane: 2,
      Skill.fire: 2,
      Skill.earth: 2,
      Skill.ice: 2,
      Skill.summoning: 2,
    },
  ),
  dwarf(
    name: '드워프',
    description: '강인한 힘을 지녔지만 학문과 신앙에는 다소 서툴다. 근접전에 강하다.',
    strength: 13,
    dexterity: 11,
    intelligence: 8,
    faith: 8,
    aptitudes: {
      Skill.mace: 2,
      Skill.axe: 2,
      Skill.bow: -2,
      Skill.armour: 2,
      Skill.dodging: -1,
      Skill.stealth: -1,
      Skill.shield: 2,
      Skill.arcane: -2,
      Skill.fire: 1,
      Skill.earth: 2,
      Skill.ice: -1,
      Skill.summoning: -1,
      Skill.invocation: -1,
    },
  );

  const Species({
    required this.name,
    required this.description,
    required this.strength,
    required this.dexterity,
    required this.intelligence,
    required this.faith,
    required this.aptitudes,
  });

  final String name;
  final String description;
  final int strength;
  final int dexterity;
  final int intelligence;
  final int faith;

  /// 숙련도 적성 (-3 ~ +3, 없으면 0). 적성 +4마다 필요 경험치 절반.
  final Map<Skill, int> aptitudes;

  int aptitude(Skill skill) => aptitudes[skill] ?? 0;

  int baseValue(Attribute attribute) => switch (attribute) {
    Attribute.strength => strength,
    Attribute.dexterity => dexterity,
    Attribute.intelligence => intelligence,
    Attribute.faith => faith,
  };

  Attributes createAttributes() => Attributes(
    strength: strength,
    dexterity: dexterity,
    intelligence: intelligence,
    faith: faith,
  );
}
