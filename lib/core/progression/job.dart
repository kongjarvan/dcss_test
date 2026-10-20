import '../items/item.dart';
import 'attributes.dart';
import 'skills.dart';
import 'species.dart';

/// 플레이어 직업.
///
/// 종족 능력치에 직업 보정치를 더해 시작 능력치가 정해진다.
/// 보정치 합은 모든 직업이 같도록(+2) 맞춘다.
/// 시작 숙련도도 직업이 정한다.
enum Job {
  fighter(
    name: '전사',
    description: '무기와 갑옷에 익숙한 근접전의 달인.',
    adjustments: {Attribute.strength: 2},
    startingSkills: {
      Skill.sword: 3,
      Skill.armour: 2,
      Skill.shield: 2,
      Skill.dodging: 1,
    },
    startingItems: [
      ItemTypes.shortSword,
      ItemTypes.leatherArmour,
      ItemTypes.buckler,
    ],
  ),
  wizard(
    name: '마법사',
    description: '몸은 약하지만 강력한 주문을 다룬다.',
    adjustments: {Attribute.intelligence: 2},
    startingSkills: {
      Skill.arcane: 3,
      Skill.fire: 1,
      Skill.ice: 1,
      Skill.dodging: 2,
      Skill.stealth: 1,
    },
    startingItems: [ItemTypes.robe],
  ),
  hunter(
    name: '사냥꾼',
    description: '활과 덫을 다루며 먼 거리에서 적을 쓰러뜨린다.',
    adjustments: {Attribute.dexterity: 2},
    startingSkills: {
      Skill.bow: 3,
      Skill.throwing: 1,
      Skill.dodging: 2,
      Skill.stealth: 2,
    },
    startingItems: [ItemTypes.shortbow, ItemTypes.leatherArmour],
  );

  const Job({
    required this.name,
    required this.description,
    required this.adjustments,
    required this.startingSkills,
    required this.startingItems,
  });

  final String name;
  final String description;

  /// 능력치 보정치. 없는 능력치는 0.
  final Map<Attribute, int> adjustments;

  int adjustment(Attribute attribute) => adjustments[attribute] ?? 0;

  /// 시작 숙련도 레벨. 시작 시 이 숙련도들이 훈련 중으로 켜진다.
  final Map<Skill, int> startingSkills;

  /// 시작 장비. 시작 시 모두 장착한다.
  final List<ItemType> startingItems;
}

/// [species] 기본 능력치에 [job] 보정치를 더한 시작 능력치.
/// [job]이 null이면 종족 능력치 그대로 (테스트 등).
Attributes startingAttributes(Species species, Job? job) {
  final attributes = species.createAttributes();
  if (job != null) {
    for (final MapEntry(key: attribute, value: amount)
        in job.adjustments.entries) {
      attributes.increase(attribute, amount);
    }
  }
  return attributes;
}
