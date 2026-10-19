enum TileType {
  wall(passable: false, blocksSight: true),
  floor(passable: true, blocksSight: false),
  doorClosed(passable: false, blocksSight: true),
  doorOpen(passable: true, blocksSight: false);

  const TileType({required this.passable, required this.blocksSight});

  /// 지금 바로 걸어 들어갈 수 있는지.
  final bool passable;
  final bool blocksSight;

  /// 경로탐색 기준으로 지나갈 수 있는지 (닫힌 문은 열고 지나간다).
  bool get traversable => passable || this == TileType.doorClosed;
}
