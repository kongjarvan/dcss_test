import 'attributes.dart';
import 'species.dart';

/// 플레이어 직업.
///
/// 종족 능력치에 직업 보정치를 더해 시작 능력치가 정해진다.
/// 보정치 합은 모든 직업이 같도록(+2) 맞춘다.
/// 숙련도 보정은 숙련도 시스템을 만들 때 여기에 항목을 추가한다.
enum Job {
  fighter(
    name: '전사',
    description: '무기와 갑옷에 익숙한 근접전의 달인.',
    adjustments: {Attribute.strength: 2},
  ),
  wizard(
    name: '마법사',
    description: '몸은 약하지만 강력한 주문을 다룬다.',
    adjustments: {Attribute.intelligence: 2},
  ),
  hunter(
    name: '사냥꾼',
    description: '활과 덫을 다루며 먼 거리에서 적을 쓰러뜨린다.',
    adjustments: {Attribute.dexterity: 2},
  );

  const Job({
    required this.name,
    required this.description,
    required this.adjustments,
  });

  final String name;
  final String description;

  /// 능력치 보정치. 없는 능력치는 0.
  final Map<Attribute, int> adjustments;

  int adjustment(Attribute attribute) => adjustments[attribute] ?? 0;
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
