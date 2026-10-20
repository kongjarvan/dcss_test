import 'dart:math';

import 'package:dc_test/core/action/action.dart';
import 'package:dc_test/core/entity/actor.dart';
import 'package:dc_test/core/entity/monster_type.dart';
import 'package:dc_test/core/game.dart';
import 'package:dc_test/core/geometry.dart';
import 'package:dc_test/core/progression/job.dart';
import 'package:dc_test/core/progression/skills.dart';
import 'package:dc_test/core/progression/species.dart';
import 'package:dc_test/core/world/dungeon_map.dart';
import 'package:dc_test/core/world/tile.dart';
import 'package:dc_test/ui/game_controller.dart';
import 'package:dc_test/ui/game_screen.dart';
import 'package:dc_test/ui/skills_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

typedef P = SkillProgression;

void main() {
  test('숙련도 목록 17종', () {
    expect(Skill.values.map((s) => s.label), [
      '둔기', '검', '도끼', '장병기', '맨손격투', '활', '투척무기', '갑옷', '회피', //
      '은신', '방패술', '비전마법', '화염마법', '대지마법', '얼음마법', '소환술', '기도술',
    ]);
  });

  group('성장 곡선과 적성', () {
    test('필요 경험치는 레벨마다 증가한다', () {
      for (var l = 1; l <= P.maxLevel; l++) {
        expect(P.baseTotalForLevel(l), greaterThan(P.baseTotalForLevel(l - 1)));
      }
    });

    test('적성 +4면 절반, -4면 두 배', () {
      expect(
        P.totalForLevel(10, 4),
        closeTo(P.baseTotalForLevel(10) / 2, 1e-6),
      );
      expect(
        P.totalForLevel(10, -4),
        closeTo(P.baseTotalForLevel(10) * 2, 1e-6),
      );
      expect(P.totalForLevel(10, 0), P.baseTotalForLevel(10));
    });
  });

  group('SkillSet', () {
    test('시작 숙련도는 해당 레벨에서 시작하고 훈련이 켜져 있다', () {
      final s = SkillSet(startingLevels: {Skill.sword: 3, Skill.armour: 2});
      expect(s.level(Skill.sword), 3);
      expect(s.level(Skill.armour), 2);
      expect(s.level(Skill.bow), 0);
      expect(s.training, {Skill.sword, Skill.armour});
      expect(s.progress(Skill.sword), 0);
    });

    test('경험치는 훈련 중인 숙련도에 똑같이 나뉜다', () {
      final s = SkillSet()
        ..setTraining(Skill.sword, true)
        ..setTraining(Skill.bow, true);
      s.train(20);
      expect(s.xp(Skill.sword), 10);
      expect(s.xp(Skill.bow), 10);
      expect(s.xp(Skill.axe), 0);
    });

    test('레벨이 오르면 (숙련도, 새 레벨)을 반환한다', () {
      final s = SkillSet()..setTraining(Skill.sword, true);
      expect(s.train(9), isEmpty);
      expect(s.train(1), [(Skill.sword, 1)]);
      // 한 번에 여러 레벨: 마지막 레벨만 보고
      expect(s.train(P.baseTotalForLevel(5)), [(Skill.sword, 5)]);
    });

    test('훈련 중인 숙련도가 없으면 경험치를 보관했다가 나중에 준다', () {
      final s = SkillSet();
      expect(s.train(30), isEmpty);
      expect(s.pool, 30);
      s.setTraining(Skill.ice, true);
      s.train(0);
      expect(s.xp(Skill.ice), 30);
      expect(s.pool, 0);
    });

    test('적성이 높을수록 같은 경험치로 더 높이 오른다', () {
      final elf = SkillSet(aptitudes: Species.elf.aptitudes)
        ..setTraining(Skill.bow, true);
      final dwarf = SkillSet(aptitudes: Species.dwarf.aptitudes)
        ..setTraining(Skill.bow, true);
      elf.train(1000);
      dwarf.train(1000);
      expect(elf.level(Skill.bow), greaterThan(dwarf.level(Skill.bow)));
    });

    test('최대 레벨에 도달하면 훈련이 꺼지고 더 오르지 않는다', () {
      final s = SkillSet()..setTraining(Skill.sword, true);
      s.train(1e9);
      expect(s.level(Skill.sword), P.maxLevel);
      expect(s.isTraining(Skill.sword), isFalse);
      s.setTraining(Skill.sword, true);
      expect(s.isTraining(Skill.sword), isFalse);
    });
  });

  group('종족 적성 / 직업 시작 숙련도', () {
    test('적성은 -3 ~ +3, 인간은 모두 0', () {
      for (final sp in Species.values) {
        for (final apt in sp.aptitudes.values) {
          expect(apt, inInclusiveRange(-3, 3), reason: sp.name);
        }
      }
      expect(Skill.values.map(Species.human.aptitude).toSet(), {0});
    });

    test('엘프: 마법 계열 +2, 그 밖에는 최대 +1', () {
      for (final skill in Skill.values) {
        final apt = Species.elf.aptitude(skill);
        if (skill.category == SkillCategory.magic) {
          expect(apt, 2, reason: skill.label);
        } else {
          expect(apt, lessThanOrEqualTo(1), reason: skill.label);
        }
      }
    });

    test('직업별 시작 숙련도', () {
      expect(Job.fighter.startingSkills[Skill.sword], 3);
      expect(Job.wizard.startingSkills[Skill.arcane], 3);
      expect(Job.hunter.startingSkills[Skill.bow], 3);
    });

    test('플레이어는 종족 적성과 직업 시작 숙련도로 시작한다', () {
      final p = Player(
        pos: const Pos(0, 0),
        species: Species.elf,
        job: Job.hunter,
      );
      expect(p.skills.level(Skill.bow), 3);
      expect(p.skills.aptitude(Skill.bow), 1);
      expect(p.skills.isTraining(Skill.bow), isTrue);
      expect(p.skills.isTraining(Skill.sword), isFalse);
    });
  });

  test('몬스터를 처치하면 경험치가 훈련 중인 숙련도에 쌓인다', () {
    final map = DungeonMap(10, 10);
    for (var y = 1; y < 9; y++) {
      for (var x = 1; x < 9; x++) {
        map[Pos(x, y)] = TileType.floor;
      }
    }
    final player = Player(pos: const Pos(3, 3))
      ..baseStats = const CombatStats(accuracy: 1000, maxDamage: 5, evasion: 0)
      ..skills.setTraining(Skill.sword, true);
    final goblin = Monster(MonsterTypes.goblin, pos: const Pos(4, 3))..hp = 1;
    final game = Game(
      rng: Random(1),
      map: map,
      player: player,
      monsters: [goblin],
    );
    game.playerAct(const MoveAction(Direction.e));
    expect(player.skills.xp(Skill.sword), MonsterTypes.goblin.xp);
  });

  testWidgets('숙련도 화면에서 훈련을 켜고 끈다', (tester) async {
    final controller = GameController(seed: 1, job: Job.fighter);
    await tester.pumpWidget(
      MaterialApp(home: GameScreen(controller: controller)),
    );
    await tester.tap(find.byTooltip('적성'));
    await tester.pump();
    await tester.tap(find.byTooltip('숙련도'));
    await tester.pumpAndSettle();
    expect(find.byType(SkillsScreen), findsOneWidget);
    expect(find.text('얻은 경험치가 훈련 중인 숙련도 4개에 똑같이 나뉘어 쌓입니다.'), findsOneWidget);

    final skills = controller.game.player.skills;
    expect(skills.isTraining(Skill.bow), isFalse);
    await tester.scrollUntilVisible(find.text('활'), 100);
    await tester.tap(find.text('활'));
    await tester.pump();
    expect(skills.isTraining(Skill.bow), isTrue);
    expect(skills.training.length, 5); // 헤더는 스크롤로 화면 밖

    await tester.tap(find.text('활'));
    await tester.pump();
    expect(skills.isTraining(Skill.bow), isFalse);
  });
}
