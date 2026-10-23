import 'entity/actor.dart';
import 'geometry.dart';
import 'items/item.dart';
import 'world/dungeon_map.dart';

/// 던전의 한 층. 다른 층에 가 있는 동안에도 그대로 보관된다 (시간은 멈춤).
class Level {
  Level({
    required this.depth,
    required this.map,
    List<Monster>? monsters,
    this.stairsDown = const [],
    this.stairsUp = const [],
  }) : monsters = monsters ?? [];

  /// 1층부터 아래로 내려갈수록 커진다.
  final int depth;
  final DungeonMap map;
  final List<Monster> monsters;

  /// 내려가는 계단. k번째 계단은 아래층의 k번째 올라가는 계단과 이어진다.
  final List<Pos> stairsDown;

  /// 올라가는 계단. k번째 계단은 위층의 k번째 내려가는 계단과 이어진다.
  final List<Pos> stairsUp;

  final Map<Pos, List<Item>> floorItems = {};

  /// 플레이어가 이미 올라서서 확인한 아이템 더미 (자동 탐험이 다시 찾아가지 않음).
  final Set<Pos> noticedPiles = {};
}
