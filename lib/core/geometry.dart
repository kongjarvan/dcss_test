import 'dart:math' as math;

/// 맵 위의 정수 좌표.
class Pos {
  const Pos(this.x, this.y);

  final int x;
  final int y;

  Pos operator +(Pos other) => Pos(x + other.x, y + other.y);
  Pos operator -(Pos other) => Pos(x - other.x, y - other.y);

  /// 8방향 이동 기준 거리 (대각선도 1칸).
  int distanceTo(Pos other) =>
      math.max((x - other.x).abs(), (y - other.y).abs());

  bool isAdjacentTo(Pos other) => distanceTo(other) == 1;

  @override
  bool operator ==(Object other) =>
      other is Pos && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x, $y)';
}

/// 8방향 단위 벡터.
abstract final class Direction {
  static const n = Pos(0, -1);
  static const ne = Pos(1, -1);
  static const e = Pos(1, 0);
  static const se = Pos(1, 1);
  static const s = Pos(0, 1);
  static const sw = Pos(-1, 1);
  static const w = Pos(-1, 0);
  static const nw = Pos(-1, -1);

  static const all = [n, ne, e, se, s, sw, w, nw];
}

/// 정수 격자 위의 사각형. right/bottom은 포함하지 않는다.
class GridRect {
  const GridRect(this.left, this.top, this.width, this.height);

  final int left;
  final int top;
  final int width;
  final int height;

  int get right => left + width;
  int get bottom => top + height;
  Pos get center => Pos(left + width ~/ 2, top + height ~/ 2);

  bool contains(Pos p) =>
      p.x >= left && p.x < right && p.y >= top && p.y < bottom;

  /// [margin]칸 이내로 붙어 있으면 겹친 것으로 본다.
  bool overlaps(GridRect other, {int margin = 0}) =>
      left - margin < other.right &&
      other.left < right + margin &&
      top - margin < other.bottom &&
      other.top < bottom + margin;

  Iterable<Pos> get cells sync* {
    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        yield Pos(x, y);
      }
    }
  }

  /// 사각형 바로 바깥 테두리 칸 (모서리 제외).
  Iterable<Pos> get perimeter sync* {
    for (var x = left; x < right; x++) {
      yield Pos(x, top - 1);
      yield Pos(x, bottom);
    }
    for (var y = top; y < bottom; y++) {
      yield Pos(left - 1, y);
      yield Pos(right, y);
    }
  }
}
