import 'package:dc_test/core/entity/actor.dart';
import 'package:dc_test/core/entity/monster_type.dart';
import 'package:dc_test/core/geometry.dart';
import 'package:dc_test/core/world/tile.dart';
import 'package:dc_test/ui/game_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void runAutoMove(GameController c) {
  for (var i = 0; c.isTraveling && i < 5000; i++) {
    c.autoMoveStep();
  }
}

void main() {
  test('휴식하면 체력이 완전히 회복될 때까지 턴이 흐른다', () {
    final c = GameController(seed: 1);
    final game = c.game;
    game.monsters.clear();
    game.updateFov();
    game.player.hp = 5;

    expect(c.canRest, isTrue);
    c.rest();
    expect(c.isTraveling, isTrue);
    expect(c.autoMoveMode, AutoMoveMode.rest);
    runAutoMove(c);

    expect(c.isTraveling, isFalse);
    expect(game.player.hp, game.player.maxHp);
    // 25 HP × 60 aut = 1500 aut
    expect(game.time, 25 * Player.baseAutPerHpRegen);
    expect(game.lastActionCost, game.time);
    expect(c.canRest, isFalse); // 체력 가득
    c.dispose();
  });

  test('몬스터가 보이면 휴식 불가, 휴식 중 나타나면 멈춘다', () {
    final c = GameController(seed: 1);
    final game = c.game;
    game.monsters.clear();
    game.updateFov();
    game.player.hp = 5;

    final near = Direction.all
        .map((d) => game.player.pos + d)
        .firstWhere((p) => game.map[p] == TileType.floor);
    game.monsters.add(Monster(MonsterTypes.goblin, pos: near));
    game.updateFov();
    expect(c.canRest, isFalse);
    c.rest();
    expect(c.isTraveling, isFalse);

    // 시야 밖에서 깨어 있는 몬스터가 다가오면 휴식 중단
    game.monsters.clear();
    final map = game.map;
    Pos? far;
    for (var y = 0; y < map.height && far == null; y++) {
      for (var x = 0; x < map.width; x++) {
        final p = Pos(x, y);
        if (map[p] == TileType.floor && !map.isVisible(p)) {
          far = p;
          break;
        }
      }
    }
    game.monsters.add(
      Monster(MonsterTypes.goblin, pos: far!)
        ..awake = true
        ..lastKnownPlayerPos = game.player.pos,
    );
    game.updateFov();
    c.rest();
    runAutoMove(c);
    expect(c.isTraveling, isFalse);
    expect(game.visibleMonsters, isNotEmpty);
    expect(game.player.hp, lessThan(game.player.maxHp));
    c.dispose();
  });
}
