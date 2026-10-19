import '../action/action.dart';
import '../entity/actor.dart';
import '../game.dart';
import '../geometry.dart';
import '../korean.dart';
import 'pathfinding.dart';

abstract final class MonsterAi {
  static Action chooseAction(Game game, Monster monster) {
    final player = game.player;

    // 시야는 대칭으로 취급: 플레이어가 볼 수 있으면 몬스터도 플레이어를 본다.
    if (game.map.isVisible(monster.pos)) {
      if (!monster.awake) {
        monster.awake = true;
        game.message('${iGa(monster.name)} 당신을 발견했다!');
      }
      monster.lastKnownPlayerPos = player.pos;
    }
    if (!monster.awake) return const WaitAction();

    if (monster.pos.isAdjacentTo(player.pos)) {
      return MoveAction(player.pos - monster.pos);
    }

    final target = monster.lastKnownPlayerPos;
    if (target == null || target == monster.pos) {
      monster.lastKnownPlayerPos = null;
      return _wander(game, monster);
    }

    final path = findPath(
      monster.pos,
      target,
      (p) =>
          game.map.contains(p) &&
          game.map[p].traversable &&
          game.actorAt(p) == null,
      maxNodes: 800,
    );
    if (path == null || path.isEmpty) return const WaitAction();
    return MoveAction(path.first - monster.pos);
  }

  /// 플레이어를 놓쳤을 때 주변을 배회한다.
  static Action _wander(Game game, Monster monster) {
    final options = Direction.all.where((d) {
      final p = monster.pos + d;
      return game.map.contains(p) &&
          game.map[p].passable &&
          game.actorAt(p) == null;
    }).toList();
    if (options.isEmpty || game.rng.nextInt(3) == 0) return const WaitAction();
    return MoveAction(options[game.rng.nextInt(options.length)]);
  }
}
