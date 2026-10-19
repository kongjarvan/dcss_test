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
import 'package:dc_test/main.dart';
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
    test('경험치가 차면 레벨이 오르고 최대 HP가 늘어난다', () {
      final p = Player(pos: const Pos(0, 0));
      expect(p.gainXp(9), isEmpty);
      expect(p.level, 1);

      expect(p.gainXp(1), [2]);
      expect(p.level, 2);
      expect(p.maxHp, 30 + Experience.hpPerLevel);
      expect(p.hp, 30 + Experience.hpPerLevel);
      expect(p.unspentStatPoints, 0);
    });

    test('한 번에 여러 레벨이 오를 수 있고 3레벨마다 포인트를 받는다', () {
      final p = Player(pos: const Pos(0, 0));
      expect(p.gainXp(Experience.totalForLevel(7)), [2, 3, 4, 5, 6, 7]);
      expect(p.unspentStatPoints, 2); // 3, 6레벨
    });

    test('최대 레벨을 넘지 않는다', () {
      final p = Player(pos: const Pos(0, 0));
      p.gainXp(1 << 30);
      expect(p.level, Experience.maxLevel);
      expect(p.unspentStatPoints, Experience.maxLevel ~/ 3);
    });

    test('포인트를 투자하면 능력치가 1 오르고, 포인트가 없으면 실패', () {
      final p = Player(pos: const Pos(0, 0));
      expect(p.spendStatPoint(Attribute.strength), isFalse);
      p.gainXp(Experience.totalForLevel(3));
      expect(p.spendStatPoint(Attribute.dexterity), isTrue);
      expect(p.attributes[Attribute.dexterity], 11);
      expect(p.attributes[Attribute.strength], 10);
      expect(p.unspentStatPoints, 0);
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
    await tester.pumpWidget(const DungeonApp(seed: 42));
    await tester.tap(find.byTooltip('적성'));
    await tester.pump();

    // 포인트가 없으면 + 버튼이 비활성(숨김)이다.
    await tester.tap(find.byTooltip('캐릭터'));
    await tester.pumpAndSettle();
    expect(find.text('레벨 1'), findsOneWidget);
    expect(find.text('3레벨마다 포인트 1개'), findsOneWidget);
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
}
