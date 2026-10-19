import 'dart:math';

import 'package:dc_test/core/action/action.dart';
import 'package:dc_test/core/ai/pathfinding.dart';
import 'package:dc_test/core/entity/actor.dart';
import 'package:dc_test/core/entity/monster_type.dart';
import 'package:dc_test/core/fov/shadowcasting.dart';
import 'package:dc_test/core/game.dart';
import 'package:dc_test/core/geometry.dart';
import 'package:dc_test/core/time/energy.dart';
import 'package:dc_test/core/world/dungeon_generator.dart';
import 'package:dc_test/core/world/dungeon_map.dart';
import 'package:dc_test/core/world/tile.dart';
import 'package:flutter_test/flutter_test.dart';

/// 벽으로 둘러싸인 빈 방.
DungeonMap openRoom(int w, int h) {
  final map = DungeonMap(w, h);
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      map[Pos(x, y)] = TileType.floor;
    }
  }
  return map;
}

/// 항상 명중하고 피해 1을 주는 몬스터.
MonsterType sureHitter({required int speed, int attackDelay = autPerTurn}) =>
    MonsterType(
      id: 'test',
      name: '테스트',
      maxHp: 100,
      speed: speed,
      attackDelay: attackDelay,
      stats: const CombatStats(accuracy: 1000, maxDamage: 1, evasion: 0),
      xp: 1,
    );

Game duel(MonsterType type) {
  final player = Player(pos: const Pos(3, 3))
    ..baseStats = const CombatStats(accuracy: 1, maxDamage: 1, evasion: 0);
  final monster = Monster(type, pos: const Pos(4, 3))..awake = true;
  return Game(
    rng: Random(1),
    map: openRoom(10, 10),
    player: player,
    monsters: [monster],
  );
}

void main() {
  group('시간 시스템', () {
    test('속도 10 몬스터는 플레이어 1턴에 1번 공격', () {
      final game = duel(sureHitter(speed: 10));
      game.playerAct(const WaitAction());
      expect(game.player.hp, game.player.maxHp - 1);
    });

    test('속도 20 몬스터는 플레이어 1턴에 2번 공격', () {
      final game = duel(sureHitter(speed: 20));
      game.playerAct(const WaitAction());
      expect(game.player.hp, game.player.maxHp - 2);
    });

    test('공격 비용 15인 몬스터는 6턴 동안 4번 공격', () {
      final game = duel(sureHitter(speed: 10, attackDelay: 15));
      for (var i = 0; i < 6; i++) {
        game.playerAct(const WaitAction());
      }
      // 재생은 피해를 입은 뒤부터 누적되므로 아직 발동하지 않는다.
      expect(game.player.hp, game.player.maxHp - 4);
    });

    test('느린 플레이어 행동 동안 몬스터가 더 많이 행동한다', () {
      final game = duel(sureHitter(speed: 10));
      game.player.attackDelay = 20;
      game.playerAct(MoveAction(Direction.e)); // 공격으로 대체됨
      expect(game.lastActionCost, 20);
      expect(game.time, 20);
      expect(game.player.hp, game.player.maxHp - 2);
    });

    test('실패한 행동은 시간이 흐르지 않는다', () {
      final game = duel(sureHitter(speed: 10));
      game.player.pos = const Pos(1, 1);
      expect(game.playerAct(MoveAction(Direction.n)), isFalse);
      expect(game.time, 0);
    });
  });

  group('자동 전투', () {
    test('인접한 적이 있으면 공격', () {
      final game = duel(sureHitter(speed: 10));
      expect(game.autoFightAction(), isA<AttackAction>());
    });

    test('떨어진 적에게는 한 칸 다가간다', () {
      final game = duel(sureHitter(speed: 10));
      game.monsters.first.pos = const Pos(7, 3);
      game.updateFov();
      final action = game.autoFightAction();
      expect(action, isA<MoveAction>());
      final before = game.player.pos.distanceTo(const Pos(7, 3));
      game.playerAct(action!);
      expect(game.player.pos.distanceTo(const Pos(7, 3)), before - 1);
    });

    test('보이는 적이 없으면 null', () {
      final game = duel(sureHitter(speed: 10));
      game.monsters.clear();
      expect(game.autoFightAction(), isNull);
    });
  });

  group('경로탐색', () {
    bool open(Pos p) => true;

    test('최소 칸 수로 이동하고 위아래로 꺾이지 않는다', () {
      for (final goal in const [
        Pos(6, 2),
        Pos(10, 3),
        Pos(4, 4),
        Pos(7, 0),
        Pos(-5, 8),
      ]) {
        final path = findPath(const Pos(0, 0), goal, open)!;
        expect(path.length, const Pos(0, 0).distanceTo(goal), reason: '$goal');
        // 대각선 수가 최소 (= min(|dx|, |dy|))
        var prev = const Pos(0, 0);
        var diagonals = 0;
        for (final p in path) {
          final d = p - prev;
          if (d.x != 0 && d.y != 0) diagonals++;
          // y 방향이 목표 반대로 가지 않음 (지그재그 없음)
          expect(
            d.y * goal.y >= 0 && d.x * goal.x >= 0,
            isTrue,
            reason: '$goal: $path',
          );
          prev = p;
        }
        expect(
          diagonals,
          goal.x.abs() < goal.y.abs() ? goal.x.abs() : goal.y.abs(),
          reason: '$goal: $path',
        );
      }
    });

    test('계단 모양이 직선에 가깝다 (대각선이 한쪽에 몰리지 않음)', () {
      // (0,0) → (8,2): 직선 y = x/4. 모든 칸이 직선에서 1칸 미만으로 떨어져야 함.
      final path = findPath(const Pos(0, 0), const Pos(8, 2), open)!;
      for (final p in path) {
        expect((p.y - p.x / 4).abs() < 1, isTrue, reason: '$path');
      }
    });
  });

  test('닫힌 문으로 이동하면 문을 연다', () {
    final map = openRoom(10, 10);
    map[const Pos(4, 3)] = TileType.doorClosed;
    final game = Game(
      rng: Random(1),
      map: map,
      player: Player(pos: const Pos(3, 3)),
    );
    game.playerAct(MoveAction(Direction.e));
    expect(map[const Pos(4, 3)], TileType.doorOpen);
    expect(game.player.pos, const Pos(3, 3));
  });

  test('벽 뒤는 보이지 않는다', () {
    final map = openRoom(20, 10);
    for (var y = 1; y < 9; y++) {
      map[Pos(10, y)] = TileType.wall;
    }
    computeFov(map, const Pos(5, 5), 8);
    expect(map.isVisible(const Pos(8, 5)), isTrue);
    expect(map.isVisible(const Pos(10, 5)), isTrue); // 벽 자체는 보임
    expect(map.isVisible(const Pos(12, 5)), isFalse);
  });

  test('생성된 던전의 모든 방은 연결되어 있다', () {
    for (var seed = 0; seed < 30; seed++) {
      final level = DungeonGenerator(Random(seed)).generate();
      final map = level.map;
      final start = level.rooms.first.center;
      final reached = <Pos>{start};
      final queue = [start];
      while (queue.isNotEmpty) {
        final p = queue.removeLast();
        for (final d in Direction.all) {
          final q = p + d;
          if (map.contains(q) && map[q].traversable && reached.add(q)) {
            queue.add(q);
          }
        }
      }
      for (final room in level.rooms) {
        expect(reached, contains(room.center), reason: 'seed $seed');
      }
      for (var x = 0; x < map.width; x++) {
        expect(map[Pos(x, 0)], TileType.wall);
        expect(map[Pos(x, map.height - 1)], TileType.wall);
      }
    }
  });
}
