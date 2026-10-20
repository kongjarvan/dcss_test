import 'package:dc_test/core/entity/actor.dart';
import 'package:dc_test/core/game.dart';
import 'package:dc_test/core/geometry.dart';
import 'package:dc_test/core/progression/attributes.dart';
import 'package:dc_test/core/progression/species.dart';
import 'package:dc_test/main.dart';
import 'package:dc_test/ui/game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('종족별 능력치 합은 모두 같다 (40)', () {
    for (final s in Species.values) {
      final sum = Attribute.values.map(s.baseValue).reduce((a, b) => a + b);
      expect(sum, 40, reason: s.name);
    }
  });

  test('종족별 시작 능력치', () {
    for (final (s, str, dex, intel, faith) in const [
      (Species.human, 10, 10, 10, 10),
      (Species.elf, 6, 12, 12, 10),
      (Species.dwarf, 13, 11, 8, 8),
    ]) {
      final a = s.createAttributes();
      expect(
        [
          a[Attribute.strength],
          a[Attribute.dexterity],
          a[Attribute.intelligence],
          a[Attribute.faith],
        ],
        [str, dex, intel, faith],
        reason: s.name,
      );
    }
  });

  test('종족 성향', () {
    const h = Species.human, e = Species.elf, d = Species.dwarf;
    // 인간: 고름
    expect({h.strength, h.dexterity, h.intelligence}, hasLength(1));
    // 엘프: 민첩·지능 높고 힘 낮음
    expect(e.dexterity, greaterThan(h.dexterity));
    expect(e.intelligence, greaterThan(h.intelligence));
    expect(e.strength, lessThan(h.strength));
    // 드워프: 힘 높음, 지능·신앙 조금 낮음
    expect(d.strength, greaterThan(h.strength));
    expect(d.intelligence, lessThan(h.intelligence));
    expect(d.faith, lessThan(h.faith));
  });

  test('선택한 종족의 능력치로 게임이 시작된다', () {
    final game = Game.newGame(seed: 1, species: Species.elf);
    expect(game.player.species, Species.elf);
    expect(game.player.attributes[Attribute.strength], 6);
    expect(game.player.attributes[Attribute.dexterity], 12);
    // 민첩 12 → 명중 +2, 회피 +1
    final base = Player(pos: const Pos(0, 0)).baseStats;
    expect(game.player.stats.accuracy, base.accuracy + 2);
    expect(game.player.stats.evasion, base.evasion + 1);
  });

  testWidgets('앱을 켜면 종족 선택 화면, 고르면 게임 시작', (tester) async {
    await tester.pumpWidget(const DungeonApp(seed: 42));
    expect(find.text('종족 선택'), findsOneWidget);
    for (final s in Species.values) {
      expect(find.text(s.name), findsOneWidget);
    }

    await tester.tap(find.text('드워프'));
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.text('종족 선택'), findsNothing);

    // 새 게임 → 확인 → 다시 종족 선택 화면
    await tester.tap(find.byTooltip('새 게임'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '새로 시작'));
    await tester.pumpAndSettle();
    expect(find.text('종족 선택'), findsOneWidget);
  });
}
