import 'dart:math' as math;

/// 경험치/레벨업 규칙. 밸런스 수치는 모두 여기서 조정한다.
abstract final class Experience {
  /// DCSS와 같은 최대 레벨.
  static const maxLevel = 27;

  /// 레벨업마다 받는 능력치 포인트. 최대 HP/MP는 포인트를 투자할 때 늘어난다
  /// ([AttributeEffects.gainOnIncrease]).
  static const statPointsPerLevel = 1;

  /// [level]에 도달하는 데 필요한 누적 경험치.
  /// 2레벨 10, 3레벨 57, 5레벨 320, 10레벨 2430, 27레벨 약 34000.
  static int totalForLevel(int level) =>
      level <= 1 ? 0 : (10 * math.pow(level - 1, 2.5)).round();
}
