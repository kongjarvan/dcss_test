import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../core/game.dart';
import '../core/geometry.dart';
import 'tile_renderer.dart';

/// 플레이어를 중심으로 던전을 그린다.
class MapPainter extends CustomPainter {
  MapPainter({
    required this.game,
    required this.tileSize,
    required this.renderer,
    this.travelTarget,
  });

  final Game game;
  final double tileSize;
  final TileRenderer renderer;
  final Pos? travelTarget;

  /// 화면 좌상단에 해당하는 타일 좌표 (실수).
  static Offset cameraOrigin(Size size, Pos center, double tileSize) => Offset(
    center.x + 0.5 - size.width / (2 * tileSize),
    center.y + 0.5 - size.height / (2 * tileSize),
  );

  /// 화면 좌표 → 타일 좌표.
  static Pos tileAt(Offset local, Size size, Pos center, double tileSize) {
    final origin = cameraOrigin(size, center, tileSize);
    return Pos(
      (origin.dx + local.dx / tileSize).floor(),
      (origin.dy + local.dy / tileSize).floor(),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF000000),
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final map = game.map;
    final origin = cameraOrigin(size, game.player.pos, tileSize);
    // 타일 크기가 소수여도 이웃 타일과 틈/겹침이 없도록 경계를 반올림.
    double sx(num x) => ((x - origin.dx) * tileSize).roundToDouble();
    double sy(num y) => ((y - origin.dy) * tileSize).roundToDouble();
    Rect rectOf(Pos p) =>
        Rect.fromLTRB(sx(p.x), sy(p.y), sx(p.x + 1), sy(p.y + 1));

    final fog = Paint()..color = const Color(0x99000000);
    final x0 = origin.dx.floor();
    final y0 = origin.dy.floor();
    final x1 = (origin.dx + size.width / tileSize).ceil();
    final y1 = (origin.dy + size.height / tileSize).ceil();

    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final p = Pos(x, y);
        if (!map.isExplored(p)) continue;
        final rect = rectOf(p);
        renderer.drawTile(canvas, rect, map[p], p);
        // 바닥 아이템은 본 적 있는 칸이면 기억해서 그린다 (맨 위 하나만).
        final items = game.itemsAt(p);
        if (items.isNotEmpty) renderer.drawItem(canvas, rect, items.last.type);
        if (!map.isVisible(p)) canvas.drawRect(rect, fog);
      }
    }

    final target = travelTarget;
    if (target != null) {
      canvas.drawRect(
        rectOf(target).deflate(2),
        Paint()
          ..color = const Color(0xCCFFD54F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    final screen = Offset.zero & size;
    final offscreen = <Offset>[];
    for (final m in game.visibleMonsters) {
      final rect = rectOf(m.pos);
      if (!screen.contains(rect.center)) offscreen.add(rect.center);
      renderer.drawMonster(canvas, rect, m.type);
      if (m.hp < m.maxHp) _drawHpBar(canvas, rect, m.hp / m.maxHp);
    }

    if (game.player.isAlive) {
      final player = game.player;
      renderer.drawPlayer(
        canvas,
        rectOf(player.pos),
        player.species,
        weapon: player.weaponType,
        shield: player.shieldType,
      );
    }

    for (final point in offscreen) {
      _drawOffscreenArrow(canvas, size, point);
    }
    canvas.restore();
  }

  /// 화면 밖 [point]를 향하는 화살표를 놓을 화면 가장자리 위치.
  /// [point]가 화면 안이면 null.
  static Offset? edgeIndicatorPosition(
    Size size,
    Offset point, {
    double margin = 16,
  }) {
    if ((Offset.zero & size).contains(point)) return null;
    final center = size.center(Offset.zero);
    final v = point - center;
    final sx = v.dx == 0
        ? double.infinity
        : (size.width / 2 - margin) / v.dx.abs();
    final sy = v.dy == 0
        ? double.infinity
        : (size.height / 2 - margin) / v.dy.abs();
    return center + v * math.min(sx, sy);
  }

  void _drawOffscreenArrow(Canvas canvas, Size size, Offset point) {
    final pos = edgeIndicatorPosition(size, point);
    if (pos == null) return;
    final dir = (point - size.center(Offset.zero));
    final unit = dir / dir.distance;
    final normal = Offset(-unit.dy, unit.dx);
    const length = 12.0;
    const halfWidth = 8.0;
    final tip = pos + unit * length;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((pos + normal * halfWidth).dx, (pos + normal * halfWidth).dy)
      ..lineTo((pos - normal * halfWidth).dx, (pos - normal * halfWidth).dy)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFE53935));
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF2A0A0A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawHpBar(Canvas canvas, Rect rect, double ratio) {
    final bar = Rect.fromLTWH(
      rect.left + rect.width * 0.1,
      rect.bottom - rect.height * 0.08,
      rect.width * 0.8,
      rect.height * 0.06,
    );
    canvas.drawRect(bar, Paint()..color = const Color(0xFF5A1010));
    canvas.drawRect(
      Rect.fromLTWH(
        bar.left,
        bar.top,
        bar.width * ratio.clamp(0, 1),
        bar.height,
      ),
      Paint()..color = const Color(0xFF4CDB4C),
    );
  }

  @override
  bool shouldRepaint(covariant MapPainter oldDelegate) => true;
}
