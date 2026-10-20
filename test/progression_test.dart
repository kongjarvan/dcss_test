import 'dart:math';

import 'package:dc_test/core/action/action.dart';
import 'package:dc_test/core/entity/actor.dart';
import 'package:dc_test/core/entity/monster_type.dart';
import 'package:dc_test/core/game.dart';
import 'package:dc_test/core/geometry.dart';
import 'package:dc_test/core/korean.dart';
import 'package:dc_test/core/progression/attributes.dart';
import 'package:dc_test/core/progression/experience.dart';
import 'package:dc_test/core/world/dungeon_map.dart';
import 'package:dc_test/core/world/tile.dart';
import 'package:dc_test/core/progression/species.dart';
import 'package:dc_test/main.dart';
import 'package:dc_test/ui/character_sheet.dart';
import 'package:dc_test/ui/game_controller.dart';
import 'package:dc_test/ui/game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('필요 경험치는 레벨마다 증가한다', () {
    expect(Experience.totalForLevel(1), 0);
    expect(Experience.totalForLevel(2), 10);
    for (var l = 2; l <= Experience.maxLevel; l++) {
      expect(
        Experience.totalForLevel(l),
        greaterThan(Experience.totalForLevel(l - 1)),
      );
    }
  });

  group('레벨업', () {
    test('레벨업만으로는 HP가 늘지 않고 능력치 포인트 1개를 받는다', () {
      final p = Player(pos: const Pos(0, 0));
      expect(p.gainXp(9), isEmpty);
      expect(p.level, 1);

      expect(p.gainXp(1), [2]);
      expect(p.level, 2);
      expect(p.maxHp, Player.baseHp);
      expect(p.unspentStatPoints, 1);
    });

    test('한 번에 여러 레벨이 오르면 오른 만큼 포인트를 받는다', () {
      final p = Player(pos: const Pos(0, 0));
      expect(p.gainXp(Experience.totalForLevel(7)), [2, 3, 4, 5, 6, 7]);
      expect(p.unspentStatPoints, 6);
    });

    test('최대 레벨을 넘지 않는다', () {
      final p = Player(pos: const Pos(0, 0));
      p.gainXp(1 << 30);
      expect(p.level, Experience.maxLevel);
      expect(p.unspentStatPoints, Experience.maxLevel - 1);
    });

    test('포인트가 없으면 투자 실패', () {
      final p = Player(pos: const Pos(0, 0));
      expect(p.spendStatPoint(Attribute.strength), isFalse);
      expect(p.attributes[Attribute.strength], 10);
    });

    for (final (attribute, hp, mp) in const [
      (Attribute.strength, 4, 0),
      (Attribute.dexterity, 2, 0),
      (Attribute.intelligence, 1, 3),
      (Attribute.faith, 2, 0),
    ]) {
      test('${attribute.label}을 올리면 최대 HP +$hp, 최대 MP +$mp', () {
        final p = Player(pos: const Pos(0, 0));
        p.gainXp(Experience.totalForLevel(2));
        expect(p.spendStatPoint(attribute), isTrue);
        expect(p.attributes[attribute], 11);
        expect(p.maxHp, Player.baseHp + hp);
        expect(p.hp, Player.baseHp + hp); // 늘어난 만큼 현재치도 오른다
        expect(p.maxMp, Player.baseMp + mp);
        expect(p.mp, Player.baseMp + mp);
        expect(p.unspentStatPoints, 0);
      });
    }

    test('민첩이 높을수록 체력 재생이 빠르다', () {
      final normal = Player(pos: const Pos(0, 0));
      final agile = Player(pos: const Pos(0, 0))
        ..attributes.increase(Attribute.dexterity, 10);
      expect(normal.autPerHpRegen, Player.baseAutPerHpRegen);
      expect(agile.autPerHpRegen, lessThan(normal.autPerHpRegen));
      // 민첩 20 → 재생 속도 1.3배 → 60 / 1.3 ≈ 46
      expect(agile.autPerHpRegen, 46);
    });
  });

  test('몬스터를 처치하면 경험치를 얻는다', () {
    final map = DungeonMap(10, 10);
    for (var y = 1; y < 9; y++) {
      for (var x = 1; x < 9; x++) {
        map[Pos(x, y)] = TileType.floor;
      }
    }
    final goblin = Monster(MonsterTypes.goblin, pos: const Pos(4, 3))..hp = 1;
    final game = Game(
      rng: Random(1),
      map: map,
      player: Player(pos: const Pos(3, 3))
        ..baseStats = const CombatStats(
          accuracy: 1000,
          maxDamage: 5,
          evasion: 0,
        ),
      monsters: [goblin],
    );
    game.playerAct(const MoveAction(Direction.e));
    expect(goblin.isAlive, isFalse);
    expect(game.player.xp, MonsterTypes.goblin.xp);
    expect(game.kills, 1);
  });

  test('숫자 조사', () {
    expect(numberIGa(2), '2가');
    expect(numberIGa(3), '3이');
    expect(numberIGa(10), '10이');
    expect(numberIGa(11), '11이');
    expect(numberIGa(15), '15가');
  });

  testWidgets('캐릭터 화면에서 포인트를 투자한다', (tester) async {
    await tester.pumpWidget(const DungeonApp(seed: 42, species: Species.human));
    await tester.tap(find.byTooltip('적성'));
    await tester.pump();

    // 포인트가 없으면 + 버튼이 비활성(숨김)이다.
    await tester.tap(find.byTooltip('캐릭터'));
    await tester.pumpAndSettle();
    expect(find.text('인간 · 레벨 1'), findsOneWidget);
    expect(find.text('레벨업마다 포인트 1개'), findsOneWidget);
    for (final a in Attribute.values) {
      final plus = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('${a.label} +1'),
          matching: find.byType(IconButton),
        ),
      );
      expect(plus.onPressed, isNull);
    }
  });

  Future<GameController> pumpGame(WidgetTester tester) async {
    final controller = GameController(seed: 42);
    await tester.pumpWidget(
      MaterialApp(home: GameScreen(controller: controller)),
    );
    return controller;
  }

  Future<void> levelUpTo(
    WidgetTester tester,
    GameController controller,
    int level,
  ) async {
    controller.game.player.gainXp(Experience.totalForLevel(level));
    controller.waitTurn();
    await tester.pumpAndSettle();
  }

  testWidgets('레벨업 창은 능력치를 고르기 전엔 닫히지 않고, 고르면 자동으로 닫힌다', (tester) async {
    final controller = await pumpGame(tester);
    expect(find.byType(CharacterSheet), findsNothing);

    await levelUpTo(tester, controller, 2);
    expect(find.byType(CharacterSheet), findsOneWidget);
    expect(find.text('레벨 업! 올릴 능력치를 고르세요'), findsOneWidget);

    // 바깥 탭, 아래로 끌기, 뒤로 가기 → 닫히지 않음
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CharacterSheet), const Offset(0, 500));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(CharacterSheet), findsOneWidget);

    await tester.tap(find.byTooltip('힘 +1'));
    await tester.pumpAndSettle();
    expect(find.byType(CharacterSheet), findsNothing);
    expect(controller.game.player.attributes[Attribute.strength], 11);
    expect(controller.game.player.maxHp, Player.baseHp + 4);
  });

  testWidgets('한 번에 여러 레벨이 오르면 포인트를 모두 써야 닫힌다', (tester) async {
    final controller = await pumpGame(tester);
    await levelUpTo(tester, controller, 3);
    expect(find.text('레벨 업! 능력치를 2개 올리세요'), findsOneWidget);

    await tester.tap(find.byTooltip('지능 +1'));
    await tester.pumpAndSettle();
    expect(find.byType(CharacterSheet), findsOneWidget);
    expect(find.text('레벨 업! 올릴 능력치를 고르세요'), findsOneWidget);

    await tester.tap(find.byTooltip('민첩 +1'));
    await tester.pumpAndSettle();
    expect(find.byType(CharacterSheet), findsNothing);
    final p = controller.game.player;
    expect(p.maxHp, Player.baseHp + 1 + 2);
    expect(p.maxMp, Player.baseMp + 3);
  });

  testWidgets('캐릭터 버튼으로 직접 연 창은 자유롭게 닫힌다', (tester) async {
    await pumpGame(tester);
    await tester.tap(find.byTooltip('적성'));
    await tester.pump();
    await tester.tap(find.byTooltip('캐릭터'));
    await tester.pumpAndSettle();
    expect(find.byType(CharacterSheet), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(CharacterSheet), findsNothing);
  });
}
