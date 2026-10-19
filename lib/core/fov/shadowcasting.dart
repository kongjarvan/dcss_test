import '../geometry.dart';
import '../world/dungeon_map.dart';

// 8개 팔분면 변환 계수.
const _mult = [
  [1, 0, 0, -1, -1, 0, 0, 1],
  [0, 1, -1, 0, 0, -1, 1, 0],
  [0, 1, 1, 0, 0, -1, -1, 0],
  [1, 0, 0, 1, -1, 0, 0, -1],
];

/// Recursive Shadowcasting으로 [origin]에서의 시야를 계산해 [map]에 기록한다.
void computeFov(DungeonMap map, Pos origin, int radius) {
  map.clearVisibility();
  map.markVisible(origin);
  for (var oct = 0; oct < 8; oct++) {
    _castLight(
      map,
      origin,
      1,
      1.0,
      0.0,
      radius,
      _mult[0][oct],
      _mult[1][oct],
      _mult[2][oct],
      _mult[3][oct],
    );
  }
}

void _castLight(
  DungeonMap map,
  Pos origin,
  int row,
  double start,
  double end,
  int radius,
  int xx,
  int xy,
  int yx,
  int yy,
) {
  if (start < end) return;
  // + radius: 원형 시야 가장자리를 조금 더 둥글게.
  final radiusSq = radius * radius + radius;
  var newStart = 0.0;

  for (var j = row; j <= radius; j++) {
    var dx = -j - 1;
    final dy = -j;
    var blocked = false;

    while (dx <= 0) {
      dx++;
      final p = Pos(origin.x + dx * xx + dy * xy, origin.y + dx * yx + dy * yy);
      final lSlope = (dx - 0.5) / (dy + 0.5);
      final rSlope = (dx + 0.5) / (dy - 0.5);
      if (start < rSlope) continue;
      if (end > lSlope) break;

      if (dx * dx + dy * dy <= radiusSq) map.markVisible(p);
      final opaque = !map.contains(p) || map[p].blocksSight;

      if (blocked) {
        if (opaque) {
          newStart = rSlope;
          continue;
        }
        blocked = false;
        start = newStart;
      } else if (opaque && j < radius) {
        blocked = true;
        _castLight(map, origin, j + 1, start, lSlope, radius, xx, xy, yx, yy);
        newStart = rSlope;
      }
    }
    if (blocked) break;
  }
}
