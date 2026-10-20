import 'package:dc_test/core/entity/actor.dart';
import 'package:dc_test/core/entity/monster_type.dart';
import 'package:dc_test/core/geometry.dart';
import 'package:dc_test/core/world/tile.dart';
import 'package:dc_test/ui/game_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// 자동 이동이 끝날 때까지 한 걸음씩 진행. 진행한 걸음 수를 반환.
int runAutoMove(GameController c, {int maxSteps = 5000}) {
  var steps = 0;
  while (c.isTraveling && steps < maxSteps) {
    c.autoMoveStep();
    steps++;
  }
  return steps;
}

/// 아이템 위에서 멈추면 다시 탐험을 누르며, 탐험이 끝나거나 [stopWhen]이 참일 때까지 진행.
/// 아이템에서 멈춘 횟수를 반환.
int exploreFully(GameController c, {bool Function()? stopWhen}) {
  var itemStops = 0;
  for (var i = 0; i < 200; i++) {
    c.explore();
    if (!c.isTraveling) break;
    runAutoMove(c);
    if (stopWhen?.call() ?? false) break;
    if (c.game.itemsAt(c.game.player.pos).isNotEmpty) itemStops++;
  }
  return itemStops;
}

void main() {
  test('몬스터가 없으면 맵 전체를 탐험하고 끝난다', () {
    for (final seed in [1, 2, 3, 4, 5]) {
      final c = GameController(seed: seed);
      final game = c.game;
      game.monsters.clear();
      game.updateFov();

      final itemStops = exploreFully(c);
      expect(c.isTraveling, isFalse, reason: 'seed $seed: 끝나지 않음');
      // 바닥 아이템마다 한 번씩 멈춘다.
      expect(itemStops, game.itemPositions.length, reason: 'seed $seed');

      // 도달 가능한 모든 바닥/문 칸을 봤어야 한다.
      final map = game.map;
      for (var y = 0; y < map.height; y++) {
        for (var x = 0; x < map.width; x++) {
          final p = Pos(x, y);
          if (map[p].traversable) {
            expect(map.isExplored(p), isTrue, reason: 'seed $seed: $p 미탐험');
          }
        }
      }
      expect(game.exploreTarget(), isNull);

      // 다 끝났으면 탐험할 곳이 없다는 메시지.
      c.explore();
      expect(c.isTraveling, isFalse);
      expect(game.log.recent(1).single.text, '더 탐험할 곳이 없다.');
      c.dispose();
    }
  });

  test('몬스터가 보이면 자동 탐험 불가, 탐험 중 발견하면 멈춘다', () {
    final c = GameController(seed: 3);
    final game = c.game;
    game.monsters.clear();
    game.updateFov();

    // 시야 안에 몬스터 배치 → 사용 불가
    final near = Direction.all
        .map((d) => game.player.pos + d)
        .firstWhere((p) => game.map[p] == TileType.floor);
    game.monsters.add(Monster(MonsterTypes.goblin, pos: near));
    game.updateFov();
    expect(c.canExplore, isFalse);
    c.explore();
    expect(c.isTraveling, isFalse);

    // 몬스터를 시야 밖 미탐험 지역에 두고 탐험 → 발견 시 정지
    game.monsters.clear();
    game.updateFov();
    final map = game.map;
    Pos? hidden;
    for (var y = 0; y < map.height && hidden == null; y++) {
      for (var x = 0; x < map.width; x++) {
        final p = Pos(x, y);
        if (map[p] == TileType.floor && !map.isExplored(p)) {
          hidden = p;
          break;
        }
      }
    }
    game.monsters.add(Monster(MonsterTypes.goblin, pos: hidden!));
    game.updateFov();
    expect(c.canExplore, isTrue);

    exploreFully(c, stopWhen: () => game.visibleMonsters.isNotEmpty);
    expect(c.isTraveling, isFalse);
    expect(game.visibleMonsters, isNotEmpty);
    expect(c.canExplore, isFalse);
    c.dispose();
  });
}
