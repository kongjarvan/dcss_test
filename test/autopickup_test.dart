import 'package:dc_test/core/geometry.dart';
import 'package:dc_test/core/items/item.dart';
import 'package:dc_test/ui/game_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// 몬스터와 기존 바닥 아이템을 모두 치운 게임. [place]로 아이템을 직접 놓는다.
GameController cleanGame({int seed = 2}) {
  final c = GameController(seed: seed);
  final game = c.game;
  game.monsters.clear();
  for (final p in [...game.itemPositions]) {
    for (final item in game.itemsAt(p)) {
      game.removeFloorItem(p, item);
    }
  }
  game.updateFov();
  return c;
}

/// 플레이어가 지금 볼 수 있고, 시작 위치에서 떨어진 바닥 칸.
Pos visibleFloorAwayFromPlayer(GameController c, {int skip = 0}) {
  final game = c.game;
  final cells = <Pos>[];
  for (var y = 0; y < game.map.height; y++) {
    for (var x = 0; x < game.map.width; x++) {
      final p = Pos(x, y);
      if (game.map.isVisible(p) &&
          game.map[p].passable &&
          p.distanceTo(game.player.pos) >= 2) {
        cells.add(p);
      }
    }
  }
  return cells[skip];
}

void runExplore(GameController c) {
  for (var i = 0; c.isTraveling && i < 5000; i++) {
    c.autoMoveStep();
  }
}

Item potion(Potion p, {int quantity = 1}) =>
    Item(PotionType.of(p), quantity: quantity);

void main() {
  test('자동 줍기 대상: 해롭다고 밝혀진 물약과 장비는 제외', () {
    final game = cleanGame().game;
    expect(game.shouldAutoPickUp(potion(Potion.poison)), isTrue); // 미확인
    expect(game.shouldAutoPickUp(potion(Potion.curing)), isTrue);
    game.identifiedPotions.addAll([Potion.poison, Potion.curing]);
    expect(game.shouldAutoPickUp(potion(Potion.poison)), isFalse);
    expect(game.shouldAutoPickUp(potion(Potion.curing)), isTrue);
    expect(game.shouldAutoPickUp(Item(ItemTypes.dagger)), isFalse);
  });

  test('탐험 중 물약만 있는 칸은 줍고 멈추지 않고 계속 탐험한다', () {
    final c = cleanGame();
    final game = c.game;
    final spot = visibleFloorAwayFromPlayer(c);
    game.addFloorItem(spot, potion(Potion.curing, quantity: 2));

    c.explore();
    runExplore(c);
    // 탐험이 끝날 때까지 멈추지 않았고 물약을 주웠다.
    expect(game.log.recent(1).single.text, '탐험을 마쳤다.');
    expect(game.itemsAt(spot), isEmpty);
    final picked = game.player.inventory.where((i) => i.type is PotionType);
    expect(picked.single.quantity, 2);
    expect(
      game.log.recent(50).map((m) => m.text),
      contains('${game.nameOf(picked.single)}를 주웠다.'),
    );
  });

  test('해롭다고 밝혀진 물약은 줍지 않고, 처음 발견하면 멈춘다', () {
    final c = cleanGame();
    final game = c.game;
    game.identifiedPotions.add(Potion.poison);
    final spot = visibleFloorAwayFromPlayer(c);
    game.addFloorItem(spot, potion(Potion.poison));

    c.explore();
    runExplore(c);
    expect(game.player.pos, spot);
    expect(game.itemsAt(spot), hasLength(1));
    expect(game.player.inventory.where((i) => i.type is PotionType), isEmpty);

    // 다시 탐험하면 그냥 지나간다.
    c.explore();
    runExplore(c);
    expect(game.log.recent(1).single.text, '탐험을 마쳤다.');
    expect(game.itemsAt(spot), hasLength(1));
  });

  test('장비와 물약이 함께 있으면 멈추고, 다시 탐험할 때 물약만 줍는다', () {
    final c = cleanGame();
    final game = c.game;
    final spot = visibleFloorAwayFromPlayer(c);
    game.addFloorItem(spot, Item(ItemTypes.mace));
    game.addFloorItem(spot, potion(Potion.magic));

    c.explore();
    runExplore(c);
    expect(game.player.pos, spot); // 장비 때문에 멈춤
    expect(game.itemsAt(spot), hasLength(2));

    c.explore();
    c.autoMoveStep(); // 첫 걸음: 물약 줍기
    expect(game.itemsAt(spot).map((i) => i.type), [ItemTypes.mace]);
    expect(game.player.inventory.any((i) => i.type is PotionType), isTrue);
    expect(c.isTraveling, isTrue); // 계속 탐험
    c.dispose();
  });

  test('소지품이 가득 차서 못 주우면 탐험을 멈춘다', () {
    final c = cleanGame();
    final game = c.game;
    final p = game.player;
    while (!p.isInventoryFull) {
      p.addItem(Item(ItemTypes.dagger));
    }
    game.addFloorItem(p.pos, potion(Potion.curing));
    c.explore();
    c.autoMoveStep();
    expect(c.isTraveling, isFalse);
    expect(game.log.recent(1).single.text, '소지품이 가득 찼다.');
  });
}
