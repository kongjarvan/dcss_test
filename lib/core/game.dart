import 'dart:math';

import 'action/action.dart';
import 'ai/monster_ai.dart';
import 'ai/pathfinding.dart';
import 'entity/actor.dart';
import 'entity/monster_type.dart';
import 'fov/shadowcasting.dart';
import 'geometry.dart';
import 'items/item.dart';
import 'korean.dart';
import 'message_log.dart';
import 'progression/attribute_effects.dart';
import 'progression/attributes.dart';
import 'progression/job.dart';
import 'progression/species.dart';
import 'time/energy.dart';
import 'world/dungeon_generator.dart';
import 'world/dungeon_map.dart';

/// 게임 상태와 턴 진행. Flutter에 의존하지 않는 순수 Dart.
class Game {
  Game({
    required this.rng,
    required this.map,
    required this.player,
    List<Monster>? monsters,
  }) : monsters = monsters ?? [] {
    updateFov();
  }

  factory Game.newGame({int? seed, Species species = Species.human, Job? job}) {
    final rng = Random(seed ?? DateTime.now().microsecondsSinceEpoch);
    final level = DungeonGenerator(rng).generate();
    final player = Player(
      pos: level.rooms.first.center,
      species: species,
      job: job,
    );
    final monsters = <Monster>[];

    for (final room in level.rooms.skip(1)) {
      final count = rng.nextInt(3);
      for (var i = 0; i < count; i++) {
        final p = Pos(
          room.left + rng.nextInt(room.width),
          room.top + rng.nextInt(room.height),
        );
        if (p == player.pos || monsters.any((m) => m.pos == p)) continue;
        // 초기 에너지를 흩뿌려 몬스터들이 같은 박자로 움직이지 않게 한다.
        monsters.add(
          Monster(MonsterTypes.goblin, pos: p)
            ..energy = -rng.nextInt(autPerTurn * normalSpeed),
        );
      }
    }

    final game = Game(
      rng: rng,
      map: level.map,
      player: player,
      monsters: monsters,
    );
    // 시작 방을 뺀 방마다 일정 확률로 무작위 장비 하나.
    for (final room in level.rooms.skip(1)) {
      if (rng.nextDouble() >= itemChancePerRoom) continue;
      final p = Pos(
        room.left + rng.nextInt(room.width),
        room.top + rng.nextInt(room.height),
      );
      final type = ItemTypes.all[rng.nextInt(ItemTypes.all.length)];
      game.addFloorItem(p, Item(type));
    }
    game.message('던전 1층에 들어섰다. 화면을 탭해 이동하세요.');
    return game;
  }

  static const fovRadius = 8;

  final Random rng;
  final DungeonMap map;
  final Player player;
  final List<Monster> monsters;
  final MessageLog log = MessageLog();

  /// 누적 게임 시간 (aut).
  int time = 0;

  /// 플레이어 직전 행동의 소요 시간 (aut).
  int lastActionCost = 0;

  int kills = 0;

  Set<Monster> _monstersInView = {};

  bool get isGameOver => !player.isAlive;

  Iterable<Monster> get visibleMonsters =>
      monsters.where((m) => m.isAlive && map.isVisible(m.pos));

  void message(String text) => log.add(text, time);

  Actor? actorAt(Pos p) {
    if (player.isAlive && player.pos == p) return player;
    for (final m in monsters) {
      if (m.isAlive && m.pos == p) return m;
    }
    return null;
  }

  /// 플레이어 행동을 수행하고, 성공하면 그 소요 시간만큼 세계를 진행시킨다.
  /// 시간이 흘렀으면 true.
  bool playerAct(Action action) {
    if (isGameOver) return false;
    final from = player.pos;
    newItemsUnderfoot = false;
    final cost = _perform(action, player);
    if (cost == null) return false;
    lastActionCost = cost;
    if (player.pos != from) _noticeItemsUnderfoot();
    _advanceTime(cost);
    return true;
  }

  // ── 바닥 아이템 ──
  /// 시작 방이 아닌 방에 장비가 놓일 확률.
  static const itemChancePerRoom = 0.4;

  final Map<Pos, List<Item>> _floorItems = {};

  /// 플레이어가 이미 올라서서 확인한 아이템 더미 (자동 탐험이 다시 찾아가지 않음).
  final Set<Pos> _noticedPiles = {};

  List<Item> itemsAt(Pos p) => List.unmodifiable(_floorItems[p] ?? const []);

  Iterable<Pos> get itemPositions => _floorItems.keys;

  void addFloorItem(Pos p, Item item, {bool noticed = false}) {
    (_floorItems[p] ??= []).add(item);
    if (noticed) {
      _noticedPiles.add(p);
    } else {
      _noticedPiles.remove(p);
    }
  }

  void removeFloorItem(Pos p, Item item) {
    final pile = _floorItems[p];
    if (pile == null) return;
    pile.remove(item);
    if (pile.isEmpty) {
      _floorItems.remove(p);
      _noticedPiles.remove(p);
    }
  }

  /// 아직 확인하지 않은, 본 적 있는 아이템 더미.
  bool hasUnnoticedItems(Pos p) =>
      _floorItems.containsKey(p) &&
      !_noticedPiles.contains(p) &&
      map.isExplored(p);

  /// 직전 행동으로 처음 보는 아이템 더미 위에 올라섰는지 (자동 탐험 정지용).
  bool newItemsUnderfoot = false;

  void _noticeItemsUnderfoot() {
    final items = itemsAt(player.pos);
    if (items.isEmpty) return;
    newItemsUnderfoot = _noticedPiles.add(player.pos);
    final names = items.map((i) => i.name).join(', ');
    message('여기에 ${iGa(names)} 있다.');
  }

  // ── 원거리 ──
  /// [from]에서 [to]까지 쏠 수 있는지. 사이 칸에 벽·닫힌 문·다른 생물이 없어야 한다.
  bool hasLineOfFire(Pos from, Pos to, {int range = fovRadius}) {
    if (from.distanceTo(to) > range) return false;
    for (final p in _lineBetween(from, to)) {
      if (!map.contains(p) || map[p].blocksSight || actorAt(p) != null) {
        return false;
      }
    }
    return true;
  }

  /// 플레이어 근접 공격이 [target]에 닿는지 (장병기는 2칸, 사이 칸이 막히면 안 됨).
  bool canReach(Actor target) =>
      target.isAlive &&
      target.pos != player.pos &&
      hasLineOfFire(player.pos, target.pos, range: player.reach);

  /// 양 끝을 뺀 직선 위의 칸들 (브레젠햄).
  Iterable<Pos> _lineBetween(Pos a, Pos b) sync* {
    var x = a.x, y = a.y;
    final dx = (b.x - a.x).abs(), dy = -(b.y - a.y).abs();
    final sx = a.x < b.x ? 1 : -1, sy = a.y < b.y ? 1 : -1;
    var err = dx + dy;
    while (true) {
      final e2 = 2 * err;
      if (e2 >= dy) {
        err += dy;
        x += sx;
      }
      if (e2 <= dx) {
        err += dx;
        y += sy;
      }
      final p = Pos(x, y);
      if (p == b) return;
      yield p;
    }
  }

  /// 활로 쏠 수 있는 가장 가까운 적. 활이 없거나 대상이 없으면 null.
  Monster? rangedTarget() {
    if (player.launcher == null) return null;
    final targets = visibleMonsters.toList()
      ..sort(
        (a, b) => a.pos
            .distanceTo(player.pos)
            .compareTo(b.pos.distanceTo(player.pos)),
      );
    for (final m in targets) {
      if (hasLineOfFire(player.pos, m.pos)) return m;
    }
    return null;
  }

  /// 대체 행동을 따라가며 실행. 실패하면 null, 성공하면 소요 aut.
  int? _perform(Action action, Actor actor) {
    var current = action;
    while (true) {
      final result = current.perform(this, actor);
      final alternate = result.alternate;
      if (alternate == null) return result.succeeded ? result.cost : null;
      current = alternate;
    }
  }

  void _advanceTime(int aut) {
    time += aut;
    _regenerate(aut);
    updateFov();

    for (final m in monsters) {
      if (!m.isAlive) continue;
      EnergyScheduler.grant(m, aut);
      while (m.isAlive && !isGameOver && EnergyScheduler.canAct(m)) {
        final cost =
            _perform(MonsterAi.chooseAction(this, m), m) ??
            _perform(const WaitAction(), m)!;
        EnergyScheduler.spend(m, cost);
      }
      if (isGameOver) break;
    }

    monsters.removeWhere((m) => !m.isAlive);
    updateFov();
  }

  void _regenerate(int aut) {
    final p = player;
    if (p.hp >= p.maxHp) {
      p.hpRegenProgress = 0;
    } else {
      p.hpRegenProgress += aut;
      final step = p.autPerHpRegen;
      while (p.hpRegenProgress >= step && p.hp < p.maxHp) {
        p.hpRegenProgress -= step;
        p.hp++;
      }
    }
    if (p.mp >= p.maxMp) {
      p.mpRegenProgress = 0;
    } else {
      p.mpRegenProgress += aut;
      while (p.mpRegenProgress >= Player.autPerMpRegen && p.mp < p.maxMp) {
        p.mpRegenProgress -= Player.autPerMpRegen;
        p.mp++;
      }
    }
  }

  void updateFov() {
    computeFov(map, player.pos, fovRadius);
    final inView = visibleMonsters.toSet();
    for (final m in inView.difference(_monstersInView)) {
      message('${iGa(m.name)} 시야에 들어왔다.');
    }
    _monstersInView = inView;
  }

  void onActorDied(Actor victim, Actor killer) {
    if (victim.isPlayer) {
      message('당신은 죽었다...');
    } else {
      message('${eulReul(victim.name)} 죽였다!');
      if (killer.isPlayer && victim is Monster) {
        kills++;
        _grantXp(victim.type.xp);
      }
    }
  }

  void _grantXp(int amount) {
    for (final (skill, level) in player.skills.train(amount)) {
      message('${skill.label} 숙련도가 ${numberIGa(level)} 되었다.');
    }
    for (final level in player.gainXp(amount)) {
      message('레벨 업! 레벨 ${numberIGa(level)} 되었다. 능력치를 하나 올릴 수 있다.');
    }
  }

  /// 능력치 포인트 투자. 턴을 소모하지 않는다.
  bool increaseAttribute(Attribute attribute) {
    if (!player.spendStatPoint(attribute)) return false;
    final gain = AttributeEffects.gainOnIncrease(attribute);
    final bonus = [
      if (gain.hp > 0) '최대 HP +${gain.hp}',
      if (gain.mp > 0) '최대 MP +${gain.mp}',
    ].join(', ');
    final suffix = bonus.isEmpty ? '' : ' ($bonus)';
    message(
      '${iGa(attribute.label)} ${numberIGa(player.attributes[attribute])} 되었다.$suffix',
    );
    return true;
  }

  /// 가장 가까운 적을 공격하거나, 인접하지 않았으면 한 칸 다가가는 행동.
  /// 보이는 적이 없거나 다가갈 길이 없으면 null.
  Action? autoFightAction() {
    final shootable = rangedTarget();
    if (shootable != null) return RangedAttackAction(shootable);
    final targets = visibleMonsters.toList()
      ..sort(
        (a, b) => a.pos
            .distanceTo(player.pos)
            .compareTo(b.pos.distanceTo(player.pos)),
      );
    for (final m in targets) {
      if (m.pos.isAdjacentTo(player.pos)) return AttackAction(m);
      if (canReach(m)) return ReachAttackAction(m);
      final path = findPath(
        player.pos,
        m.pos,
        (p) => map.contains(p) && map[p].traversable && actorAt(p) == null,
        maxNodes: 800,
      );
      if (path != null && path.isNotEmpty) {
        return MoveAction(path.first - player.pos);
      }
    }
    return null;
  }

  /// 탐험 경계: 이미 본 통행 가능한 칸 중, 아직 보지 못한 칸과 맞닿은 칸.
  bool isExploreFrontier(Pos p) =>
      map.isExplored(p) &&
      map[p].traversable &&
      Direction.all.any((d) {
        final q = p + d;
        return map.contains(q) && !map.isExplored(q);
      });

  /// 자동 탐험이 찾아갈 곳: 탐험 경계, 또는 확인하지 않은 아이템 더미.
  bool isExploreGoal(Pos p) => isExploreFrontier(p) || hasUnnoticedItems(p);

  /// 이동 칸 수 기준으로 가장 가까운 탐험 목표. 더 탐험할 곳이 없으면 null.
  Pos? exploreTarget() {
    final visited = <Pos>{player.pos};
    final queue = <Pos>[player.pos];
    for (var i = 0; i < queue.length; i++) {
      final p = queue[i];
      if (p != player.pos && isExploreGoal(p)) return p;
      for (final d in Direction.all) {
        final q = p + d;
        if (map.isExplored(q) && map[q].traversable && visited.add(q)) {
          queue.add(q);
        }
      }
    }
    return null;
  }

  /// 탐험한 칸만 거쳐 [dest]까지 가는 경로. 갈 수 없으면 null.
  List<Pos>? travelPath(Pos dest) {
    if (!map.isExplored(dest) || !map[dest].traversable) return null;
    return findPath(
      player.pos,
      dest,
      (p) => map.isExplored(p) && map[p].traversable,
    );
  }
}
