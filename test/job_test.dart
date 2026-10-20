import 'package:dc_test/core/game.dart';
import 'package:dc_test/core/progression/attributes.dart';
import 'package:dc_test/core/progression/job.dart';
import 'package:dc_test/core/progression/species.dart';
import 'package:dc_test/ui/character_sheet.dart';
import 'package:dc_test/ui/game_controller.dart';
import 'package:dc_test/ui/game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('직업별 보정: 전사 힘 +2, 마법사 지능 +2, 사냥꾼 민첩 +2', () {
    expect(Job.values, [Job.fighter, Job.wizard, Job.hunter]);
    expect(Job.fighter.adjustments, {Attribute.strength: 2});
    expect(Job.wizard.adjustments, {Attribute.intelligence: 2});
    expect(Job.hunter.adjustments, {Attribute.dexterity: 2});
  });

  test('직업별 보정치 합은 모두 같다 (+2)', () {
    for (final j in Job.values) {
      final sum = Attribute.values.map(j.adjustment).reduce((a, b) => a + b);
      expect(sum, 2, reason: j.name);
    }
  });

  test('시작 능력치 = 종족 + 직업 보정', () {
    for (final s in Species.values) {
      for (final j in Job.values) {
        final a = startingAttributes(s, j);
        for (final attr in Attribute.values) {
          expect(
            a[attr],
            s.baseValue(attr) + j.adjustment(attr),
            reason: '${s.name} ${j.name} ${attr.label}',
          );
        }
      }
    }
    // 예) 드워프 전사: 힘 13+2
    final dwarfFighter = startingAttributes(Species.dwarf, Job.fighter);
    expect(dwarfFighter[Attribute.strength], 15);
    expect(dwarfFighter[Attribute.dexterity], 11);
  });

  test('직업이 없으면 종족 능력치 그대로', () {
    final a = startingAttributes(Species.elf, null);
    for (final attr in Attribute.values) {
      expect(a[attr], Species.elf.baseValue(attr));
    }
  });

  test('선택한 직업으로 게임이 시작되고 능력치 효과에 반영된다', () {
    final human = Game.newGame(seed: 1, species: Species.human);
    final hunter = Game.newGame(
      seed: 1,
      species: Species.human,
      job: Job.hunter,
    );
    expect(hunter.player.job, Job.hunter);
    expect(hunter.player.attributes[Attribute.dexterity], 12);
    // 민첩 +2 → 명중 +2
    expect(hunter.player.stats.accuracy, human.player.stats.accuracy + 2);
  });

  testWidgets('캐릭터 화면 제목에 종족과 직업이 나온다', (tester) async {
    final controller = GameController(
      seed: 1,
      species: Species.elf,
      job: Job.wizard,
    );
    await tester.pumpWidget(
      MaterialApp(home: GameScreen(controller: controller)),
    );
    await tester.tap(find.byTooltip('적성'));
    await tester.pump();
    await tester.tap(find.byTooltip('캐릭터'));
    await tester.pumpAndSettle();
    expect(find.byType(CharacterSheet), findsOneWidget);
    expect(find.text('엘프 마법사 · 레벨 1'), findsOneWidget);
  });
}
