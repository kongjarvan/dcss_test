import 'dart:math';

import '../entity/actor.dart';
import '../entity/status.dart';
import '../game.dart';
import '../items/item.dart';
import '../geometry.dart';
import '../korean.dart';
import '../progression/experience.dart';
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
    // 몬스터는 든 무기를 밝힌다: "고블린이 몽둥이로 당신을 공격해 …"
    final weapon = attacker is Monster ? attacker.meleeWeapon : null;
    final subject = attacker.isPlayer
        ? ''
        : '${iGa(attacker.name)} ${weapon == null ? '' : '${euroRo(weapon.name)} '}';
    final object = eulReul(target.name);

    final hit = rng.nextInt(a.accuracy + d.evasion) < a.accuracy;
    if (!hit) {
      game.message('$subject$object 공격했지만 빗나갔다.');
    } else if (_blocked(target, rng)) {
      game.message('$subject$object 공격했지만 방패에 막혔다.');
    } else {
      final damage = rollDamage(
        rng,
        a.maxDamage,
        attacker.meleeDamageMultiplier,
        d.armor,
      );
      if (damage == 0) {
        game.message('$subject$object 공격했지만 피해를 주지 못했다.');
      } else {
        target.hp -= damage;
        game.message('$subject$object 공격해 $damage의 피해를 입혔다.');
        if (!target.isAlive) game.onActorDied(target, attacker);
      }
    }
    return ActionResult.success(attacker.meleeDelay);
  }
}

/// 장병기로 2칸 떨어진 [target]을 찌른다. 계산은 일반 근접 공격과 같다.
class ReachAttackAction extends Action {
  const ReachAttackAction(this.target);

  final Actor target;

  @override
  ActionResult perform(Game game, Actor actor) {
    if (actor is! Player || !game.canReach(target)) {
      return ActionResult.failure;
    }
    return AttackAction(target).perform(game, actor);
  }
}

/// [target]이 방패로 공격을 막았는지.
bool _blocked(Actor target, Random rng) {
  final chance = target.blockChance;
  return chance > 0 && rng.nextDouble() < chance;
}

/// 피해 굴림: 1~[maxDamage] × [multiplier] − 0~[armor].
int rollDamage(Random rng, int maxDamage, double multiplier, int armor) {
  final roll = _scale(1 + rng.nextInt(maxDamage), multiplier, rng);
  return max(0, roll - rng.nextInt(armor + 1));
}

/// [value] × [multiplier]를 확률적으로 반올림한다.
/// 예) 4 × 1.15 = 4.6 → 60% 확률로 5, 40% 확률로 4. 기대값이 정확히 유지된다.
int _scale(int value, double multiplier, Random rng) {
  if (multiplier == 1.0) return value;
  final scaled = value * multiplier;
  final whole = scaled.floor();
  return whole + (rng.nextDouble() < scaled - whole ? 1 : 0);
}

/// 활로 [target]을 쏜다. 사이에 벽이나 다른 몬스터가 있으면 쏠 수 없다.
class RangedAttackAction extends Action {
  const RangedAttackAction(this.target);

  final Actor target;

  @override
  ActionResult perform(Game game, Actor actor) {
    if (actor is! Player) return ActionResult.failure;
    final a = actor.rangedStats;
    if (a == null) return ActionResult.failure;
    if (!target.isAlive || !game.hasLineOfFire(actor.pos, target.pos)) {
      game.message('목표를 겨눌 수 없다.');
      return ActionResult.failure;
    }

    final rng = game.rng;
    final d = target.stats;
    final hit = rng.nextInt(a.accuracy + d.evasion) < a.accuracy;
    if (!hit) {
      game.message('화살이 ${eulReul(target.name)} 빗나갔다.');
    } else if (_blocked(target, rng)) {
      game.message('${iGa(target.name)} 화살을 방패로 막았다.');
    } else {
      final damage = rollDamage(
        rng,
        a.maxDamage,
        actor.rangedDamageMultiplier,
        d.armor,
      );
      if (damage == 0) {
        game.message('화살이 ${target.name}에게 맞았지만 피해를 주지 못했다.');
      } else {
        target.hp -= damage;
        game.message('화살이 ${target.name}에게 명중해 $damage의 피해를 입혔다.');
        if (!target.isAlive) game.onActorDied(target, actor);
      }
    }
    return ActionResult.success(actor.rangedDelay);
  }
}

/// 발밑의 아이템을 모두 줍는다 (소지품 칸이 허락하는 만큼).
class PickUpAction extends Action {
  /// [autoOnly]면 자동 줍기 대상([Game.shouldAutoPickUp])만,
  /// [only]가 있으면 그 아이템 하나만 줍는다.
  const PickUpAction({this.autoOnly = false, this.only});

  final bool autoOnly;
  final Item? only;

  @override
  ActionResult perform(Game game, Actor actor) {
    if (actor is! Player) return ActionResult.failure;
    final items = game
        .itemsAt(actor.pos)
        .where((i) => only == null || i == only)
        .where((i) => !autoOnly || game.shouldAutoPickUp(i))
        .toList();
    if (items.isEmpty) {
      game.message('여기에는 주울 것이 없다.');
      return ActionResult.failure;
    }
    final picked = <String>[];
    var full = false;
    for (final item in items) {
      // 이름은 줍기 전에 정한다 (겹치면 아이템 묶음이 합쳐진다).
      final name = game.nameOf(item);
      if (!actor.addItem(item)) {
        full = true;
        break;
      }
      game.removeFloorItem(actor.pos, item);
      picked.add(name);
    }
    if (picked.isEmpty) {
      game.message('소지품이 가득 찼다.');
      return ActionResult.failure;
    }
    game.message('${eulReul(picked.join(', '))} 주웠다.');
    if (full) game.message('소지품이 가득 차 나머지는 줍지 못했다.');
    return const ActionResult.success(autPerTurn);
  }
}

/// 소지품의 아이템(묶음 전체)을 발밑에 내려놓는다. 장착 중이면 먼저 해제해야 한다.
class DropAction extends Action {
  const DropAction(this.item);

  final Item item;

  @override
  ActionResult perform(Game game, Actor actor) {
    if (actor is! Player || !actor.inventory.contains(item)) {
      return ActionResult.failure;
    }
    if (actor.isEquipped(item)) {
      game.message('장착 중인 아이템은 먼저 해제해야 한다.');
      return ActionResult.failure;
    }
    actor.inventory.remove(item);
    game.addFloorItem(actor.pos, item, noticed: true);
    game.message('${eulReul(game.nameOf(item))} 내려놓았다.');
    return const ActionResult.success(autPerTurn);
  }
}

/// 장착. 같은 부위에 장비가 있으면 바꿔 낀다 (두 장비의 시간이 모두 든다).
class EquipAction extends Action {
  const EquipAction(this.item);

  final Item item;

  @override
  ActionResult perform(Game game, Actor actor) {
    final type = item.type;
    if (actor is! Player ||
        type is! EquipmentType ||
        !actor.inventory.contains(item) ||
        actor.isEquipped(item)) {
      return ActionResult.failure;
    }
    final problem = actor.equipProblem(item);
    if (problem != null) {
      game.message(problem);
      return ActionResult.failure;
    }
    final previous = actor.equipped(type.slot);
    actor.equip(item);
    final verb = switch (type) {
      WeaponType() => '손에 들었다',
      ArmourType() => '입었다',
      ShieldType() => '들었다',
    };
    final instead = previous == null ? '' : '${previous.name} 대신 ';
    game.message('$instead${eulReul(item.name)} $verb.');
    return ActionResult.success(
      type.equipTime + ((previous?.type as EquipmentType?)?.equipTime ?? 0),
    );
  }
}

/// 장착 해제. 아이템은 소지품에 남는다.
class UnequipAction extends Action {
  const UnequipAction(this.slot);

  final EquipSlot slot;

  @override
  ActionResult perform(Game game, Actor actor) {
    if (actor is! Player) return ActionResult.failure;
    final item = actor.unequip(slot);
    if (item == null) return ActionResult.failure;
    final type = item.type as EquipmentType;
    final verb = switch (type) {
      WeaponType() => '집어넣었다',
      ArmourType() || ShieldType() => '벗었다',
    };
    game.message('${eulReul(item.name)} $verb.');
    return ActionResult.success(type.equipTime);
  }
}

/// 물약을 마신다 (1턴). 마시면 그 물약 종류가 식별된다.
class QuaffAction extends Action {
  const QuaffAction(this.item);

  final Item item;

  @override
  ActionResult perform(Game game, Actor actor) {
    final type = item.type;
    if (actor is! Player ||
        type is! PotionType ||
        !actor.inventory.contains(item)) {
      return ActionResult.failure;
    }
    final potion = type.potion;
    final shownName = game.nameOf(item, withCount: false);
    final wasKnown = game.identifiedPotions.contains(potion);
    actor.consume(item);
    game.identifiedPotions.add(potion);
    game.message(
      wasKnown
          ? '${eulReul(shownName)} 마셨다.'
          : '${eulReul(shownName)} 마셨다. ${potion.label}이었다!',
    );
    _applyPotion(game, actor, potion);
    return const ActionResult.success(autPerTurn);
  }

  static int _turns(Random rng, int min, int max) =>
      (min + rng.nextInt(max - min + 1)) * autPerTurn;

  static void _applyPotion(Game game, Player p, Potion potion) {
    final rng = game.rng;
    switch (potion) {
      case Potion.curing:
        p.hp = min(p.maxHp, p.hp + 5 + rng.nextInt(7));
        game.message('몸이 한결 나아졌다.');
        if (p.statuses.remove(Status.poison) != null) {
          p.poisonProgress = 0;
          game.message('독이 사라졌다.');
        }
      case Potion.healWounds:
        p.hp = min(p.maxHp, p.hp + 15 + rng.nextInt(11));
        game.message('상처가 아물었다.');
      case Potion.magic:
        p.mp = min(p.maxMp, p.mp + 8 + rng.nextInt(6));
        game.message('마력이 차오른다.');
      case Potion.haste:
        p.addStatus(Status.haste, _turns(rng, 30, 45));
        game.message('몸이 빨라졌다!');
      case Potion.might:
        p.addStatus(Status.might, _turns(rng, 35, 50));
        game.message('힘이 솟는다!');
      case Potion.agility:
        p.addStatus(Status.agility, _turns(rng, 35, 50));
        game.message('몸이 가벼워졌다!');
      case Potion.brilliance:
        p.addStatus(Status.brilliance, _turns(rng, 35, 50));
        game.message('머리가 맑아졌다!');
      case Potion.slowing:
        p.addStatus(Status.slow, _turns(rng, 15, 25));
        game.message('몸이 느려졌다...');
      case Potion.poison:
        p.addStatus(Status.poison, _turns(rng, 8, 14));
        game.message('독이다! 속이 뒤틀린다.');
      case Potion.experience:
        if (p.isMaxLevel) {
          game.message('아무 일도 일어나지 않았다.');
        } else {
          game.message('깨달음이 밀려온다!');
          game.grantXp(Experience.totalForLevel(p.level + 1) - p.xp);
        }
      case Potion.enlightenment:
        game.revealMap();
        game.message('이 층의 구조가 머릿속에 떠오른다.');
    }
  }
}
