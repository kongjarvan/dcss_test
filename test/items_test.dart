import 'dart:math';

import 'package:dc_test/core/action/action.dart';
import 'package:dc_test/core/entity/actor.dart';
import 'package:dc_test/core/entity/monster_type.dart';
import 'package:dc_test/core/game.dart';
import 'package:dc_test/core/geometry.dart';
import 'package:dc_test/core/items/item.dart';
import 'package:dc_test/core/progression/attributes.dart';
import 'package:dc_test/core/progression/job.dart';
import 'package:dc_test/core/progression/skill_effects.dart';
import 'package:dc_test/core/progression/skills.dart';
import 'package:dc_test/core/world/dungeon_map.dart';
import 'package:dc_test/core/world/tile.dart';
import 'package:dc_test/ui/game_controller.dart';
import 'package:dc_test/ui/game_screen.dart';
import 'package:dc_test/ui/inventory_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DungeonMap openRoom(int w, int h) {
  final map = DungeonMap(w, h);
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      map[Pos(x, y)] = TileType.floor;
    }
  }
  return map;
}

Player playerWith(List<ItemType> gear, {Job? job}) {
  final p = Player(pos: const Pos(2, 2), job: job);
  for (final type in gear) {
    final item = Item(type);
    p.inventory.add(item);
    p.equip(item);
  }
  return p;
}

Game gameWith(Player player, {List<Monster> monsters = const []}) => Game(
  rng: Random(1),
  map: openRoom(16, 10),
  player: player,
  monsters: [...monsters],
);

const _neverHit = MonsterType(
  id: 'dummy',
  name: '허수아비',
  maxHp: 1000,
  stats: CombatStats(accuracy: 1, maxDamage: 1, evasion: 0),
  xp: 5,
);

Pos d(Pos dir, int n) => Pos(dir.x * n, dir.y * n);

void main() {
  group('직업별 시작 장비', () {
    test('전사: 숏소드 + 가죽 갑옷 + 버클러', () {
      final p = Player(pos: const Pos(0, 0), job: Job.fighter);
      expect(p.weaponType, ItemTypes.shortSword);
      expect(p.armourType, ItemTypes.leatherArmour);
      expect(p.shieldType, ItemTypes.buckler);
      expect(p.inventory, hasLength(3));
    });

    test('마법사: 로브, 맨손', () {
      final p = Player(pos: const Pos(0, 0), job: Job.wizard);
      expect(p.weaponType, isNull);
      expect(p.armourType, ItemTypes.robe);
    });

    test('사냥꾼: 단궁 + 가죽 갑옷', () {
      final p = Player(pos: const Pos(0, 0), job: Job.hunter);
      expect(p.launcher, ItemTypes.shortbow);
      expect(p.meleeWeapon, isNull); // 활로는 근접 공격 못 함 → 맨손
      expect(p.armourType, ItemTypes.leatherArmour);
    });
  });

  group('전투 수치', () {
    test('무기: 명중·최대 피해가 무기 값을 따른다', () {
      final bare = playerWith([]);
      final armed = playerWith([ItemTypes.longSword]);
      expect(armed.stats.maxDamage, 10);
      expect(armed.stats.accuracy, bare.stats.accuracy + 1);
      expect(bare.stats.maxDamage, 3); // 맨손
    });

    test('무기 숙련도: 명중·피해 배율·공격 속도', () {
      final p = playerWith([ItemTypes.longSword]);
      final acc0 = p.stats.accuracy;
      expect(p.meleeDelay, 14);
      p.skills
        ..setTraining(Skill.sword, true)
        ..train(SkillProgression.totalForLevel(10, 0));
      expect(p.skills.level(Skill.sword), 10);
      expect(p.stats.accuracy, acc0 + 5);
      expect(p.meleeDamageMultiplier, closeTo(1.2, 1e-9));
      expect(p.meleeDelay, 9);
    });

    test('공격 시간은 기본의 절반(최소 5) 아래로 줄지 않는다', () {
      expect(SkillEffects.attackDelay(14, 27), 7);
      expect(SkillEffects.attackDelay(10, 27), 5);
      expect(SkillEffects.attackDelay(13, 4), 11);
    });

    test('갑옷: 방어력, 갑옷 숙련도로 증가', () {
      final p = playerWith([ItemTypes.plateArmour]);
      expect(p.stats.armor, 10);
      p.skills
        ..setTraining(Skill.armour, true)
        ..train(SkillProgression.totalForLevel(10, 0));
      expect(p.stats.armor, (10 * 1.45).round());
    });

    test('갑옷·방패 무게로 회피가 줄고, 힘이 높으면 덜 줄어든다. 이동은 느려지지 않는다', () {
      final bare = playerWith([]);
      final eva = bare.stats.evasion; // 5
      final p = playerWith([ItemTypes.plateArmour]); // 무게 18 → 회피 -4
      expect(p.armourEvasionPenalty, 4);
      expect(p.stats.evasion, eva - 4);
      p.attributes.increase(Attribute.strength, 10); // 힘 20 → 절반
      expect(p.stats.evasion, eva - 2);
      p.attributes.increase(Attribute.strength, 10); // 힘 30 → 없음
      expect(p.stats.evasion, eva);
      expect(playerWith([ItemTypes.robe]).stats.evasion, eva);

      // 판금 + 타워 실드 (무게 26 → -6): 회피는 0 아래로 내려가지 않는다.
      final heavy = playerWith([ItemTypes.plateArmour, ItemTypes.towerShield]);
      expect(heavy.armourEvasionPenalty, 6);
      expect(heavy.stats.evasion, 0);

      // 이동 시간은 장비와 무관
      final game = gameWith(heavy);
      game.playerAct(const MoveAction(Direction.e));
      expect(game.lastActionCost, 10);
    });

    test('방패: 막기 확률, 방패술로 증가', () {
      final p = playerWith([ItemTypes.kiteShield]);
      final base = p.blockChance;
      expect(base, closeTo(8 / 23, 1e-9));
      p.skills
        ..setTraining(Skill.shield, true)
        ..train(SkillProgression.totalForLevel(10, 0));
      expect(p.blockChance, greaterThan(base));
      expect(playerWith([]).blockChance, 0);
    });

    test('회피 숙련도: 2레벨마다 회피 +1', () {
      final p = playerWith([]);
      final eva = p.stats.evasion;
      p.skills
        ..setTraining(Skill.dodging, true)
        ..train(SkillProgression.totalForLevel(6, 0));
      expect(p.stats.evasion, eva + 3);
    });

    test('방패에 막히면 피해를 받지 않는다', () {
      final p = playerWith([ItemTypes.towerShield]);
      p.skills
        ..setTraining(Skill.shield, true)
        ..train(1e7);
      final monster = Monster(
        const MonsterType(
          id: 'hitter',
          name: '타격수',
          maxHp: 10,
          stats: CombatStats(accuracy: 1000, maxDamage: 1, evasion: 0),
          xp: 1,
        ),
        pos: const Pos(3, 2),
      );
      final game = gameWith(p, monsters: [monster]);
      var blocked = 0;
      for (var i = 0; i < 200; i++) {
        p.hp = p.maxHp;
        AttackAction(p).perform(game, monster);
        if (p.hp == p.maxHp) blocked++;
      }
      // 최대 레벨 타워 실드: 막기 약 63%
      expect(blocked, inInclusiveRange(100, 160));
    });
  });

  group('장착 / 해제 / 줍기 / 버리기', () {
    test('양손 무기와 방패는 함께 쓸 수 없다', () {
      final p = playerWith([ItemTypes.buckler]);
      final halberd = Item(ItemTypes.halberd);
      p.inventory.add(halberd);
      final game = gameWith(p);
      expect(game.playerAct(EquipAction(halberd)), isFalse);
      expect(game.log.recent(1).single.text, contains('방패를 벗어야'));
      expect(game.time, 0);

      final p2 = playerWith([ItemTypes.shortbow]);
      final shield = Item(ItemTypes.buckler);
      p2.inventory.add(shield);
      expect(p2.equipProblem(shield), isNotNull);
    });

    test('갑옷 갈아입기는 벗는 시간 + 입는 시간', () {
      final p = playerWith([ItemTypes.robe]);
      final mail = Item(ItemTypes.chainMail);
      p.inventory.add(mail);
      final game = gameWith(p);
      expect(game.playerAct(EquipAction(mail)), isTrue);
      expect(game.lastActionCost, 100);
      expect(p.armourType, ItemTypes.chainMail);
      expect(game.log.recent(1).single.text, '로브 대신 사슬 갑옷을 입었다.');
    });

    test('해제하면 소지품에 남고, 장착 중인 아이템은 버릴 수 없다', () {
      final p = playerWith([ItemTypes.shortSword]);
      final sword = p.equipped(EquipSlot.weapon)!;
      final game = gameWith(p);
      expect(game.playerAct(DropAction(sword)), isFalse);
      expect(game.playerAct(const UnequipAction(EquipSlot.weapon)), isTrue);
      expect(p.weaponType, isNull);
      expect(p.inventory, contains(sword));
      expect(game.playerAct(DropAction(sword)), isTrue);
      expect(p.inventory, isEmpty);
      expect(game.itemsAt(p.pos), [sword]);
    });

    test('줍기: 발밑 아이템을 모두 줍고 1턴 걸린다', () {
      final p = playerWith([]);
      final game = gameWith(p);
      game.addFloorItem(p.pos, Item(ItemTypes.mace));
      game.addFloorItem(p.pos, Item(ItemTypes.buckler));
      expect(game.playerAct(const PickUpAction()), isTrue);
      expect(p.inventory.map((i) => i.type), [
        ItemTypes.mace,
        ItemTypes.buckler,
      ]);
      expect(game.itemsAt(p.pos), isEmpty);
      expect(game.lastActionCost, 10);
      expect(game.log.recent(1).single.text, '철퇴, 버클러를 주웠다.');
    });

    test('소지품이 가득 차면 남은 것은 못 줍는다', () {
      final p = playerWith([]);
      for (var i = 0; i < Player.inventoryCapacity - 1; i++) {
        p.inventory.add(Item(ItemTypes.dagger));
      }
      final game = gameWith(p);
      game.addFloorItem(p.pos, Item(ItemTypes.mace));
      game.addFloorItem(p.pos, Item(ItemTypes.club));
      game.playerAct(const PickUpAction());
      expect(p.isInventoryFull, isTrue);
      expect(game.itemsAt(p.pos), hasLength(1));
    });
  });

  group('원거리 공격', () {
    test('벽이나 다른 몬스터가 사이에 있으면 쏠 수 없다', () {
      final p = playerWith([ItemTypes.shortbow]);
      final game = gameWith(p);
      expect(game.hasLineOfFire(const Pos(2, 2), const Pos(8, 2)), isTrue);
      game.map[const Pos(5, 2)] = TileType.wall;
      expect(game.hasLineOfFire(const Pos(2, 2), const Pos(8, 2)), isFalse);
      game.map[const Pos(5, 2)] = TileType.floor;
      game.monsters.add(Monster(_neverHit, pos: const Pos(5, 2)));
      expect(game.hasLineOfFire(const Pos(2, 2), const Pos(8, 2)), isFalse);
    });

    test('활이 있으면 가장 가까운 쏠 수 있는 적을 겨눈다', () {
      final near = Monster(_neverHit, pos: const Pos(5, 2));
      final far = Monster(_neverHit, pos: const Pos(9, 5));
      final game = gameWith(
        playerWith([ItemTypes.shortbow]),
        monsters: [far, near],
      );
      expect(game.rangedTarget(), near);
      expect(game.autoFightAction(), isA<RangedAttackAction>());

      final melee = gameWith(playerWith([]), monsters: [near]);
      expect(melee.rangedTarget(), isNull);
    });

    test('화살로 처치하면 경험치를 얻고 활 시간만큼 걸린다', () {
      final p = playerWith([ItemTypes.shortbow])
        ..baseStats = const CombatStats(
          accuracy: 1000,
          maxDamage: 3,
          evasion: 5,
        );
      final target = Monster(MonsterTypes.goblin, pos: const Pos(6, 2))
        ..hp = 1
        ..baseStats = const CombatStats(accuracy: 6, maxDamage: 4, evasion: 0);
      final game = gameWith(p, monsters: [target]);
      expect(game.playerAct(RangedAttackAction(target)), isTrue);
      expect(target.isAlive, isFalse);
      expect(p.xp, MonsterTypes.goblin.xp);
      expect(game.lastActionCost, ItemTypes.shortbow.delay);
    });
  });

  group('장병기 사거리 2', () {
    Monster dummyAt(Pos p) => Monster(
      const MonsterType(
        id: 'target',
        name: '표적',
        maxHp: 1000,
        stats: CombatStats(accuracy: 1, maxDamage: 1, evasion: 0),
        xp: 1,
      ),
      pos: p,
    );

    test('창·할버드만 사거리 2', () {
      for (final t in ItemTypes.all.whereType<WeaponType>()) {
        expect(t.reach, t.skill == Skill.polearm ? 2 : 1, reason: t.name);
      }
      expect(playerWith([ItemTypes.spear]).reach, 2);
      expect(playerWith([ItemTypes.longSword]).reach, 1);
      expect(playerWith([]).reach, 1);
    });

    test('2칸 떨어진 적(대각선 포함)에 닿고, 3칸은 안 닿는다', () {
      final p = playerWith([ItemTypes.spear]); // (2,2)
      final game = gameWith(p);
      expect(game.canReach(dummyAt(const Pos(4, 2))), isTrue);
      expect(game.canReach(dummyAt(const Pos(4, 4))), isTrue);
      expect(game.canReach(dummyAt(const Pos(5, 2))), isFalse);
      expect(
        gameWith(
          playerWith([ItemTypes.longSword]),
        ).canReach(dummyAt(const Pos(4, 2))),
        isFalse,
      );
    });

    test('사이 칸이 벽이나 몬스터로 막히면 닿지 않는다', () {
      final p = playerWith([ItemTypes.spear]);
      final game = gameWith(p);
      final target = dummyAt(const Pos(4, 2));
      game.map[const Pos(3, 2)] = TileType.wall;
      expect(game.canReach(target), isFalse);
      game.map[const Pos(3, 2)] = TileType.floor;
      game.monsters.add(dummyAt(const Pos(3, 2)));
      expect(game.canReach(target), isFalse);
    });

    test('2칸 공격은 근접 공격 계산·시간을 그대로 쓴다', () {
      final p = playerWith([ItemTypes.spear])
        ..baseStats = const CombatStats(
          accuracy: 1000,
          maxDamage: 3,
          evasion: 5,
        );
      final target = dummyAt(const Pos(4, 2));
      final game = gameWith(p, monsters: [target]);
      expect(game.playerAct(ReachAttackAction(target)), isTrue);
      expect(target.hp, lessThan(1000));
      expect(game.lastActionCost, p.meleeDelay);
      expect(p.pos, const Pos(2, 2)); // 제자리에서 찌름
    });

    test('자동 전투는 2칸 거리면 다가가지 않고 찌른다', () {
      final game = gameWith(
        playerWith([ItemTypes.halberd]),
        monsters: [dummyAt(const Pos(4, 3))],
      );
      expect(game.autoFightAction(), isA<ReachAttackAction>());
    });

    test('2칸 떨어진 몬스터를 탭하면 찌른다', () {
      final c = GameController(seed: 1);
      final game = c.game;
      final p = game.player;
      final spear = Item(ItemTypes.spear);
      p.inventory.add(spear);
      p.equip(spear);
      game.monsters.clear();
      // 플레이어 주변 열린 방향으로 2칸 떨어진 곳에 표적 배치
      final dir = Direction.all.firstWhere(
        (d) =>
            game.map[p.pos + d] == TileType.floor &&
            game.map[p.pos + d + d] == TileType.floor,
      );
      final target = dummyAt(p.pos + d(dir, 2));
      game.monsters.add(target);
      game.updateFov();
      c.tapTile(target.pos);
      expect(target.hp, lessThan(1000));
      expect(c.isTraveling, isFalse);
      c.dispose();
    });
  });

  group('바닥 아이템과 자동 탐험', () {
    test('새 게임에는 바닥 아이템이 생긴다', () {
      final total = [
        for (var seed = 0; seed < 10; seed++)
          Game.newGame(seed: seed).itemPositions.length,
      ].reduce((a, b) => a + b);
      expect(total, greaterThan(10));
    });

    test('처음 보는 아이템 위에서만 자동 탐험이 멈춘다', () {
      final c = GameController(seed: 4);
      final game = c.game;
      game.monsters.clear();
      game.updateFov();
      expect(game.itemPositions, isNotEmpty);

      c.explore();
      for (var i = 0; c.isTraveling && i < 5000; i++) {
        c.autoMoveStep();
      }
      expect(game.itemsAt(game.player.pos), isNotEmpty);
      expect(game.log.recent(1).single.text, startsWith('여기에 '));
      expect(c.canPickUp, isTrue);
      c.pickUp();
      expect(game.itemsAt(game.player.pos), isEmpty);
      expect(game.player.inventory, isNotEmpty);
      c.dispose();
    });
  });

  testWidgets('소지품 화면에서 장착하고, 장비 화면에서 확인한다', (tester) async {
    final controller = GameController(seed: 1, job: Job.fighter);
    final axe = Item(ItemTypes.handAxe);
    controller.game.player.inventory.add(axe);
    await tester.pumpWidget(
      MaterialApp(home: GameScreen(controller: controller)),
    );

    await tester.tap(find.byTooltip('아이템'));
    await tester.pump();
    await tester.tap(find.byTooltip('소지품'));
    await tester.pumpAndSettle();
    expect(find.byType(InventoryScreen), findsOneWidget);
    expect(find.text('손도끼'), findsOneWidget);

    await tester.tap(find.text('손도끼'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('장착'));
    await tester.pumpAndSettle();
    expect(controller.game.player.weaponType, ItemTypes.handAxe);
    expect(find.text('숏소드 대신 손도끼를 손에 들었다.'), findsOneWidget);

    await tester.tapAt(const Offset(200, 40)); // 시트 바깥 → 시트 닫기
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('장비'));
    await tester.pumpAndSettle();
    expect(find.byType(EquipmentScreen), findsOneWidget);
    expect(find.text('손도끼'), findsOneWidget);
    expect(find.text('전투 능력'), findsOneWidget);
  });
}
