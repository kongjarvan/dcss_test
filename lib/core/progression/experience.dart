import 'dart:math' as math;

/// 경험치/레벨업 규칙. 밸런스 수치는 모두 여기서 조정한다.
abstract final class Experience {
  /// DCSS와 같은 최대 레벨.
  static const maxLevel = 27;

  /// 레벨업마다 늘어나는 최대 HP. (임시값 — 능력치 효과가 정해지면 바뀔 수 있음)
  static const hpPerLevel = 4;

  /// 이 레벨 간격마다 능력치 포인트 1개 (3, 6, 9, … 레벨).
  static const statPointInterval = 3;

  /// [level]에 도달하는 데 필요한 누적 경험치.
  /// 2레벨 10, 3레벨 57, 5레벨 320, 10레벨 2430, 27레벨 약 34000.
  static int totalForLevel(int level) =>
      level <= 1 ? 0 : (10 * math.pow(level - 1, 2.5)).round();
}
