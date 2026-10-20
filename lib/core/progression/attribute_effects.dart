import 'dart:math' as math;

import '../entity/actor.dart';
import 'attributes.dart';

/// 능력치가 각 수치에 주는 효과. 밸런스 수치는 모두 여기서 조정한다.
///
/// 능력치 [neutral](10)이 기준이며, 1포인트 높을수록 효과가 커지고
/// 낮으면 반대로 불리해진다.
abstract final class AttributeEffects {
  static const neutral = 10;

  // ── 힘 ──
  /// 근접 피해: 1포인트당 +3%
  static const meleeDamagePerPoint = 0.03;

  /// 방어구 회피 패널티: 1포인트당 -5% (힘 30이면 패널티 없음)
  static const armorPenaltyReductionPerPoint = 0.05;

  // ── 능력치를 1 올릴 때 늘어나는 최대 HP / MP ──
  static const strengthHpGain = 4;
  static const dexterityHpGain = 2;
  static const intelligenceHpGain = 1;
  static const intelligenceMpGain = 3;
  static const faithHpGain = 2;

  // ── 민첩 ──
  /// 체력 재생 속도: 1포인트당 +3%
  static const hpRegenPerPoint = 0.03;

  /// 원거리 피해: 1포인트당 +3%
  static const rangedDamagePerPoint = 0.03;

  /// 명중: 1포인트당 +1
  static const accuracyPerPoint = 1.0;

  /// 회피: 2포인트당 +1
  static const evasionPerPoint = 0.5;

  /// 은신 효율: 1포인트당 +4%
  static const stealthPerPoint = 0.04;

  // ── 지능 ──
  /// 주문 시전 시간: 1포인트당 -2% (최대 50%까지 단축)
  static const spellTimeReductionPerPoint = 0.02;

  /// 주문 성공률: 1포인트당 +2%p
  static const spellSuccessPerPoint = 0.02;

  /// 주문 피해: 1포인트당 +3%
  static const spellDamagePerPoint = 0.03;

  /// 마나 소모: 1포인트당 -2% (최대 50%까지 감소)
  static const manaCostReductionPerPoint = 0.02;

  // ── 신앙 ──
  /// 권능 위력: 1포인트당 +3%
  static const invocationPowerPerPoint = 0.03;

  /// 권능 성공률: 1포인트당 +2%p
  static const invocationSuccessPerPoint = 0.02;

  /// 권능의 신앙심 소모: 1포인트당 -2% (최대 50%까지 감소)
  static const pietyCostReductionPerPoint = 0.02;

  static int _delta(int value) => value - neutral;

  /// [attribute]를 1 올릴 때 늘어나는 최대 HP / MP.
  static ({int hp, int mp}) gainOnIncrease(Attribute attribute) =>
      switch (attribute) {
        Attribute.strength => (hp: strengthHpGain, mp: 0),
        Attribute.dexterity => (hp: dexterityHpGain, mp: 0),
        Attribute.intelligence => (
          hp: intelligenceHpGain,
          mp: intelligenceMpGain,
        ),
        Attribute.faith => (hp: faithHpGain, mp: 0),
      };

  /// 1 + delta × rate, 단 [min] 미만으로는 내려가지 않음.
  static double _bonus(int value, double rate, {double min = 0.5}) =>
      math.max(min, 1 + _delta(value) * rate);

  /// 1 - delta × rate, [0.5, 1.5] 범위.
  static double _reduction(int value, double rate, {double min = 0.5}) =>
      (1 - _delta(value) * rate).clamp(min, 1.5);

  // ── 힘 ──
  static double meleeDamageMultiplier(int strength) =>
      _bonus(strength, meleeDamagePerPoint);

  static double armorPenaltyMultiplier(int strength) =>
      _reduction(strength, armorPenaltyReductionPerPoint, min: 0);

  /// 갑옷·방패 무게로 인한 회피 감소에 힘을 반영한 값.
  static int armourEvasionPenalty(int basePenalty, int strength) =>
      (basePenalty * armorPenaltyMultiplier(strength)).round();

  // ── 민첩 ──
  static double hpRegenMultiplier(int dexterity) =>
      _bonus(dexterity, hpRegenPerPoint);

  static double rangedDamageMultiplier(int dexterity) =>
      _bonus(dexterity, rangedDamagePerPoint);

  static int accuracyBonus(int dexterity) =>
      (_delta(dexterity) * accuracyPerPoint).floor();

  static int evasionBonus(int dexterity) =>
      (_delta(dexterity) * evasionPerPoint).floor();

  static double stealthMultiplier(int dexterity) =>
      _bonus(dexterity, stealthPerPoint);

  // ── 지능 ──
  static double spellTimeMultiplier(int intelligence) =>
      _reduction(intelligence, spellTimeReductionPerPoint);

  /// 주문 시전 시간(aut)에 지능을 반영한 값.
  static int spellCastTime(int baseAut, int intelligence) =>
      math.max(1, (baseAut * spellTimeMultiplier(intelligence)).round());

  /// 주문 성공률에 더하는 값 (0.02 = +2%p).
  static double spellSuccessBonus(int intelligence) =>
      _delta(intelligence) * spellSuccessPerPoint;

  static double spellDamageMultiplier(int intelligence) =>
      _bonus(intelligence, spellDamagePerPoint);

  static double manaCostMultiplier(int intelligence) =>
      _reduction(intelligence, manaCostReductionPerPoint);

  /// 주문 마나 소모량에 지능을 반영한 값. 최소 1.
  static int manaCost(int baseCost, int intelligence) =>
      math.max(1, (baseCost * manaCostMultiplier(intelligence)).round());

  /// 기본 전투 수치에 민첩(명중·회피)을 반영한다.
  // ── 신앙 ──
  static double invocationPowerMultiplier(int faith) =>
      _bonus(faith, invocationPowerPerPoint);

  /// 권능 성공률에 더하는 값 (0.02 = +2%p).
  static double invocationSuccessBonus(int faith) =>
      _delta(faith) * invocationSuccessPerPoint;

  static double pietyCostMultiplier(int faith) =>
      _reduction(faith, pietyCostReductionPerPoint);

  /// 권능의 신앙심 소모량에 신앙을 반영한 값. 최소 1.
  static int pietyCost(int baseCost, int faith) =>
      math.max(1, (baseCost * pietyCostMultiplier(faith)).round());

  static CombatStats applyTo(CombatStats base, Attributes attributes) {
    final dex = attributes[Attribute.dexterity];
    return CombatStats(
      accuracy: math.max(1, base.accuracy + accuracyBonus(dex)),
      maxDamage: base.maxDamage,
      evasion: math.max(0, base.evasion + evasionBonus(dex)),
      armor: base.armor,
    );
  }
}
