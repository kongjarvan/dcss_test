import 'dart:math';

import 'package:dc_test/core/action/action.dart';
import 'package:dc_test/core/entity/actor.dart';
import 'package:dc_test/core/entity/status.dart';
import 'package:dc_test/core/game.dart';
import 'package:dc_test/core/geometry.dart';
import 'package:dc_test/core/items/item.dart';
import 'package:dc_test/core/items/potion_appearance.dart';
import 'package:dc_test/core/progression/attributes.dart';
import 'package:dc_test/core/world/dungeon_map.dart';
import 'package:dc_test/core/world/tile.dart';
import 'package:dc_test/ui/game_controller.dart';
import 'package:dc_test/ui/game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Game newGame({int seed = 1}) {
  final map = DungeonMap(12, 8);
  for (var y = 1; y < 7; y++) {
    for (var x = 1; x < 11; x++) {
      map[Pos(x, y)] = TileType.floor;
    }
  }
  return Game(
    rng: Random(seed),
    map: map,
    player: Player(pos: const Pos(3, 3)),
  );
}

Item give(Game game, Potion potion, {int quantity = 1}) {
  final item = Item(PotionType.of(potion), quantity: quantity);
  game.player.addItem(item);
  return game.player.inventory.firstWhere((i) => i.canStackWith(item));
}

void quaff(Game game, Potion potion) {
  final item = give(game, potion);
  expect(game.playerAct(QuaffAction(item)), isTrue);
}

void main() {
  group('식별', () {
    test('게임마다 물약 종류에 서로 다른 색이 배정된다', () {
      expect(
        PotionAppearance.all.length,
        greaterThanOrEqualTo(Potion.values.length),
      );
      final game = newGame();
      final names = Potion.values.map((p) => game.potionAppearance[p]!.name);
      expect(names.toSet(), hasLength(Potion.values.length));
      // 다른 시드면 배정이 달라진다.
      final other = newGame(seed: 2);
      expect(
        Potion.values.any(
          (p) => other.potionAppearance[p] != game.potionAppearance[p],
        ),
        isTrue,
      );
    });

    test('마시기 전에는 색 이름, 마시면 같은 종류가 모두 식별된다', () {
      final game = newGame();
      final a = Item(PotionType.of(Potion.magic), quantity: 2);
      game.player.addItem(a);
      final look = game.potionAppearance[Potion.magic]!.name;
      expect(game.nameOf(a), '$look 물약 2개');
      expect(game.isIdentified(a), isFalse);

      game.playerAct(QuaffAction(a));
      expect(
        game.log.recent(10).map((m) => m.text),
        contains('$look 물약을 마셨다. 마나 물약이었다!'),
      );
      expect(game.nameOf(a), '마나 물약');
      expect(game.isIdentified(a), isTrue);

      // 바닥의 같은 종류도 식별된 이름으로 보인다.
      final floor = Item(PotionType.of(Potion.magic));
      expect(game.nameOf(floor), '마나 물약');
    });
  });

  group('겹치기', () {
    test('같은 물약은 한 칸에 겹치고, 마시면 하나씩 줄어든다', () {
      final game = newGame();
      give(game, Potion.curing);
      final stack = give(game, Potion.curing, quantity: 2);
      give(game, Potion.haste);
      expect(game.player.inventory, hasLength(2));
      expect(stack.quantity, 3);

      game.playerAct(QuaffAction(stack));
      expect(stack.quantity, 2);
      game.playerAct(QuaffAction(stack));
      game.playerAct(QuaffAction(stack));
      expect(game.player.inventory.contains(stack), isFalse);
    });

    test('주우면 가진 물약과 합쳐지고 칸을 더 쓰지 않는다', () {
      final game = newGame();
      final p = game.player;
      give(game, Potion.curing);
      for (var i = 0; p.inventory.length < Player.inventoryCapacity; i++) {
        p.addItem(Item(ItemTypes.dagger));
      }
      game.addFloorItem(p.pos, Item(PotionType.of(Potion.curing)));
      expect(game.playerAct(const PickUpAction()), isTrue);
      expect(p.inventory.first.quantity, 2);
    });

    test('마시는 데 1턴', () {
      final game = newGame();
      quaff(game, Potion.curing);
      expect(game.lastActionCost, 10);
    });
  });

  group('효과', () {
    test('치유: HP 회복 + 독 해제', () {
      final game = newGame();
      final p = game.player
        ..hp = 10
        ..addStatus(Status.poison, 100);
      quaff(game, Potion.curing);
      expect(p.hp, inInclusiveRange(15, 21));
      expect(p.has(Status.poison), isFalse);
    });

    test('상처 치료: HP 크게 회복 (최대치를 넘지 않음)', () {
      final game = newGame();
      final p = game.player..hp = 1;
      quaff(game, Potion.healWounds);
      expect(p.hp, inInclusiveRange(16, 26));
      quaff(game, Potion.healWounds);
      quaff(game, Potion.healWounds);
      expect(p.hp, p.maxHp);
    });

    test('마나: MP 회복', () {
      final game = newGame();
      final p = game.player
        ..maxMp = 30
        ..mp = 0;
      quaff(game, Potion.magic);
      expect(p.mp, inInclusiveRange(8, 13));
    });

    test('가속: 행동 시간 절반, 끝나면 메시지', () {
      final game = newGame();
      quaff(game, Potion.haste);
      expect(game.player.has(Status.haste), isTrue);
      game.playerAct(const WaitAction());
      expect(game.lastActionCost, 5);
      for (var i = 0; i < 200 && game.player.has(Status.haste); i++) {
        game.playerAct(const WaitAction());
      }
      expect(game.player.has(Status.haste), isFalse);
      expect(
        game.log.recent(5).map((m) => m.text),
        contains(Status.haste.expireMessage),
      );
    });

    test('둔화: 행동 시간 1.5배, 가속과 함께면 상쇄', () {
      final game = newGame();
      quaff(game, Potion.slowing);
      game.playerAct(const WaitAction());
      expect(game.lastActionCost, 15);
      quaff(game, Potion.haste);
      game.playerAct(const WaitAction());
      expect(game.lastActionCost, 10);
    });

    test('힘·민첩·지능 물약: 해당 능력치 +5 (효과도 반영)', () {
      final game = newGame();
      final p = game.player;
      final acc = p.stats.accuracy;
      final mult = p.meleeDamageMultiplier;
      quaff(game, Potion.might);
      quaff(game, Potion.agility);
      quaff(game, Potion.brilliance);
      expect(p.attribute(Attribute.strength), 15);
      expect(p.attribute(Attribute.dexterity), 15);
      expect(p.attribute(Attribute.intelligence), 15);
      expect(p.attributes[Attribute.strength], 10); // 기본값은 그대로
      expect(p.stats.accuracy, acc + 5);
      expect(p.meleeDamageMultiplier, greaterThan(mult));
    });

    test('독: 매 턴 HP -1, 그동안 재생 없음, 끝나면 메시지', () {
      final game = newGame();
      final p = game.player..hp = 20;
      quaff(game, Potion.poison);
      expect(p.has(Status.poison), isTrue);
      final hp = p.hp;
      for (var i = 0; i < 5; i++) {
        game.playerAct(const WaitAction());
      }
      expect(p.hp, hp - 5);
      for (var i = 0; i < 30 && p.has(Status.poison); i++) {
        game.playerAct(const WaitAction());
      }
      expect(p.has(Status.poison), isFalse);
      expect(
        game.log.recent(5).map((m) => m.text),
        contains(Status.poison.expireMessage),
      );
    });

    test('독으로 죽을 수 있다', () {
      final game = newGame();
      game.player.hp = 2;
      quaff(game, Potion.poison);
      for (var i = 0; i < 10 && !game.isGameOver; i++) {
        game.playerAct(const WaitAction());
      }
      expect(game.isGameOver, isTrue);
      expect(game.log.recent(1).single.text, '당신은 독으로 죽었다...');
    });

    test('경험: 즉시 레벨 +1', () {
      final game = newGame();
      quaff(game, Potion.experience);
      expect(game.player.level, 2);
      expect(game.player.unspentStatPoints, 1);
    });

    test('깨달음: 이 층의 모든 바닥이 밝혀진다', () {
      final game = Game.newGame(seed: 3);
      quaff(game, Potion.enlightenment);
      final map = game.map;
      for (var y = 0; y < map.height; y++) {
        for (var x = 0; x < map.width; x++) {
          final p = Pos(x, y);
          if (map[p].traversable) expect(map.isExplored(p), isTrue);
        }
      }
    });
  });

  test('바닥 생성: 물약이 놓이고, 빈도는 가중치를 따른다', () {
    var potions = 0;
    for (var seed = 0; seed < 20; seed++) {
      final game = Game.newGame(seed: seed);
      for (final p in game.itemPositions) {
        potions += game.itemsAt(p).where((i) => i.type is PotionType).length;
      }
    }
    expect(potions, greaterThan(50));

    final rng = Random(7);
    final counts = <Potion, int>{};
    for (var i = 0; i < 20000; i++) {
      final p = Game.randomPotion(rng);
      counts[p] = (counts[p] ?? 0) + 1;
    }
    expect(counts[Potion.curing]!, greaterThan(counts[Potion.experience]! * 5));
  });

  testWidgets('아이템 탭의 마시기 버튼으로 물약을 마시고 상태가 표시된다', (tester) async {
    final controller = GameController(seed: 1);
    final game = controller.game;
    game.monsters.clear();
    game.updateFov();
    await tester.pumpWidget(
      MaterialApp(home: GameScreen(controller: controller)),
    );

    await tester.tap(find.byTooltip('아이템'));
    await tester.pump();
    final drink = find.byTooltip('물약 마시기 · 물약 없음');
    expect(drink, findsOneWidget);

    give(game, Potion.haste);
    controller.waitTurn();
    await tester.pump();
    await tester.tap(find.byTooltip('물약 마시기'));
    await tester.pumpAndSettle();
    final look = game.potionAppearance[Potion.haste]!.name;
    await tester.tap(find.text('$look 물약'));
    await tester.pumpAndSettle();

    expect(game.player.has(Status.haste), isTrue);
    expect(find.textContaining(RegExp(r'^가속 \d+$')), findsOneWidget); // 상태 표시
  });
}
