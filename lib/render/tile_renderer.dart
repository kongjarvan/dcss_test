import 'dart:math' as math;
import 'dart:ui';

import '../core/entity/monster_type.dart';
import '../core/geometry.dart';
import '../core/items/item.dart';
import '../core/progression/skills.dart';
import '../core/progression/species.dart';
import '../core/world/tile.dart';

/// 타일 그래픽 출력 인터페이스.
/// 나중에 스프라이트 시트 기반 구현으로 교체하면 나머지 코드는 그대로 쓸 수 있다.
abstract class TileRenderer {
  void drawTile(Canvas canvas, Rect rect, TileType type, Pos pos);
  void drawPlayer(
    Canvas canvas,
    Rect rect,
    Species species, {
    WeaponType? weapon,
    ShieldType? shield,
  });
  void drawMonster(Canvas canvas, Rect rect, MonsterType type);
  void drawItem(Canvas canvas, Rect rect, ItemType type);
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
  void drawPlayer(
    Canvas c,
    Rect r,
    Species species, {
    WeaponType? weapon,
    ShieldType? shield,
  }) {
    final w = r.width;
    final h = r.height;
    final cx = r.center.dx;
    // 종족별 외형: 망토 색, 머리 높이(드워프는 땅딸막), 머리카락 색
    final (cloak, hair, headY) = switch (species) {
      Species.human => (const Color(0xFF3D6FD8), const Color(0xFF5A3A1E), 0.33),
      Species.elf => (const Color(0xFF3E9A5A), const Color(0xFFE8D27A), 0.31),
      Species.dwarf => (const Color(0xFFB0453A), const Color(0xFFB8642A), 0.42),
    };
    final shoulderY = headY + 0.13;
    const skin = Color(0xFFE8C39E);
    final head = Offset(cx, r.top + h * headY);

    _shadow(c, r);
    // 오른손 무기 (맨손이면 없음)
    if (weapon != null) {
      _weapon(
        c,
        Offset(cx + w * 0.24, r.top + h * 0.76),
        Offset(cx + w * 0.38, r.top + h * 0.2),
        w,
        weapon.skill,
      );
    }
    // 몸통 (망토). 드워프는 어깨가 넓다.
    final shoulder = species == Species.dwarf ? 0.2 : 0.15;
    final body = Path()
      ..moveTo(cx - w * 0.24, r.top + h * 0.86)
      ..lineTo(cx + w * 0.24, r.top + h * 0.86)
      ..lineTo(cx + w * shoulder, r.top + h * shoulderY)
      ..lineTo(cx - w * shoulder, r.top + h * shoulderY)
      ..close();
    c.drawPath(body, _fill(cloak));
    c.drawLine(
      Offset(cx - w * 0.18, r.top + h * 0.68),
      Offset(cx + w * 0.18, r.top + h * 0.68),
      _stroke(const Color(0xFF7A5A2A), w * 0.05),
    );
    // 엘프 귀
    if (species == Species.elf) {
      final ears = Path()
        ..moveTo(cx - w * 0.1, head.dy - h * 0.01)
        ..lineTo(cx - w * 0.24, head.dy - h * 0.08)
        ..lineTo(cx - w * 0.11, head.dy + h * 0.05)
        ..close()
        ..moveTo(cx + w * 0.1, head.dy - h * 0.01)
        ..lineTo(cx + w * 0.24, head.dy - h * 0.08)
        ..lineTo(cx + w * 0.11, head.dy + h * 0.05)
        ..close();
      c.drawPath(ears, _fill(skin));
    }
    // 머리
    c.drawCircle(head, w * 0.13, _fill(skin));
    // 머리카락
    c.drawArc(
      Rect.fromCircle(center: head, radius: w * 0.135),
      math.pi,
      math.pi,
      true,
      _fill(hair),
    );
    // 드워프 수염
    if (species == Species.dwarf) {
      final beard = Path()
        ..moveTo(cx - w * 0.13, head.dy + h * 0.06)
        ..lineTo(cx + w * 0.13, head.dy + h * 0.06)
        ..lineTo(cx, head.dy + h * 0.25)
        ..close();
      c.drawPath(beard, _fill(hair));
    }
    // 왼손 방패
    if (shield != null) {
      _shield(
        c,
        Rect.fromCenter(
          center: Offset(cx - w * 0.2, r.top + h * (headY + 0.32)),
          width: w * 0.24,
          height: h * 0.28,
        ),
        shield,
      );
    }
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

  // ── 아이템 ──
  @override
  void drawItem(Canvas c, Rect r, ItemType type) {
    final w = r.width;
    final h = r.height;
    switch (type) {
      case WeaponType():
        // 피해가 큰 무기일수록 길게 그려 같은 계열끼리 구분한다.
        final length = (0.55 + type.damage / 14 * 0.45).clamp(0.55, 1.0);
        final grip = Offset(r.left + w * 0.24, r.top + h * 0.78);
        final full = Offset(r.left + w * 0.76, r.top + h * 0.22);
        _weapon(c, grip, grip + (full - grip) * length, w, type.skill);
      case ArmourType():
        _armour(c, r.deflate(w * 0.18), type);
      case ShieldType():
        final size = switch (type.id) {
          'buckler' => 0.42,
          'kite_shield' => 0.52,
          _ => 0.62,
        };
        _shield(
          c,
          Rect.fromCenter(
            center: r.center,
            width: w * size * 0.85,
            height: h * size,
          ),
          type,
        );
    }
  }

  static const _steel = Color(0xFFD7DDE6);
  static const _wood = Color(0xFF8A6A30);

  /// [grip](손잡이 끝)에서 [tip](끝)까지 무기 하나를 그린다.
  void _weapon(Canvas c, Offset grip, Offset tip, double w, Skill skill) {
    final dir = tip - grip;
    final unit = dir / dir.distance;
    final normal = Offset(-unit.dy, unit.dx);
    Offset at(double t) => grip + dir * t;
    final thin = math.max(1.0, w * 0.05);

    switch (skill) {
      case Skill.sword:
        c.drawLine(grip, at(0.28), _stroke(_wood, thin));
        c.drawLine(
          at(0.28) - normal * w * 0.08,
          at(0.28) + normal * w * 0.08,
          _stroke(const Color(0xFFB08A3A), thin),
        );
        c.drawLine(at(0.3), tip, _stroke(_steel, thin * 1.2));
      case Skill.axe:
        c.drawLine(grip, tip, _stroke(_wood, thin));
        final blade = Path()
          ..moveTo(at(0.72).dx, at(0.72).dy)
          ..lineTo(
            (at(0.62) + normal * w * 0.16).dx,
            (at(0.62) + normal * w * 0.16).dy,
          )
          ..lineTo(
            (at(1.0) + normal * w * 0.16).dx,
            (at(1.0) + normal * w * 0.16).dy,
          )
          ..lineTo(at(0.92).dx, at(0.92).dy)
          ..close();
        c.drawPath(blade, _fill(_steel));
      case Skill.mace:
        c.drawLine(grip, at(0.8), _stroke(_wood, thin));
        c.drawCircle(at(0.86), w * 0.09, _fill(const Color(0xFF8E959E)));
      case Skill.polearm:
        c.drawLine(grip - dir * 0.15, at(0.8), _stroke(_wood, thin));
        final head = Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(
            (at(0.78) + normal * w * 0.06).dx,
            (at(0.78) + normal * w * 0.06).dy,
          )
          ..lineTo(
            (at(0.78) - normal * w * 0.06).dx,
            (at(0.78) - normal * w * 0.06).dy,
          )
          ..close();
        c.drawPath(head, _fill(_steel));
      case Skill.bow:
        // 활대는 무기 축에서 바깥으로 휜 호, 시위는 직선.
        final bend = normal * w * 0.16;
        final limb = Path()
          ..moveTo(grip.dx, grip.dy)
          ..quadraticBezierTo(
            (at(0.5) + bend * 2).dx,
            (at(0.5) + bend * 2).dy,
            tip.dx,
            tip.dy,
          );
        c.drawPath(
          limb,
          _stroke(_wood, thin * 1.2)..style = PaintingStyle.stroke,
        );
        c.drawLine(
          grip,
          tip,
          _stroke(const Color(0xFFE8E2D0), math.max(1, w * 0.015)),
        );
      default:
        c.drawLine(grip, tip, _stroke(_wood, thin));
    }
  }

  void _armour(Canvas c, Rect r, ArmourType type) {
    final color = switch (type.id) {
      'robe' => const Color(0xFF6A4C9C),
      'leather_armour' => const Color(0xFF8B5A2B),
      'ring_mail' => const Color(0xFF8E959E),
      'scale_mail' => const Color(0xFF7F8C5A),
      'chain_mail' => const Color(0xFFB0B7BF),
      _ => const Color(0xFFD0D6DE),
    };
    final w = r.width;
    final h = r.height;
    final body = Path()
      ..moveTo(r.left + w * 0.3, r.top)
      ..lineTo(r.left + w * 0.7, r.top)
      ..lineTo(r.right, r.top + h * 0.22)
      ..lineTo(r.left + w * 0.84, r.top + h * 0.42)
      ..lineTo(r.left + w * 0.76, r.top + h * 0.34)
      ..lineTo(r.left + w * 0.76, r.bottom)
      ..lineTo(r.left + w * 0.24, r.bottom)
      ..lineTo(r.left + w * 0.24, r.top + h * 0.34)
      ..lineTo(r.left + w * 0.16, r.top + h * 0.42)
      ..lineTo(r.left, r.top + h * 0.22)
      ..close();
    c.drawPath(body, _fill(color));
    c.drawPath(
      body,
      _stroke(const Color(0x66000000), math.max(1, w * 0.04))
        ..style = PaintingStyle.stroke,
    );
  }

  void _shield(Canvas c, Rect r, ShieldType type) {
    final edge = _stroke(const Color(0xFF5A4630), math.max(1, r.width * 0.1))
      ..style = PaintingStyle.stroke;
    switch (type.id) {
      case 'buckler':
        c.drawOval(r, _fill(const Color(0xFF9A7B4F)));
        c.drawOval(r, edge);
        c.drawCircle(r.center, r.width * 0.12, _fill(_steel));
      case 'kite_shield':
        final kite = Path()
          ..moveTo(r.left, r.top)
          ..lineTo(r.right, r.top)
          ..lineTo(r.right, r.top + r.height * 0.45)
          ..lineTo(r.center.dx, r.bottom)
          ..lineTo(r.left, r.top + r.height * 0.45)
          ..close();
        c.drawPath(kite, _fill(const Color(0xFF3F5E8C)));
        c.drawPath(kite, edge);
      default:
        final rr = RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.12));
        c.drawRRect(rr, _fill(const Color(0xFF6B6F75)));
        c.drawRRect(rr, edge);
    }
  }
}
