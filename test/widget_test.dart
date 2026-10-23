import 'package:dc_test/core/progression/species.dart';
import 'package:dc_test/core/entity/actor.dart';
import 'package:dc_test/core/entity/monster_type.dart';
import 'package:dc_test/core/geometry.dart';
import 'package:dc_test/core/progression/job.dart';
import 'package:dc_test/main.dart';
import 'package:dc_test/ui/action_bar.dart';
import 'package:dc_test/ui/game_controller.dart';
import 'package:dc_test/ui/game_screen.dart';
import 'package:dc_test/core/game.dart';
import 'package:dc_test/render/map_painter.dart';
import 'package:dc_test/ui/message_log_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FilledButton buttonByTooltip(WidgetTester tester, String tooltip) =>
    tester.widget<FilledButton>(
      find.descendant(
        of: find.byTooltip(tooltip),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );

/// 화면 안 ListenableBuilder가 듣고 있는 컨트롤러에서 게임을 꺼낸다.
Game gameOf(WidgetTester tester) => tester
    .widgetList<ListenableBuilder>(find.byType(ListenableBuilder))
    .map((b) => b.listenable)
    .whereType<GameController>()
    .first
    .game;

void main() {
  testWidgets('게임 화면이 뜨고, 자기 자신을 탭하면 1턴 대기', (tester) async {
    final controller = GameController(seed: 42);
    await tester.pumpWidget(
      MaterialApp(home: GameScreen(controller: controller)),
    );
    expect(find.textContaining('HP 30/30'), findsOneWidget);
    expect(controller.game.time, 0);

    // 카메라가 플레이어를 맵 가운데에 둔다.
    final map = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is MapPainter,
    );
    await tester.tapAt(tester.getCenter(map));
    await tester.pump();
    expect(controller.game.time, 10);
  });

  testWidgets('상태바에는 레벨과 층만 한 줄로 (시간·처치 수 없음)', (tester) async {
    await tester.pumpWidget(const DungeonApp(seed: 42, species: Species.human));
    expect(find.text('Lv 1 · 1층'), findsOneWidget);
    expect(find.textContaining('시간 '), findsNothing);
    expect(find.textContaining('처치 '), findsNothing);
    expect(find.textContaining('직전 행동'), findsNothing);
  });

  testWidgets('하단 버튼은 카테고리 없이 자동 탐험·공격·휴식·계단 4개, 아이콘만', (tester) async {
    final controller = GameController(seed: 42);
    controller.game.monsters.clear();
    controller.game.updateFov();
    await tester.pumpWidget(
      MaterialApp(home: GameScreen(controller: controller)),
    );
    final bar = find.byType(ActionBar);
    final buttons = find.descendant(
      of: bar,
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
    expect(buttons, findsNWidgets(4));
    expect(find.descendant(of: bar, matching: find.byType(Text)), findsNothing);
    for (final tip in ['자동 탐험', '공격 · 대상 없음', '휴식 (HP·MP 완전 회복) · 회복 완료']) {
      expect(
        find.descendant(of: bar, matching: find.byTooltip(tip)),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(
        of: bar,
        matching: find.byTooltip('내려가는 계단으로 이동 · 계단 모름'),
      ),
      controller.knownStairs == null ? findsOneWidget : findsNothing,
    );
    // 예전 카테고리 탭은 없다.
    for (final tab in ['이동', '전투', '아이템', '적성']) {
      expect(find.byTooltip(tab), findsNothing);
    }
    // 보이는 적이 없으면 공격 버튼은 비활성.
    expect(buttonByTooltip(tester, '공격 · 대상 없음').onPressed, isNull);
  });

  testWidgets('핀치로 확대되고, 탭 이동도 그대로 동작한다', (tester) async {
    await tester.pumpWidget(const DungeonApp(seed: 42, species: Species.human));
    MapPainter painter() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<MapPainter>()
        .single;
    final mapFinder = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is MapPainter,
    );
    final before = painter().tileSize;
    final center = tester.getCenter(mapFinder);

    // 두 손가락을 벌린다.
    final g1 = await tester.startGesture(center - const Offset(20, 0));
    final g2 = await tester.startGesture(center + const Offset(20, 0));
    await tester.pump();
    await g1.moveBy(const Offset(-60, 0));
    await g2.moveBy(const Offset(60, 0));
    await tester.pump();
    await g1.up();
    await g2.up();
    await tester.pump();
    final zoomed = painter().tileSize;
    expect(zoomed, greaterThan(before * 1.5));

    // 플레이어 오른쪽 칸 탭 → 이동(또는 문 열기)으로 시간이 흐른다.
    final hpLabel = find.textContaining('HP ');
    expect(hpLabel, findsOneWidget);
    final state = tester.state(find.byType(GameScreen));
    await tester.tapAt(center + Offset(zoomed, 0));
    await tester.pump();
    expect(tester.state(find.byType(GameScreen)), same(state));
    expect(gameOf(tester).time, greaterThan(0));
  });

  testWidgets('HP·MP가 가득하면 휴식 버튼 비활성', (tester) async {
    await tester.pumpWidget(const DungeonApp(seed: 42, species: Species.human));
    expect(
      buttonByTooltip(tester, '휴식 (HP·MP 완전 회복) · 회복 완료').onPressed,
      isNull,
    );
  });

  testWidgets('메시지는 게임 화면에 바로 보이지 않고 로그 버튼으로 연다', (tester) async {
    await tester.pumpWidget(const DungeonApp(seed: 42, species: Species.human));
    const intro = '던전 1층에 들어섰다. 화면을 탭해 이동하세요.';
    expect(find.text(intro), findsNothing);

    await tester.tap(find.byTooltip('메시지 로그'));
    await tester.pumpAndSettle();
    expect(find.byType(MessageLogScreen), findsOneWidget);
    expect(find.text(intro), findsOneWidget);
    expect(find.text('0.0'), findsWidgets); // 메시지가 나온 시간

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(MessageLogScreen), findsNothing);
  });

  testWidgets('공격 버튼: 보이는 적이 있으면 활성, 활을 들었으면 쏜다', (tester) async {
    final controller = GameController(seed: 42, job: Job.hunter);
    final game = controller.game;
    game.monsters.clear();
    final spot = Direction.all
        .map((d) => game.player.pos + d + d)
        .firstWhere(
          (p) =>
              game.map.contains(p) &&
              game.map[p].passable &&
              game.hasLineOfFire(game.player.pos, p),
        );
    final target = Monster(MonsterTypes.goblin, pos: spot)..hp = 100;
    game.monsters.add(target);
    game.updateFov();
    await tester.pumpWidget(
      MaterialApp(home: GameScreen(controller: controller)),
    );

    expect(buttonByTooltip(tester, '공격').onPressed, isNotNull);
    await tester.tap(find.byTooltip('공격'));
    await tester.pump();
    // 활로 쐈다 (명중이든 빗나감이든 화살 메시지).
    expect(
      game.log.recent(5).map((m) => m.text).any((t) => t.startsWith('화살이')),
      isTrue,
    );
    expect(game.player.pos, isNot(spot)); // 다가가지 않음
    await tester.pump(const Duration(seconds: 5));
  });
}
