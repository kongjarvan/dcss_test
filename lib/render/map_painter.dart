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
    Rect rectOf(Pos p) => Rect.fromLTWH(
      ((p.x - origin.dx) * tileSize).roundToDouble(),
      ((p.y - origin.dy) * tileSize).roundToDouble(),
      tileSize,
      tileSize,
    );

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

    for (final m in game.visibleMonsters) {
      final rect = rectOf(m.pos);
      renderer.drawMonster(canvas, rect, m.type);
      if (m.hp < m.maxHp) _drawHpBar(canvas, rect, m.hp / m.maxHp);
    }

    if (game.player.isAlive) {
      renderer.drawPlayer(canvas, rectOf(game.player.pos));
    }
    canvas.restore();
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
