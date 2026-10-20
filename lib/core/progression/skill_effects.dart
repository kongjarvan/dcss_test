import 'dart:math' as math;

/// 숙련도가 장비·전투 수치에 주는 효과 (DCSS 방식). 밸런스 수치는 여기서 조정한다.
abstract final class SkillEffects {
  /// 무기 숙련도: 2레벨마다 명중 +1
  static const weaponAccuracyPerLevel = 0.5;

  /// 무기 숙련도: 레벨당 피해 +2%
  static const weaponDamagePerLevel = 0.02;

  /// 맨손격투: 2레벨마다 최대 피해 +1
  static const unarmedDamagePerLevel = 0.5;

  /// 갑옷 숙련도: 레벨당 방어력 +4.5% (DCSS와 같음)
  static const armourAcPerLevel = 0.045;

  /// 회피 숙련도: 2레벨마다 회피 +1
  static const dodgingPerLevel = 0.5;

  /// 방패술: 레벨당 막기 수치 +5%
  static const shieldBlockPerLevel = 0.05;

  /// 무게 이만큼마다 회피 -1 (판금 18 → -4).
  static const encumbrancePerEvasion = 4;

  static int weaponAccuracy(int skill) =>
      (skill * weaponAccuracyPerLevel).floor();

  static double weaponDamageMultiplier(int skill) =>
      1 + skill * weaponDamagePerLevel;

  static int unarmedDamageBonus(int skill) =>
      (skill * unarmedDamagePerLevel).floor();

  /// 숙련도 2레벨마다 공격 시간 -1 aut.
  /// 최소 시간은 기본 시간의 절반 (단, 5 aut 미만으로는 안 됨).
  static int attackDelay(int baseDelay, int skill) =>
      math.max(minAttackDelay(baseDelay), baseDelay - skill ~/ 2);

  static int minAttackDelay(int baseDelay) =>
      math.min(baseDelay, math.max(5, (baseDelay / 2).ceil()));

  static int armourAc(int baseAc, int skill) =>
      (baseAc * (1 + skill * armourAcPerLevel)).round();

  static int dodgingBonus(int skill) => (skill * dodgingPerLevel).floor();

  /// 공격이 방패에 막힐 확률 (0~1).
  static double blockChance(int block, int skill) {
    if (block <= 0) return 0;
    final b = block * (1 + skill * shieldBlockPerLevel);
    return b / (b + 15);
  }

  /// 무게로 인한 회피 감소. 힘 효과를 적용하기 전 값.
  static int encumbranceEvasionPenalty(int encumbrance) =>
      encumbrance ~/ encumbrancePerEvasion;
}
