import 'dart:math';

import '../geometry.dart';
import 'dungeon_map.dart';
import 'tile.dart';

class GeneratedLevel {
  GeneratedLevel(this.map, this.rooms);

  final DungeonMap map;

  /// 생성 순서대로. 첫 번째 방이 시작 방.
  final List<GridRect> rooms;
}

/// 방 + L자 복도 방식의 던전 생성기.
class DungeonGenerator {
  DungeonGenerator(this.rng);

  final Random rng;

  GeneratedLevel generate({
    int width = 60,
    int height = 40,
    int maxRooms = 14,
    int minRoomSize = 4,
    int maxRoomSize = 9,
    double doorChance = 0.75,
  }) {
    final map = DungeonMap(width, height);
    final rooms = <GridRect>[];

    for (var attempt = 0; attempt < 300 && rooms.length < maxRooms; attempt++) {
      final w = minRoomSize + rng.nextInt(maxRoomSize - minRoomSize + 1);
      final h = minRoomSize + rng.nextInt(maxRoomSize - minRoomSize + 1);
      // 가장자리 한 줄은 항상 벽으로 남긴다.
      final x = 1 + rng.nextInt(width - w - 1);
      final y = 1 + rng.nextInt(height - h - 1);
      final room = GridRect(x, y, w, h);
      if (rooms.any((r) => r.overlaps(room, margin: 2))) continue;

      for (final p in room.cells) {
        map[p] = TileType.floor;
      }
      if (rooms.isNotEmpty) _carveCorridor(map, rooms.last.center, room.center);
      rooms.add(room);
    }

    _placeDoors(map, rooms, doorChance);
    return GeneratedLevel(map, rooms);
  }

  void _carveCorridor(DungeonMap map, Pos a, Pos b) {
    if (rng.nextBool()) {
      _carveH(map, a.x, b.x, a.y);
      _carveV(map, a.y, b.y, b.x);
    } else {
      _carveV(map, a.y, b.y, a.x);
      _carveH(map, a.x, b.x, b.y);
    }
  }

  void _carveH(DungeonMap map, int x1, int x2, int y) {
    for (var x = min(x1, x2); x <= max(x1, x2); x++) {
      map[Pos(x, y)] = TileType.floor;
    }
  }

  void _carveV(DungeonMap map, int y1, int y2, int x) {
    for (var y = min(y1, y2); y <= max(y1, y2); y++) {
      map[Pos(x, y)] = TileType.floor;
    }
  }

  /// 복도가 방 테두리를 뚫고 들어온 자리(양옆이 벽인 통로)에 문을 단다.
  void _placeDoors(DungeonMap map, List<GridRect> rooms, double chance) {
    bool isWall(Pos p) => !map.contains(p) || map[p] == TileType.wall;
    bool isFloor(Pos p) => map.contains(p) && map[p] == TileType.floor;

    for (final room in rooms) {
      for (final p in room.perimeter) {
        if (!isFloor(p)) continue;
        final horizontalGap =
            isWall(p + Direction.w) &&
            isWall(p + Direction.e) &&
            isFloor(p + Direction.n) &&
            isFloor(p + Direction.s);
        final verticalGap =
            isWall(p + Direction.n) &&
            isWall(p + Direction.s) &&
            isFloor(p + Direction.w) &&
            isFloor(p + Direction.e);
        if (!horizontalGap && !verticalGap) continue;
        final nextToDoor = Direction.all.any((d) {
          final q = p + d;
          return map.contains(q) && map[q] == TileType.doorClosed;
        });
        if (nextToDoor) continue;
        if (rng.nextDouble() < chance) map[p] = TileType.doorClosed;
      }
    }
  }
}
