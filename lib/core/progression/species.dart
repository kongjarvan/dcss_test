import 'attributes.dart';

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
  ),
  elf(
    name: '엘프',
    description: '날렵하고 총명하지만 몸이 약하다. 활과 마법에 어울린다.',
    strength: 6,
    dexterity: 12,
    intelligence: 12,
    faith: 10,
  ),
  dwarf(
    name: '드워프',
    description: '강인한 힘을 지녔지만 학문과 신앙에는 다소 서툴다. 근접전에 강하다.',
    strength: 13,
    dexterity: 11,
    intelligence: 8,
    faith: 8,
  );

  const Species({
    required this.name,
    required this.description,
    required this.strength,
    required this.dexterity,
    required this.intelligence,
    required this.faith,
  });

  final String name;
  final String description;
  final int strength;
  final int dexterity;
  final int intelligence;
  final int faith;

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
