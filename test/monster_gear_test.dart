import 'dart:math';

import 'package:dc_test/core/action/action.dart';
import 'package:dc_test/core/entity/actor.dart';
import 'package:dc_test/core/entity/monster_type.dart';
import 'package:dc_test/core/game.dart';
import 'package:dc_test/core/geometry.dart';
import 'package:dc_test/core/items/item.dart';
import 'package:dc_test/core/korean.dart';
import 'package:dc_test/core/world/dungeon_map.dart';
import 'package:dc_test/core/world/tile.dart';
import 'package:dc_test/render/map_painter.dart';
import 'package:dc_test/ui/game_controller.dart';
import 'package:dc_test/ui/game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Game arena(Player player, Monster monster) {
  final map = DungeonMap(10, 8);
  for (var y = 1; y < 7; y++) {
    for (var x = 1; x < 9; x++) {
      map[Pos(x, y)] = TileType.floor;
    }
  }
  return Game(rng: Random(1), map: map, player: player, monsters: [monster]);
}

Monster goblinWith(List<ItemType> gear, {Pos pos = const Pos(4, 3)}) {
  final m = Monster(MonsterTypes.goblin, pos: pos);
  for (final t in gear) {
    m.equip(Item(t));
  }
  return m;
}

void main() {
  test('으로/로 조사', () {
    expect(euroRo('몽둥이'), '몽둥이로');
    expect(euroRo('단검'), '단검으로');
    expect(euroRo('숏소드'), '숏소드로');
    expect(euroRo('철퇴'), '철퇴로');
    expect(euroRo('활'), '활로'); // ㄹ 받침
    expect(euroRo('창'), '창으로');
  });

  group('몬스터 전투 수치', () {
    test('무기가 없으면 맨손(종류 기본 수치)', () {
      final m = goblinWith([]);
      expect(m.stats.maxDamage, 3);
      expect(m.stats.accuracy, 6);
    });

    test('무기를 들면 무기의 피해·명중, 갑옷은 방어력', () {
      final m = goblinWith([ItemTypes.club, ItemTypes.leatherArmour]);
      expect(m.stats.maxDamage, ItemTypes.club.damage);
      expect(m.stats.accuracy, 6 + ItemTypes.club.accuracy);
      expect(m.stats.armor, ItemTypes.leatherArmour.ac);
    });

    test('활은 근접에 못 쓰므로 맨손', () {
      final m = goblinWith([ItemTypes.shortbow]);
      expect(m.meleeWeapon, isNull);
      expect(m.stats.maxDamage, 3);
    });

    test('방패는 막기 확률', () {
      expect(goblinWith([]).blockChance, 0);
      expect(goblinWith([ItemTypes.kiteShield]).blockChance, greaterThan(0));
    });

    test('공격 속도는 무기와 무관하게 몬스터 고유 값', () {
      expect(goblinWith([ItemTypes.longSword]).meleeDelay, 10);
    });
  });

  test('생성 시 확률대로 장비를 든다 (고블린)', () {
    final rng = Random(3);
    var club = 0, dagger = 0, sword = 0, bare = 0, armour = 0;
    const n = 4000;
    for (var i = 0; i < n; i++) {
      final m = Monster(MonsterTypes.goblin, pos: const Pos(0, 0))
        ..equipRandomGear(rng);
      switch (m.weaponType) {
        case ItemTypes.club:
          club++;
        case ItemTypes.dagger:
          dagger++;
        case ItemTypes.shortSword:
          sword++;
        case null:
          bare++;
      }
      if (m.armourType != null) armour++;
    }
    expect(club / n, closeTo(0.40, 0.03));
    expect(dagger / n, closeTo(0.18, 0.03));
    expect(sword / n, closeTo(0.042, 0.02));
    expect(bare / n, closeTo(0.378, 0.03));
    expect(armour / n, closeTo(0.15, 0.03));

    // 새 게임의 몬스터들도 장비를 갖는다.
    final armed = [
      for (var seed = 0; seed < 5; seed++) ...Game.newGame(seed: seed).monsters,
    ].where((m) => m.weaponType != null);
    expect(armed, isNotEmpty);
  });

  test('몬스터 공격 메시지에 무기가 나온다', () {
    final player = Player(pos: const Pos(3, 3))
      ..baseStats = const CombatStats(accuracy: 1, maxDamage: 1, evasion: 0);
    final m = goblinWith([ItemTypes.club])
      ..baseStats = const CombatStats(accuracy: 1000, maxDamage: 3, evasion: 4);
    final game = arena(player, m);
    AttackAction(player).perform(game, m);
    expect(game.log.recent(1).single.text, startsWith('고블린이 몽둥이로 당신을 공격해'));

    final bare = goblinWith([])
      ..baseStats = const CombatStats(accuracy: 1000, maxDamage: 3, evasion: 4);
    AttackAction(player).perform(game, bare);
    expect(game.log.recent(1).single.text, startsWith('고블린이 당신을 공격해'));
  });

  test('몬스터가 죽으면 장비를 그 자리에 떨어뜨린다', () {
    final player = Player(
      pos: const Pos(3, 3),
    )..baseStats = const CombatStats(accuracy: 1000, maxDamage: 20, evasion: 0);
    final m = goblinWith([ItemTypes.dagger, ItemTypes.leatherArmour])
      ..baseStats = const CombatStats(accuracy: 0, maxDamage: 1, evasion: 0);
    final game = arena(player, m);
    // 갑옷에 막히는 굴림이 있을 수 있으므로 죽을 때까지 공격한다.
    for (var i = 0; i < 50 && m.isAlive; i++) {
      player.hp = player.maxHp;
      game.playerAct(const MoveAction(Direction.e));
    }
    expect(m.isAlive, isFalse);
    expect(game.itemsAt(const Pos(4, 3)).map((i) => i.type).toSet(), {
      ItemTypes.dagger,
      ItemTypes.leatherArmour,
    });
    expect(m.equipment, isEmpty);
  });

  testWidgets('길게 누르면 몬스터 이름·상태·장비가 팝업에 나온다', (tester) async {
    final controller = GameController(seed: 1);
    final game = controller.game;
    game.monsters.clear();
    final spot = Direction.all
        .map((d) => game.player.pos + d)
        .firstWhere((p) => game.map[p].passable);
    final m = goblinWith([ItemTypes.club], pos: spot)
      ..hp = 3
      ..awake = true
      ..lastKnownPlayerPos = game.player.pos;
    game.monsters.add(m);
    game.updateFov();
    await tester.pumpWidget(
      MaterialApp(home: GameScreen(controller: controller)),
    );

    final mapFinder = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is MapPainter,
    );
    final painter =
        tester.widget<CustomPaint>(mapFinder).painter! as MapPainter;
    final box = tester.getRect(mapFinder);
    final o = MapPainter.cameraOrigin(
      box.size,
      game.player.pos,
      painter.tileSize,
    );
    await tester.longPressAt(
      box.topLeft +
          Offset(
            (spot.x + 0.5 - o.dx) * painter.tileSize,
            (spot.y + 0.5 - o.dy) * painter.tileSize,
          ),
    );
    await tester.pumpAndSettle();
    expect(find.text('고블린'), findsOneWidget);
    expect(find.text('심하게 다침 · 당신을 쫓는 중'), findsOneWidget);
    expect(find.text('몽둥이'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pump(const Duration(seconds: 5));
  });
}
