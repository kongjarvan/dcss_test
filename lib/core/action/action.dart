import 'dart:math';

import '../entity/actor.dart';
import '../game.dart';
import '../geometry.dart';
import '../korean.dart';
import '../time/energy.dart';
import '../world/tile.dart';

class ActionResult {
  const ActionResult._(this.succeeded, this.cost, this.alternate);

  /// 행동 성공. [cost] aut만큼 시간이 흐른다.
  const ActionResult.success(int cost) : this._(true, cost, null);

  /// 다른 행동으로 대체 (예: 몬스터 쪽으로 이동 → 공격).
  const ActionResult.alternate(Action action) : this._(false, 0, action);

  /// 행동 불가. 시간이 흐르지 않는다.
  static const failure = ActionResult._(false, 0, null);

  final bool succeeded;
  final int cost;
  final Action? alternate;
}

/// 플레이어와 몬스터가 공통으로 사용하는 행동.
abstract class Action {
  const Action();

  ActionResult perform(Game game, Actor actor);
}

class WaitAction extends Action {
  const WaitAction();

  @override
  ActionResult perform(Game game, Actor actor) =>
      const ActionResult.success(autPerTurn);
}

class MoveAction extends Action {
  const MoveAction(this.direction);

  final Pos direction;

  @override
  ActionResult perform(Game game, Actor actor) {
    final dest = actor.pos + direction;
    if (!game.map.contains(dest)) return ActionResult.failure;

    final other = game.actorAt(dest);
    if (other != null) {
      // 적대 관계면 공격, 아군(몬스터끼리)이면 이동 불가.
      return other.isPlayer != actor.isPlayer
          ? ActionResult.alternate(AttackAction(other))
          : ActionResult.failure;
    }

    final tile = game.map[dest];
    if (tile == TileType.doorClosed) {
      return ActionResult.alternate(OpenDoorAction(dest));
    }
    if (!tile.passable) return ActionResult.failure;

    actor.pos = dest;
    return ActionResult.success(actor.moveDelay);
  }
}

class OpenDoorAction extends Action {
  const OpenDoorAction(this.pos);

  final Pos pos;

  @override
  ActionResult perform(Game game, Actor actor) {
    if (game.map[pos] != TileType.doorClosed) return ActionResult.failure;
    game.map[pos] = TileType.doorOpen;
    if (actor.isPlayer) {
      game.message('문을 열었다.');
    } else if (game.map.isVisible(actor.pos)) {
      game.message('${iGa(actor.name)} 문을 열었다.');
    }
    return const ActionResult.success(autPerTurn);
  }
}

class AttackAction extends Action {
  const AttackAction(this.target);

  final Actor target;

  @override
  ActionResult perform(Game game, Actor attacker) {
    final rng = game.rng;
    final a = attacker.stats;
    final d = target.stats;
    final subject = attacker.isPlayer ? '' : '${iGa(attacker.name)} ';
    final object = eulReul(target.name);

    final hit = rng.nextInt(a.accuracy + d.evasion) < a.accuracy;
    if (!hit) {
      game.message('$subject$object 공격했지만 빗나갔다.');
    } else {
      final roll = _scale(
        1 + rng.nextInt(a.maxDamage),
        attacker.meleeDamageMultiplier,
        rng,
      );
      final damage = max(0, roll - rng.nextInt(d.armor + 1));
      if (damage == 0) {
        game.message('$subject$object 공격했지만 피해를 주지 못했다.');
      } else {
        target.hp -= damage;
        game.message('$subject$object 공격해 $damage의 피해를 입혔다.');
        if (!target.isAlive) game.onActorDied(target, attacker);
      }
    }
    return ActionResult.success(attacker.attackDelay);
  }

  /// [value] × [multiplier]를 확률적으로 반올림한다.
  /// 예) 4 × 1.15 = 4.6 → 60% 확률로 5, 40% 확률로 4. 기대값이 정확히 유지된다.
  static int _scale(int value, double multiplier, Random rng) {
    if (multiplier == 1.0) return value;
    final scaled = value * multiplier;
    final whole = scaled.floor();
    return whole + (rng.nextDouble() < scaled - whole ? 1 : 0);
  }
}
