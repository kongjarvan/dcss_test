import 'package:dc_test/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('게임 화면이 뜨고 대기 버튼으로 시간이 흐른다', (tester) async {
    await tester.pumpWidget(const DungeonApp(seed: 42));
    expect(find.textContaining('HP 30/30'), findsOneWidget);
    expect(find.text('시간 0.0'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '대기'));
    await tester.pump();
    expect(find.text('시간 1.0'), findsOneWidget);
  });

  testWidgets('카테고리 탭을 바꾸면 해당 행동 버튼이 보인다', (tester) async {
    await tester.pumpWidget(const DungeonApp(seed: 42));
    expect(find.text('휴식'), findsOneWidget);

    await tester.tap(find.text('전투'));
    await tester.pump();
    expect(find.text('자동 전투'), findsOneWidget);
    expect(find.text('휴식'), findsNothing);

    await tester.tap(find.text('아이템'));
    await tester.pump();
    expect(find.text('줍기'), findsOneWidget);
    final pickUp = tester.widget<FilledButton>(
      find.ancestor(of: find.text('줍기'), matching: find.byType(FilledButton)),
    );
    expect(pickUp.onPressed, isNull);

    await tester.tap(find.text('적성').first);
    await tester.pump();
    expect(find.text('주문'), findsOneWidget);
  });
}
