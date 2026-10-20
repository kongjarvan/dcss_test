import '../geometry.dart';
import 'tile.dart';

class DungeonMap {
  DungeonMap(this.width, this.height)
    : _tiles = List.filled(width * height, TileType.wall),
      _explored = List.filled(width * height, false),
      _visible = List.filled(width * height, false);

  final int width;
  final int height;
  final List<TileType> _tiles;
  final List<bool> _explored;
  final List<bool> _visible;

  bool contains(Pos p) => p.x >= 0 && p.y >= 0 && p.x < width && p.y < height;

  int _index(Pos p) => p.y * width + p.x;

  TileType operator [](Pos p) => _tiles[_index(p)];
  void operator []=(Pos p, TileType type) => _tiles[_index(p)] = type;

  /// 현재 플레이어 시야 안에 있는지.
  bool isVisible(Pos p) => contains(p) && _visible[_index(p)];

  /// 한 번이라도 본 적이 있는지 (지도 기억).
  bool isExplored(Pos p) => contains(p) && _explored[_index(p)];

  void clearVisibility() => _visible.fillRange(0, _visible.length, false);

  /// 본 적 있는 칸으로 표시 (지금 보이지는 않음). 깨달음 물약 등.
  void markExplored(Pos p) {
    if (contains(p)) _explored[_index(p)] = true;
  }

  void markVisible(Pos p) {
    if (!contains(p)) return;
    final i = _index(p);
    _visible[i] = true;
    _explored[i] = true;
  }
}
