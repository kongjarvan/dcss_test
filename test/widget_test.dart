import 'package:dc_test/core/progression/species.dart';
import 'package:dc_test/main.dart';
import 'package:dc_test/render/map_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FilledButton buttonByTooltip(WidgetTester tester, String tooltip) =>
    tester.widget<FilledButton>(
      find.descendant(
        of: find.byTooltip(tooltip),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );

void main() {
  testWidgets('게임 화면이 뜨고 대기 버튼으로 시간이 흐른다', (tester) async {
    await tester.pumpWidget(const DungeonApp(seed: 42, species: Species.human));
    expect(find.textContaining('HP 30/30'), findsOneWidget);
    expect(find.text('시간 0.0'), findsOneWidget);

    await tester.tap(find.byTooltip('1턴 대기'));
    await tester.pump();
    expect(find.text('시간 1.0'), findsOneWidget);
  });

  testWidgets('카테고리 탭을 바꾸면 해당 행동 버튼이 보인다', (tester) async {
    await tester.pumpWidget(const DungeonApp(seed: 42, species: Species.human));
    expect(find.byTooltip('자동 탐험'), findsOneWidget);

    await tester.tap(find.byTooltip('전투'));
    await tester.pump();
    expect(find.byTooltip('자동 전투'), findsOneWidget);
    expect(find.byTooltip('자동 탐험'), findsNothing);

    await tester.tap(find.byTooltip('아이템'));
    await tester.pump();
    expect(buttonByTooltip(tester, '줍기 · 준비 중').onPressed, isNull);

    await tester.tap(find.byTooltip('적성'));
    await tester.pump();
    expect(find.byTooltip('주문 · 준비 중'), findsOneWidget);
  });

  testWidgets('버튼에는 글자 없이 아이콘만 있다', (tester) async {
    await tester.pumpWidget(const DungeonApp(seed: 42, species: Species.human));
    for (final category in ['이동', '전투', '아이템', '적성']) {
      await tester.tap(find.byTooltip(category));
      await tester.pump();
      final buttons = find.byWidgetPredicate((w) => w is ButtonStyleButton);
      expect(
        find.descendant(of: buttons, matching: find.byType(Text)),
        findsNothing,
        reason: category,
      );
    }
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
    await tester.tapAt(center + Offset(zoomed, 0));
    await tester.pump();
    expect(find.text('시간 0.0'), findsNothing);
  });

  testWidgets('HP·MP가 가득하면 휴식 버튼 비활성', (tester) async {
    await tester.pumpWidget(const DungeonApp(seed: 42, species: Species.human));
    expect(
      buttonByTooltip(tester, '휴식 (HP·MP 완전 회복) · 회복 완료').onPressed,
      isNull,
    );
  });
}
