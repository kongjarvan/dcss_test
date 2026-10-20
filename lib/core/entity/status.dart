import '../progression/attributes.dart';

/// 일정 시간 지속되는 상태 효과.
enum Status {
  haste('가속', '다시 원래 속도로 돌아왔다.'),
  slow('둔화', '다시 원래 속도로 움직인다.'),
  might('힘 강화', '솟아오르던 힘이 빠졌다.', boosts: Attribute.strength),
  agility('민첩 강화', '몸이 다시 무거워졌다.', boosts: Attribute.dexterity),
  brilliance('지능 강화', '머리가 다시 흐려졌다.', boosts: Attribute.intelligence),
  poison('중독', '독이 모두 빠졌다.', harmful: true);

  const Status(
    this.label,
    this.expireMessage, {
    this.boosts,
    this.harmful = false,
  });

  final String label;

  /// 효과가 끝날 때 메시지.
  final String expireMessage;

  /// 강화하는 능력치 (+[attributeBoost]).
  final Attribute? boosts;

  final bool harmful;

  static const attributeBoost = 5;

  /// 같은 효과를 겹쳐 받아도 이 시간(aut)을 넘지 않는다.
  static const maxDuration = 1000;
}
