import 'package:dc_test/core/entity/actor.dart';
import 'package:dc_test/core/geometry.dart';
import 'package:dc_test/core/progression/attribute_effects.dart';
import 'package:dc_test/core/progression/attributes.dart';
import 'package:dc_test/ui/character_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

typedef E = AttributeEffects;

void main() {
  group('신앙 효과', () {
    test('기준값 10에서는 효과 없음', () {
      expect(E.invocationPowerMultiplier(10), 1.0);
      expect(E.invocationSuccessBonus(10), 0);
      expect(E.pietyCostMultiplier(10), 1.0);
    });

    test('권능 위력 +3%, 성공률 +2%p (1포인트당)', () {
      expect(E.invocationPowerMultiplier(20), closeTo(1.30, 1e-9));
      expect(E.invocationSuccessBonus(15), closeTo(0.10, 1e-9));
    });

    test('신앙심 소모 -2%, 최대 50%, 최소 1', () {
      expect(E.pietyCost(10, 20), 8);
      expect(E.pietyCost(10, 100), 5);
      expect(E.pietyCost(1, 100), 1);
    });

    test('신앙을 올리면 최대 HP +2', () {
      expect(E.gainOnIncrease(Attribute.faith), (hp: 2, mp: 0));
    });
  });

  group('신앙심', () {
    test('0에서 시작하고 0~200 범위를 벗어나지 않는다', () {
      final p = Player(pos: const Pos(0, 0));
      expect(p.piety, 0);
      p.gainPiety(500);
      expect(p.piety, Player.maxPiety);
      p.gainPiety(-999);
      expect(p.piety, 0);
    });

    test('★ 단계는 DCSS 기준값을 따른다', () {
      final p = Player(pos: const Pos(0, 0));
      for (final (piety, rank) in const [
        (0, 0),
        (29, 0),
        (30, 1),
        (50, 2),
        (99, 3),
        (100, 4),
        (120, 5),
        (160, 6),
        (200, 6),
      ]) {
        p.piety = piety;
        expect(p.pietyRank, rank, reason: 'piety $piety');
      }
    });

    test('권능 사용 시 신앙이 높을수록 신앙심을 덜 소모한다', () {
      final normal = Player(pos: const Pos(0, 0))..piety = 100;
      final devout = Player(pos: const Pos(0, 0))
        ..piety = 100
        ..attributes.increase(Attribute.faith, 10);

      expect(normal.spendPiety(10), isTrue);
      expect(normal.piety, 90);
      expect(devout.spendPiety(10), isTrue);
      expect(devout.piety, 92); // 10 × 0.8 = 8
    });

    test('신앙심이 부족하면 사용 실패, 소모되지 않음', () {
      final p = Player(pos: const Pos(0, 0))..piety = 5;
      expect(p.spendPiety(10), isFalse);
      expect(p.piety, 5);
    });
  });

  test('캐릭터 화면 신앙 효과 문구', () {
    final lines = attributeEffectLines(Attribute.faith, 15);
    expect(lines.map((e) => e.label), ['권능 위력', '권능 성공률', '신앙심 소모']);
    expect(lines.map((e) => e.value), ['+15%', '+10%p', '-10%']);
    expect(lines.every((e) => !e.active), isTrue); // 권능 시스템 전까지 준비 중
    expect(increaseGainText(Attribute.faith), 'HP +2');
  });
}
