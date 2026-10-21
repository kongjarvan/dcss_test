import 'package:dc_test/core/entity/actor.dart';
import 'package:dc_test/core/geometry.dart';
import 'package:dc_test/core/items/item.dart';
import 'package:dc_test/core/progression/job.dart';
import 'package:dc_test/core/progression/skills.dart';
import 'package:dc_test/render/map_painter.dart';
import 'package:dc_test/ui/game_controller.dart';
import 'package:dc_test/ui/game_screen.dart';
import 'package:dc_test/ui/inventory_screen.dart';
import 'package:dc_test/ui/side_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<GameController> pumpGame(WidgetTester tester) async {
  final controller = GameController(seed: 1, job: Job.fighter);
  controller.game.monsters.clear();
  controller.game.updateFov();
  await tester.pumpWidget(
    MaterialApp(home: GameScreen(controller: controller)),
  );
  return controller;
}

Finder inPanel(Finder f) =>
    find.descendant(of: find.byType(SidePanel), matching: f);

void main() {
  group('옆 패널', () {
    testWidgets('기본은 소지품 아이콘 칸, 아이템을 누르면 상세 창', (tester) async {
      await pumpGame(tester);
      expect(inPanel(find.byTooltip('숏소드')), findsOneWidget);
      expect(inPanel(find.byTooltip('가죽 갑옷')), findsOneWidget);

      await tester.tap(inPanel(find.byTooltip('숏소드')));
      await tester.pumpAndSettle();
      expect(find.byTooltip('해제'), findsOneWidget); // 장착 중 → 해제 버튼
    });

    testWidgets('숙련도 목록으로 전환하고, 누르면 훈련을 켜고 끈다', (tester) async {
      final controller = await pumpGame(tester);
      await tester.tap(find.byTooltip('숙련도 목록'));
      await tester.pump();
      expect(inPanel(find.text('검')), findsOneWidget);
      expect(inPanel(find.byTooltip('숏소드')), findsNothing);

      final skills = controller.game.player.skills;
      expect(skills.isTraining(Skill.axe), isFalse);
      await tester.tap(inPanel(find.text('도끼')));
      await tester.pump();
      expect(skills.isTraining(Skill.axe), isTrue);

      await tester.tap(find.byTooltip('소지품 목록'));
      await tester.pump();
      expect(inPanel(find.byTooltip('숏소드')), findsOneWidget);
    });
  });

  group('소지품 아이콘 칸 (DCSS식)', () {
    testWidgets('이름 글자 없이 아이콘만, 개수·장착 표시, 빈 칸 포함 30칸', (tester) async {
      final controller = await pumpGame(tester);
      final game = controller.game;
      game.player.addItem(Item(PotionType.of(Potion.curing), quantity: 3));
      controller.waitTurn();
      await tester.pump();

      final grid = find.byType(InventoryGrid);
      // 아이템 이름은 글자로 보이지 않는다 (툴팁으로만).
      expect(
        find.descendant(of: grid, matching: find.text('숏소드')),
        findsNothing,
      );
      expect(
        find.descendant(of: grid, matching: find.text('3')),
        findsOneWidget,
      );

      // 칸은 소지품 한도만큼, 아이템 4개(숏소드·가죽 갑옷·버클러·물약) + 빈 칸 26개.
      final cells = tester.widget<GridView>(
        find.descendant(of: grid, matching: find.byType(GridView)),
      );
      expect(
        (cells.childrenDelegate as SliverChildBuilderDelegate).childCount,
        Player.inventoryCapacity,
      );

      // 장착 중인 장비는 노란 테두리.
      Material cellOf(String name) => tester.widget<Material>(
        find
            .descendant(
              of: inPanel(find.byTooltip(name)),
              matching: find.byType(Material),
            )
            .first,
      );
      final equippedBorder =
          (cellOf('숏소드').shape as RoundedRectangleBorder).side.color;
      final potionName = game.nameOf(game.player.inventory.last);
      final plainBorder =
          (cellOf(potionName).shape as RoundedRectangleBorder).side.color;
      expect(equippedBorder, const Color(0xFFFFD54F));
      expect(plainBorder, isNot(equippedBorder));
      await tester.pump(const Duration(seconds: 5)); // 토스트 정리
    });
  });

  group('발밑 아이템 (레벨·층 줄 오른쪽)', () {
    testWidgets('서 있는 칸의 아이템을 아이콘으로 보여주고, 누르면 상세·줍기', (tester) async {
      final controller = await pumpGame(tester);
      final game = controller.game;
      final strip = find.byType(FloorItemStrip);
      expect(find.text('Lv 1 · 1층'), findsOneWidget);
      expect(
        find.descendant(of: strip, matching: find.byType(Tooltip)),
        findsNothing,
      );

      final mace = Item(ItemTypes.mace);
      final club = Item(ItemTypes.club);
      game.addFloorItem(game.player.pos, mace);
      game.addFloorItem(game.player.pos, club);
      controller.waitTurn();
      await tester.pump();
      Finder inStrip(String name) =>
          find.descendant(of: strip, matching: find.byTooltip(name));
      expect(inStrip('철퇴'), findsOneWidget);
      expect(inStrip('몽둥이'), findsOneWidget);

      await tester.tap(inStrip('철퇴'));
      await tester.pumpAndSettle();
      expect(find.text('바닥 · 줍는 데 1턴'), findsOneWidget);
      await tester.tap(find.byTooltip('줍기').last);
      await tester.pumpAndSettle();

      // 철퇴만 주웠고 창은 닫혔다.
      expect(game.player.inventory, contains(mace));
      expect(game.itemsAt(game.player.pos), [club]);
      expect(find.text('바닥 · 줍는 데 1턴'), findsNothing);
      expect(inStrip('철퇴'), findsNothing);
      expect(inStrip('몽둥이'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5)); // 토스트 정리
    });
  });

  group('맵 길게 누르기', () {
    Offset tileCenter(WidgetTester tester, GameController c, Pos tile) {
      final mapFinder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is MapPainter,
      );
      final painter =
          tester.widget<CustomPaint>(mapFinder).painter! as MapPainter;
      final box = tester.getRect(mapFinder);
      final origin = MapPainter.cameraOrigin(
        box.size,
        c.game.player.pos,
        painter.tileSize,
      );
      return box.topLeft +
          Offset(
            (tile.x + 0.5 - origin.dx) * painter.tileSize,
            (tile.y + 0.5 - origin.dy) * painter.tileSize,
          );
    }

    testWidgets('아이템이 있는 칸은 아이템 목록 팝업, 바깥을 누르면 닫힘', (tester) async {
      final controller = await pumpGame(tester);
      final game = controller.game;
      final tile = game.player.pos + const Pos(1, 0);
      game.addFloorItem(tile, Item(ItemTypes.mace));
      game.addFloorItem(tile, Item(ItemTypes.buckler));
      controller.waitTurn();
      await tester.pump();

      await tester.longPressAt(tileCenter(tester, controller, tile));
      await tester.pumpAndSettle();
      expect(find.text('철퇴'), findsOneWidget);
      expect(find.text('버클러'), findsOneWidget);
      expect(game.player.pos, isNot(tile)); // 길게 누르기는 이동하지 않음

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('철퇴'), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('빈 칸은 "아무것도 없다", 본 적 없는 칸은 팝업 없음', (tester) async {
      final controller = await pumpGame(tester);
      final game = controller.game;
      await tester.longPressAt(tileCenter(tester, controller, game.player.pos));
      await tester.pumpAndSettle();
      expect(find.text('아무것도 없다.'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      // 시야 밖 미탐험 칸
      Pos? unknown;
      for (var d = 1; d <= 6 && unknown == null; d++) {
        for (final dir in Direction.all) {
          final p = game.player.pos + Pos(dir.x * d, dir.y * d);
          if (game.map.contains(p) && !game.map.isExplored(p)) {
            unknown = p;
            break;
          }
        }
      }
      if (unknown != null) {
        await tester.longPressAt(tileCenter(tester, controller, unknown));
        await tester.pumpAndSettle();
        expect(find.text('아무것도 없다.'), findsNothing);
      }
    });
  });

  group('토스트', () {
    testWidgets('새 메시지가 맵 위에 떴다가 3초 뒤 사라진다', (tester) async {
      final controller = await pumpGame(tester);
      const intro = '던전 1층에 들어섰다. 화면을 탭해 이동하세요.';
      expect(find.text(intro), findsNothing); // 시작 메시지는 토스트로 안 띄움

      controller.game.message('테스트 알림');
      controller.waitTurn();
      await tester.pump();
      expect(find.text('테스트 알림'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(find.text('테스트 알림'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('테스트 알림'), findsNothing);
    });

    testWidgets('최대 3개까지만 보인다', (tester) async {
      final controller = await pumpGame(tester);
      for (var i = 1; i <= 5; i++) {
        controller.game.message('알림 $i');
      }
      controller.waitTurn();
      await tester.pump();
      expect(find.text('알림 1'), findsNothing);
      expect(find.text('알림 2'), findsNothing);
      expect(find.text('알림 5'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('메시지 로그를 열고 돌아오면 토스트가 지워진다', (tester) async {
      final controller = await pumpGame(tester);
      controller.game.message('테스트 알림');
      controller.waitTurn();
      await tester.pump();
      expect(find.text('테스트 알림'), findsOneWidget);

      await tester.tap(find.byTooltip('메시지 로그'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('테스트 알림'), findsNothing);
    });
  });
}
