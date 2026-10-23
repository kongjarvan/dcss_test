import 'dart:math';

import 'package:dc_test/core/action/action.dart';
import 'package:dc_test/core/entity/actor.dart';
import 'package:dc_test/core/entity/monster_type.dart';
import 'package:dc_test/core/entity/status.dart';
import 'package:dc_test/core/game.dart';
import 'package:dc_test/core/geometry.dart';
import 'package:dc_test/core/items/item.dart';
import 'package:dc_test/core/world/dungeon_generator.dart';
import 'package:dc_test/core/world/dungeon_map.dart';
import 'package:dc_test/core/world/tile.dart';
import 'package:dc_test/ui/game_controller.dart';
import 'package:dc_test/ui/game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// [start]에서 걸어서 갈 수 있는 칸들.
Set<Pos> reachable(DungeonMap map, Pos start) {
  final seen = <Pos>{start};
  final queue = [start];
  while (queue.isNotEmpty) {
    final p = queue.removeLast();
    for (final d in Direction.all) {
      final q = p + d;
      if (map.contains(q) && map[q].traversable && seen.add(q)) queue.add(q);
    }
  }
  return seen;
}

int countTiles(DungeonMap map, TileType type) {
  var n = 0;
  for (var y = 0; y < map.height; y++) {
    for (var x = 0; x < map.width; x++) {
      if (map[Pos(x, y)] == type) n++;
    }
  }
  return n;
}

/// [index]번 내려가는 계단을 타고 내려간다.
void goDown(Game game, [int index = 0]) {
  game.player.pos = game.stairsDown[index];
  expect(game.playerAct(const UseStairsAction()), isTrue);
}

/// [index]번 올라가는 계단을 타고 올라간다.
void goUp(Game game, [int index = 0]) {
  game.player.pos = game.stairsUp[index];
  expect(game.playerAct(const UseStairsAction()), isTrue);
}

void main() {
  group('계단 배치', () {
    test('1층: 내려가는 계단 3개, 올라가는 계단 없음, 시작 칸이 아닌 곳', () {
      for (var seed = 0; seed < 30; seed++) {
        final level = DungeonGenerator(Random(seed)).generate();
        final map = level.map;
        expect(level.stairsDown, hasLength(3), reason: 'seed $seed');
        expect(level.stairsUp, isEmpty);
        expect(countTiles(map, TileType.stairsDown), 3);
        expect(countTiles(map, TileType.stairsUp), 0);
        final start = level.rooms.first.center;
        final canReach = reachable(map, start);
        for (final s in level.stairsDown) {
          expect(s, isNot(start));
          expect(canReach, contains(s), reason: 'seed $seed');
        }
      }
    });

    test('2층부터: 올라가는 계단 3개 + 내려가는 계단 3개, 모두 걸어서 갈 수 있음', () {
      for (var seed = 0; seed < 30; seed++) {
        final level = DungeonGenerator(Random(seed)).generate(stairsUp: 3);
        expect(level.stairsUp, hasLength(3));
        expect(level.stairsDown, hasLength(3));
        expect({...level.stairsUp, ...level.stairsDown}, hasLength(6));
        expect(countTiles(level.map, TileType.stairsUp), 3);
        final canReach = reachable(level.map, level.stairsUp.first);
        for (final s in [...level.stairsUp, ...level.stairsDown]) {
          expect(canReach, contains(s), reason: 'seed $seed');
        }
      }
    });
  });

  test('계단 위가 아니면 이동 불가, 1층에는 올라가는 계단이 없음', () {
    final game = Game.newGame(seed: 1);
    expect(game.playerAct(const UseStairsAction()), isFalse);
    expect(game.time, 0);
    expect(game.depth, 1);
    expect(game.stairsUp, isEmpty);
  });

  test('k번 계단으로 내려가면 아래층 k번 올라가는 계단에 도착, 플레이어 상태는 유지', () {
    final game = Game.newGame(seed: 1);
    final p = game.player
      ..hp = 17
      ..addStatus(Status.haste, 200)
      ..addItem(Item(ItemTypes.mace));
    game.identifiedPotions.add(Potion.curing);

    goDown(game, 2);
    expect(game.depth, 2);
    expect(p.pos, game.stairsUp[2]);
    expect(game.map[p.pos], TileType.stairsUp);
    expect(
      game.log.recent(10).map((m) => m.text),
      contains('계단을 내려가 2층에 도착했다.'),
    );
    expect(p.hp, 17);
    expect(p.has(Status.haste), isTrue);
    expect(p.inventory.any((i) => i.type == ItemTypes.mace), isTrue);
    expect(game.identifiedPotions, contains(Potion.curing));
    expect(game.map.isVisible(p.pos), isTrue);
    // 도착 지점 주변에는 몬스터를 두지 않는다.
    expect(game.monsters.where((m) => m.pos.distanceTo(p.pos) <= 1), isEmpty);
  });

  test('올라가면 위층의 같은 번호 계단에 도착하고, 위층은 그대로 남아 있다', () {
    final game = Game.newGame(seed: 4);
    final firstMap = game.map;
    final firstMonsters = game.monsters.length;
    final dropped = Item(ItemTypes.club);
    game.addFloorItem(game.stairsDown[0], dropped, noticed: true);

    goDown(game, 1);
    final secondMap = game.map;
    goUp(game, 1);

    expect(game.depth, 1);
    expect(game.map, same(firstMap)); // 새로 만들지 않고 저장된 층
    expect(game.player.pos, game.stairsDown[1]);
    expect(game.monsters.length, firstMonsters);
    expect(game.itemsAt(game.stairsDown[0]), [dropped]);
    expect(
      game.log.recent(5).map((m) => m.text),
      contains('계단을 올라 1층으로 돌아왔다.'),
    );

    // 다시 내려가면 아까의 2층 (같은 맵).
    goDown(game, 1);
    expect(game.map, same(secondMap));
    expect(game.player.pos, game.stairsUp[1]);
  });

  test('저장된 층의 도착 칸에 몬스터가 있으면 비켜 준다', () {
    final game = Game.newGame(seed: 5);
    final arrival = game.stairsDown[0];
    final blocker = Monster(MonsterTypes.goblin, pos: arrival);
    game.monsters.add(blocker);

    goDown(game, 1);
    goUp(game, 0); // 1층 0번 계단 = blocker 자리로 도착
    expect(game.depth, 1);
    expect(game.player.pos, arrival);
    expect(blocker.pos, isNot(arrival));
    expect(blocker.pos.distanceTo(arrival), lessThanOrEqualTo(2));
  });

  test('깊이 내려갈수록 방당 최대 몬스터 수가 늘어난다', () {
    final game = Game.newGame(seed: 2);
    expect(game.maxMonstersPerRoom, 2);
    for (var i = 0; i < 6; i++) {
      goDown(game);
    }
    expect(game.depth, 7);
    expect(game.maxMonstersPerRoom, 4);
    expect(game.hasVisited(3), isTrue);
  });

  test('계단 버튼: 본 계단 중 가장 가까운 곳으로 이동, 계단 위에서는 이용', () {
    final c = GameController(seed: 3);
    final game = c.game;
    game.monsters.clear();
    game.revealMap(); // 계단과 가는 길을 안다고 가정 (깨달음 물약과 같음)
    game.updateFov();
    final nearest = c.knownStairs!;
    expect(game.stairsDown, contains(nearest));
    final dist = game.travelPath(nearest)!.length;
    for (final s in game.stairsDown) {
      expect(game.travelPath(s)!.length, greaterThanOrEqualTo(dist));
    }

    // 도중에 새 아이템을 밟으면 멈출 수 있으므로 도착할 때까지 반복.
    for (var tries = 0; game.player.pos != nearest && tries < 20; tries++) {
      c.useOrGoToStairs();
      for (var i = 0; c.isTraveling && i < 2000; i++) {
        c.autoMoveStep();
      }
    }
    expect(c.onStairs, isTrue);
    c.useOrGoToStairs();
    expect(game.depth, 2);

    // 2층 도착 지점은 올라가는 계단 → 같은 버튼으로 올라간다.
    expect(c.stairsHere, TileType.stairsUp);
    expect(c.onStairs, isTrue);
    c.useOrGoToStairs();
    expect(game.depth, 1);
    c.dispose();
  });

  testWidgets('상태바 층 표시와 계단 버튼 (내려가기 ↔ 올라가기)', (tester) async {
    final controller = GameController(seed: 1);
    final game = controller.game;
    game.monsters.clear();
    await tester.pumpWidget(
      MaterialApp(home: GameScreen(controller: controller)),
    );
    expect(find.text('Lv 1 · 1층'), findsOneWidget);

    game.player.pos = game.stairsDown.first;
    game.updateFov();
    controller.waitTurn();
    await tester.pump();
    await tester.tap(find.byTooltip('계단 내려가기'));
    await tester.pump();
    expect(game.depth, 2);
    expect(find.text('Lv 1 · 2층'), findsOneWidget);

    game.monsters.clear();
    controller.waitTurn();
    await tester.pump();
    await tester.tap(find.byTooltip('계단 올라가기'));
    await tester.pump();
    expect(game.depth, 1);
    expect(find.text('Lv 1 · 1층'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5)); // 토스트 정리
  });
}
