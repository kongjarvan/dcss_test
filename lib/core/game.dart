import 'dart:math';

import 'action/action.dart';
import 'ai/monster_ai.dart';
import 'ai/pathfinding.dart';
import 'entity/actor.dart';
import 'entity/monster_type.dart';
import 'fov/shadowcasting.dart';
import 'geometry.dart';
import 'entity/status.dart';
import 'items/item.dart';
import 'items/potion_appearance.dart';
import 'world/tile.dart';
import 'korean.dart';
import 'level.dart';
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
    required DungeonMap map,
    required this.player,
    List<Monster>? monsters,
  }) : level = Level(depth: 1, map: map, monsters: monsters) {
    _levels[1] = level;
    // 게임마다 물약 색을 무작위로 배정한다 (마셔 보기 전엔 무슨 물약인지 모름).
    final looks = [...PotionAppearance.all]..shuffle(rng);
    for (final (i, potion) in Potion.values.indexed) {
      potionAppearance[potion] = looks[i];
    }
    updateFov();
  }

  // ── 물약 식별 ──
  final Map<Potion, PotionAppearance> potionAppearance = {};

  /// 마셔서 정체를 알게 된 물약.
  final Set<Potion> identifiedPotions = {};

  bool isIdentified(Item item) => switch (item.type) {
    PotionType(:final potion) => identifiedPotions.contains(potion),
    _ => true,
  };

  /// 화면에 보이는 이름. 미확인 물약은 색으로, 여러 개면 개수를 붙인다.
  /// 예) "붉은 물약", "치유 물약 3개"
  String nameOf(Item item, {bool withCount = true}) {
    final base = switch (item.type) {
      PotionType(:final potion) when !identifiedPotions.contains(potion) =>
        '${potionAppearance[potion]!.name} 물약',
      _ => item.name,
    };
    return withCount && item.quantity > 1 ? '$base ${item.quantity}개' : base;
  }

  factory Game.newGame({int? seed, Species species = Species.human, Job? job}) {
    final rng = Random(seed ?? DateTime.now().microsecondsSinceEpoch);
    final generated = DungeonGenerator(rng).generate();
    final player = Player(
      pos: generated.rooms.first.center,
      species: species,
      job: job,
    );
    final game = Game(rng: rng, map: generated.map, player: player);
    game._enterGeneratedLevel(generated, depth: 1);
    game.message('던전 1층에 들어섰다. 화면을 탭해 이동하세요.');
    return game;
  }

  // ── 층 ──
  /// 지금 있는 층.
  Level level;

  /// 한 번이라도 가 본 층들 (깊이별).
  final Map<int, Level> _levels = {};

  int get depth => level.depth;
  DungeonMap get map => level.map;
  List<Monster> get monsters => level.monsters;
  List<Pos> get stairsDown => level.stairsDown;
  List<Pos> get stairsUp => level.stairsUp;

  /// 이 층에 가 본 적이 있는지 (깊이별).
  bool hasVisited(int depth) => _levels.containsKey(depth);

  /// 깊이에 따른 방당 최대 몬스터 수 (1층 2마리, 3층마다 1마리씩 늘어남).
  int get maxMonstersPerRoom => 2 + (depth - 1) ~/ 3;

  /// 새로 생성한 층을 현재 층으로 만들고 몬스터·아이템을 배치한다.
  void _enterGeneratedLevel(GeneratedLevel generated, {required int depth}) {
    level = Level(
      depth: depth,
      map: generated.map,
      stairsDown: generated.stairsDown,
      stairsUp: generated.stairsUp,
    );
    _levels[depth] = level;
    _monstersInView = {};

    // 도착 지점(1층 시작 방, 올라가는 계단이 있는 방)에는 몬스터를 두지 않는다.
    bool isArrivalRoom(GridRect room) =>
        (depth == 1 && room == generated.rooms.first) ||
        generated.stairsUp.any(room.contains);
    Pos randomCell(GridRect room) => Pos(
      room.left + rng.nextInt(room.width),
      room.top + rng.nextInt(room.height),
    );
    for (final room in generated.rooms) {
      if (isArrivalRoom(room)) continue;
      final count = rng.nextInt(maxMonstersPerRoom + 1);
      for (var i = 0; i < count; i++) {
        final p = randomCell(room);
        if (p == player.pos || monsters.any((m) => m.pos == p)) continue;
        // 초기 에너지를 흩뿌려 몬스터들이 같은 박자로 움직이지 않게 한다.
        monsters.add(
          Monster(MonsterTypes.randomFor(depth, rng), pos: p)
            ..energy = -rng.nextInt(autPerTurn * normalSpeed)
            ..equipRandomGear(rng),
        );
      }
      // 무작위 장비 하나, 물약 하나 (각각 일정 확률).
      if (rng.nextDouble() < itemChancePerRoom) {
        final type = ItemTypes.all[rng.nextInt(ItemTypes.all.length)];
        addFloorItem(randomCell(room), Item(type));
      }
      if (rng.nextDouble() < potionChancePerRoom) {
        addFloorItem(
          randomCell(room),
          Item(
            PotionType.of(randomPotion(rng)),
            quantity: rng.nextDouble() < 0.15 ? 2 : 1,
          ),
        );
      }
    }
    updateFov();
  }

  /// 발밑 계단을 이용한다. 내려가는 계단이면 아래층(처음이면 새로 생성),
  /// 올라가는 계단이면 위층으로. 짝이 되는 계단 위에 도착한다. 계단이 아니면 false.
  bool useStairs() {
    final here = player.pos;
    final down = stairsDown.indexOf(here);
    final up = stairsUp.indexOf(here);
    if (down >= 0) {
      final target = depth + 1;
      final known = _levels[target];
      if (known == null) {
        final generated = DungeonGenerator(rng).generate(stairsUp: 3);
        player.pos = generated.stairsUp[down];
        _enterGeneratedLevel(generated, depth: target);
      } else {
        _switchLevel(known, known.stairsUp[down]);
      }
      message('계단을 내려가 $depth층에 도착했다.');
      return true;
    }
    if (up >= 0 && _levels[depth - 1] != null) {
      final above = _levels[depth - 1]!;
      _switchLevel(above, above.stairsDown[up]);
      message('계단을 올라 $depth층으로 돌아왔다.');
      return true;
    }
    return false;
  }

  /// 저장해 둔 층으로 옮긴다. 도착 칸에 몬스터가 있으면 가까운 빈칸으로 비켜 준다.
  void _switchLevel(Level target, Pos arrival) {
    level = target;
    player.pos = arrival;
    _monstersInView = {};
    for (final m in monsters) {
      if (m.isAlive && m.pos == arrival) m.pos = _nearestFreeCell(arrival);
    }
    updateFov();
  }

  Pos _nearestFreeCell(Pos from) {
    final seen = <Pos>{from};
    final queue = [from];
    for (var i = 0; i < queue.length; i++) {
      for (final d in Direction.all) {
        final q = queue[i] + d;
        if (!map.contains(q) || !map[q].passable || !seen.add(q)) continue;
        if (actorAt(q) == null && q != player.pos) return q;
        queue.add(q);
      }
    }
    return from;
  }

  static const fovRadius = 8;

  final Random rng;
  final Player player;
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
    // 가속·둔화는 플레이어 행동 시간에 곱해진다.
    final adjusted = max(1, (cost * player.actionTimeMultiplier).round());
    lastActionCost = adjusted;
    if (player.pos != from) _noticeItemsUnderfoot();
    _advanceTime(adjusted);
    return true;
  }

  /// 물약 종류를 빈도([Potion.weight])에 따라 하나 고른다.
  static Potion randomPotion(Random rng) {
    final total = Potion.values.fold(0, (sum, p) => sum + p.weight);
    var roll = rng.nextInt(total);
    for (final p in Potion.values) {
      roll -= p.weight;
      if (roll < 0) return p;
    }
    return Potion.values.last;
  }

  // ── 바닥 아이템 ──
  /// 시작 방이 아닌 방에 장비가 놓일 확률.
  static const itemChancePerRoom = 0.4;

  /// 시작 방이 아닌 방에 물약이 놓일 확률.
  static const potionChancePerRoom = 0.5;

  Map<Pos, List<Item>> get _floorItems => level.floorItems;
  Set<Pos> get _noticedPiles => level.noticedPiles;

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

  /// 자동 탐험 중 저절로 주울 아이템: 소모품(물약) 중 해롭다고 밝혀진 것이 아닌 것.
  bool shouldAutoPickUp(Item item) => switch (item.type) {
    PotionType(:final potion) =>
      !(identifiedPotions.contains(potion) && potion.harmful),
    _ => false,
  };

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
    final names = items.map(nameOf).join(', ');
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
    _tickStatuses(aut);
    if (isGameOver) return;
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

  /// 상태 효과 시간을 줄이고, 끝난 효과를 알린다. 중독은 10 aut마다 HP -1.
  void _tickStatuses(int aut) {
    final p = player;
    if (p.has(Status.poison)) {
      p.poisonProgress += min(aut, p.statuses[Status.poison]!);
      while (p.poisonProgress >= autPerTurn && p.isAlive) {
        p.poisonProgress -= autPerTurn;
        p.hp--;
      }
      if (!p.isAlive) {
        message('당신은 독으로 죽었다...');
        return;
      }
    }
    for (final status in [...p.statuses.keys]) {
      final left = p.statuses[status]! - aut;
      if (left > 0) {
        p.statuses[status] = left;
      } else {
        p.statuses.remove(status);
        if (status == Status.poison) p.poisonProgress = 0;
        message(status.expireMessage);
      }
    }
  }

  /// 이 층의 바닥·문과 그 둘레 벽을 모두 본 것으로 표시 (깨달음 물약).
  void revealMap() {
    for (var y = 0; y < map.height; y++) {
      for (var x = 0; x < map.width; x++) {
        final p = Pos(x, y);
        if (map[p] == TileType.wall &&
            !Direction.all.any(
              (d) => map.contains(p + d) && map[p + d] != TileType.wall,
            )) {
          continue;
        }
        map.markExplored(p);
      }
    }
  }

  void _regenerate(int aut) {
    final p = player;
    // 중독 중에는 HP가 재생되지 않는다.
    if (p.hp >= p.maxHp || p.has(Status.poison)) {
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
      // 몬스터는 장비를 그 자리에 떨어뜨린다.
      if (victim is Monster) {
        for (final item in victim.equipment.values) {
          addFloorItem(victim.pos, item);
        }
        victim.equipment.clear();
      }
      if (killer.isPlayer && victim is Monster) {
        kills++;
        grantXp(victim.type.xp);
      }
    }
  }

  /// 경험치를 주고 캐릭터 레벨·숙련도 상승을 알린다.
  void grantXp(int amount) {
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
