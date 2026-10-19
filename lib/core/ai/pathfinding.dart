import 'dart:math' as math;

import 'package:collection/collection.dart';

import '../geometry.dart';

class _Node {
  _Node(this.pos, this.g, this.f);

  final Pos pos;
  final int g;
  final int f;
}

// 경로 비용은 우선순위가 다른 세 값을 한 정수에 담는다.
// 1순위: 이동 칸 수 (게임상 실제 소요 턴) — 항상 최소.
// 2순위: 대각선 이동 수 — 칸 수가 같으면 위아래로 꺾이는 지그재그를 배제.
// 3순위: 시작점→목표 직선에서 벗어난 정도 — 계단 모양을 직선에 가깝게.
const _stepCost = 1 << 30;
const _diagonalCost = 1 << 18;
const _deviationScale = 16;

/// 8방향 A* 경로탐색.
///
/// 이동 칸 수가 최소인 경로 중에서 대각선이 가장 적고
/// 직선에 가장 가까운 경로를 고른다.
///
/// [canEnter]가 false인 칸은 지나갈 수 없다. 단 [goal] 자체는 항상 허용한다
/// (예: 플레이어가 서 있는 칸을 목표로 추적).
/// 반환값은 시작점을 제외하고 목표를 포함한 경로. 도달 불가하면 null.
List<Pos>? findPath(
  Pos start,
  Pos goal,
  bool Function(Pos) canEnter, {
  int maxNodes = 4000,
}) {
  if (start == goal) return const [];

  final line = goal - start;
  final lineLength = math.sqrt(line.x * line.x + line.y * line.y);

  // 직선으로부터의 수직 거리.
  int deviation(Pos p) {
    final d = p - start;
    final cross = (d.x * line.y - d.y * line.x).abs();
    return (cross * _deviationScale / lineLength).round();
  }

  // 남은 칸 수와 최소 대각선 수만 더하므로 실제 비용을 넘지 않는다.
  int heuristic(Pos p) {
    final dx = (goal.x - p.x).abs();
    final dy = (goal.y - p.y).abs();
    return math.max(dx, dy) * _stepCost + math.min(dx, dy) * _diagonalCost;
  }

  final open = PriorityQueue<_Node>((a, b) => a.f.compareTo(b.f));
  final cameFrom = <Pos, Pos>{};
  final gScore = <Pos, int>{start: 0};
  open.add(_Node(start, 0, heuristic(start)));

  var expanded = 0;
  while (open.isNotEmpty) {
    final current = open.removeFirst();
    if (current.g > gScore[current.pos]!) continue; // 오래된 항목
    if (current.pos == goal) return _reconstruct(cameFrom, goal);
    if (++expanded > maxNodes) break;

    for (final d in Direction.all) {
      final next = current.pos + d;
      if (next != goal && !canEnter(next)) continue;
      final isDiagonal = d.x != 0 && d.y != 0;
      final g =
          current.g +
          _stepCost +
          (isDiagonal ? _diagonalCost : 0) +
          deviation(next);
      final known = gScore[next];
      if (known != null && g >= known) continue;
      gScore[next] = g;
      cameFrom[next] = current.pos;
      open.add(_Node(next, g, g + heuristic(next)));
    }
  }
  return null;
}

List<Pos> _reconstruct(Map<Pos, Pos> cameFrom, Pos goal) {
  final path = <Pos>[goal];
  var current = goal;
  while (cameFrom.containsKey(current)) {
    current = cameFrom[current]!;
    path.add(current);
  }
  path.removeLast(); // 시작점 제외
  return path.reversed.toList();
}
