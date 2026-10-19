import 'dart:math' as math;
import 'dart:ui';

import '../core/entity/monster_type.dart';
import '../core/geometry.dart';
import '../core/world/tile.dart';

/// 타일 그래픽 출력 인터페이스.
/// 나중에 스프라이트 시트 기반 구현으로 교체하면 나머지 코드는 그대로 쓸 수 있다.
abstract class TileRenderer {
  void drawTile(Canvas canvas, Rect rect, TileType type, Pos pos);
  void drawPlayer(Canvas canvas, Rect rect);
  void drawMonster(Canvas canvas, Rect rect, MonsterType type);
}

/// 코드로 그린 임시 타일 그래픽.
class ProceduralTileRenderer implements TileRenderer {
  const ProceduralTileRenderer();

  static Paint _fill(Color color) => Paint()..color = color;

  static Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;

  /// 위치 기반 고정 난수 (0..1).
  static double _noise(int x, int y, int salt) {
    var h = (x * 374761393 + y * 668265263 + salt * 1274126177) & 0x7fffffff;
    h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff;
    return ((h ^ (h >> 16)) & 0xffff) / 0xffff;
  }

  @override
  void drawTile(Canvas canvas, Rect rect, TileType type, Pos pos) {
    switch (type) {
      case TileType.wall:
        _wall(canvas, rect, pos);
      case TileType.floor:
        _floor(canvas, rect, pos);
      case TileType.doorClosed:
        _floor(canvas, rect, pos);
        _doorClosed(canvas, rect);
      case TileType.doorOpen:
        _floor(canvas, rect, pos);
        _doorOpen(canvas, rect);
    }
  }

  void _floor(Canvas c, Rect r, Pos pos) {
    final shade = (_noise(pos.x, pos.y, 0) * 10).round();
    c.drawRect(
      r,
      _fill(Color.fromARGB(255, 50 + shade, 46 + shade, 41 + shade)),
    );
    c.drawRect(
      r.deflate(r.width * 0.03),
      _stroke(const Color(0xFF26221E), math.max(1, r.width * 0.04)),
    );
    final speck = _fill(const Color(0xFF433D36));
    for (var i = 1; i <= 3; i++) {
      final dx = _noise(pos.x, pos.y, i * 2);
      final dy = _noise(pos.x, pos.y, i * 2 + 1);
      c.drawCircle(
        Offset(
          r.left + r.width * (0.15 + 0.7 * dx),
          r.top + r.height * (0.15 + 0.7 * dy),
        ),
        r.width * 0.035,
        speck,
      );
    }
  }

  void _wall(Canvas c, Rect r, Pos pos) {
    c.drawRect(r, _fill(const Color(0xFF6B5846)));
    final mortar = _stroke(
      const Color(0xFF3B3027),
      math.max(1, r.width * 0.05),
    );
    final highlight = _stroke(
      const Color(0x22FFFFFF),
      math.max(1, r.width * 0.03),
    );
    const rows = 4;
    final bh = r.height / rows;
    for (var i = 0; i < rows; i++) {
      final y = r.top + bh * i;
      c.drawLine(
        Offset(r.left, y + bh * 0.15),
        Offset(r.right, y + bh * 0.15),
        highlight,
      );
      c.drawLine(Offset(r.left, y), Offset(r.right, y), mortar);
      // 벽돌 엇갈림
      final joints = i.isEven ? const [0.0, 0.5] : const [0.25, 0.75];
      for (final jx in joints) {
        final x = r.left + r.width * jx;
        c.drawLine(Offset(x, y), Offset(x, y + bh), mortar);
      }
    }
  }

  void _doorClosed(Canvas c, Rect r) {
    final door = r.deflate(r.width * 0.08);
    c.drawRect(door, _fill(const Color(0xFF7A4B24)));
    final plank = _stroke(const Color(0xFF5A3518), math.max(1, r.width * 0.03));
    for (var i = 1; i < 4; i++) {
      final x = door.left + door.width * i / 4;
      c.drawLine(Offset(x, door.top), Offset(x, door.bottom), plank);
    }
    c.drawRect(door, _stroke(const Color(0xFF3E2410), r.width * 0.06));
    c.drawCircle(
      Offset(door.right - door.width * 0.18, door.center.dy),
      r.width * 0.05,
      _fill(const Color(0xFFD8B04A)),
    );
  }

  void _doorOpen(Canvas c, Rect r) {
    final door = Rect.fromLTWH(
      r.left,
      r.top + r.height * 0.05,
      r.width * 0.14,
      r.height * 0.9,
    );
    c.drawRect(door, _fill(const Color(0xFF7A4B24)));
    c.drawRect(door, _stroke(const Color(0xFF3E2410), r.width * 0.04));
  }

  void _shadow(Canvas c, Rect r) {
    c.drawOval(
      Rect.fromCenter(
        center: Offset(r.center.dx, r.top + r.height * 0.88),
        width: r.width * 0.55,
        height: r.height * 0.13,
      ),
      _fill(const Color(0x66000000)),
    );
  }

  @override
  void drawPlayer(Canvas c, Rect r) {
    final w = r.width;
    final h = r.height;
    final cx = r.center.dx;
    _shadow(c, r);
    // 검
    c.drawLine(
      Offset(cx + w * 0.27, r.top + h * 0.72),
      Offset(cx + w * 0.38, r.top + h * 0.22),
      _stroke(const Color(0xFFD7DDE6), w * 0.05),
    );
    c.drawLine(
      Offset(cx + w * 0.2, r.top + h * 0.68),
      Offset(cx + w * 0.34, r.top + h * 0.72),
      _stroke(const Color(0xFF8A6A30), w * 0.05),
    );
    // 몸통 (망토)
    final body = Path()
      ..moveTo(cx - w * 0.24, r.top + h * 0.86)
      ..lineTo(cx + w * 0.24, r.top + h * 0.86)
      ..lineTo(cx + w * 0.15, r.top + h * 0.46)
      ..lineTo(cx - w * 0.15, r.top + h * 0.46)
      ..close();
    c.drawPath(body, _fill(const Color(0xFF3D6FD8)));
    c.drawLine(
      Offset(cx - w * 0.17, r.top + h * 0.62),
      Offset(cx + w * 0.17, r.top + h * 0.62),
      _stroke(const Color(0xFF7A5A2A), w * 0.05),
    );
    // 머리
    c.drawCircle(
      Offset(cx, r.top + h * 0.33),
      w * 0.13,
      _fill(const Color(0xFFE8C39E)),
    );
    // 머리카락
    c.drawArc(
      Rect.fromCircle(center: Offset(cx, r.top + h * 0.33), radius: w * 0.135),
      math.pi,
      math.pi,
      true,
      _fill(const Color(0xFF5A3A1E)),
    );
  }

  @override
  void drawMonster(Canvas c, Rect r, MonsterType type) {
    switch (type.id) {
      case 'goblin':
        _goblin(c, r);
      default:
        _shadow(c, r);
        c.drawCircle(r.center, r.width * 0.3, _fill(const Color(0xFFB04040)));
    }
  }

  void _goblin(Canvas c, Rect r) {
    final w = r.width;
    final h = r.height;
    final cx = r.center.dx;
    const skin = Color(0xFF6FA03C);
    _shadow(c, r);
    // 몽둥이
    c.drawLine(
      Offset(cx - w * 0.3, r.top + h * 0.75),
      Offset(cx - w * 0.36, r.top + h * 0.38),
      _stroke(const Color(0xFF6B4423), w * 0.08),
    );
    // 몸통 (누더기 옷)
    final body = Path()
      ..moveTo(cx - w * 0.2, r.top + h * 0.86)
      ..lineTo(cx + w * 0.2, r.top + h * 0.86)
      ..lineTo(cx + w * 0.13, r.top + h * 0.52)
      ..lineTo(cx - w * 0.13, r.top + h * 0.52)
      ..close();
    c.drawPath(body, _fill(const Color(0xFF7A6440)));
    // 귀
    final ears = Path()
      ..moveTo(cx - w * 0.12, r.top + h * 0.38)
      ..lineTo(cx - w * 0.32, r.top + h * 0.28)
      ..lineTo(cx - w * 0.1, r.top + h * 0.46)
      ..close()
      ..moveTo(cx + w * 0.12, r.top + h * 0.38)
      ..lineTo(cx + w * 0.32, r.top + h * 0.28)
      ..lineTo(cx + w * 0.1, r.top + h * 0.46)
      ..close();
    c.drawPath(ears, _fill(skin));
    // 머리
    c.drawCircle(Offset(cx, r.top + h * 0.4), w * 0.15, _fill(skin));
    // 눈
    final eye = _fill(const Color(0xFFFF4A3A));
    c.drawCircle(Offset(cx - w * 0.055, r.top + h * 0.39), w * 0.03, eye);
    c.drawCircle(Offset(cx + w * 0.055, r.top + h * 0.39), w * 0.03, eye);
  }
}
