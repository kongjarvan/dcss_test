import 'dart:math';
import 'dart:ui' as ui;

import 'package:dc_test/core/action/action.dart';
import 'package:dc_test/core/entity/actor.dart';
import 'package:dc_test/core/entity/monster_type.dart';
import 'package:dc_test/core/game.dart';
import 'package:dc_test/core/geometry.dart';
import 'package:dc_test/core/items/item.dart';
import 'package:dc_test/core/korean.dart';
import 'package:dc_test/render/tile_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('오크는 고블린보다 강하다', () {
    const g = MonsterTypes.goblin, o = MonsterTypes.orc;
    expect(o.maxHp, greaterThan(g.maxHp));
    expect(o.stats.accuracy, greaterThan(g.stats.accuracy));
    expect(o.stats.maxDamage, greaterThan(g.stats.maxDamage));
    expect(o.xp, greaterThan(g.xp));
    expect(iGa(o.name), '오크가');
    expect(MonsterTypes.all, containsAll([g, o]));
  });

  test('1층에는 고블린만, 2층부터 오크가 섞여 나온다 (빈도 10:6)', () {
    final rng = Random(1);
    for (var i = 0; i < 500; i++) {
      expect(MonsterTypes.randomFor(1, rng), MonsterTypes.goblin);
    }
    var orcs = 0;
    const n = 8000;
    for (var i = 0; i < n; i++) {
      if (MonsterTypes.randomFor(2, rng) == MonsterTypes.orc) orcs++;
    }
    expect(orcs / n, closeTo(6 / 16, 0.03));
  });

  test('오크 장비 확률', () {
    final rng = Random(2);
    final weapons = <ItemType?, int>{};
    var armoured = 0;
    const n = 6000;
    for (var i = 0; i < n; i++) {
      final m = Monster(MonsterTypes.orc, pos: const Pos(0, 0))
        ..equipRandomGear(rng);
      weapons.update(m.weaponType, (v) => v + 1, ifAbsent: () => 1);
      if (m.armourType != null) armoured++;
    }
    double share(ItemType? t) => (weapons[t] ?? 0) / n;
    expect(share(ItemTypes.handAxe), closeTo(0.30, 0.03));
    expect(share(ItemTypes.club), closeTo(0.7 * 0.25, 0.03));
    expect(share(ItemTypes.spear), closeTo(0.7 * 0.75 * 0.15, 0.03));
    // 갑옷: 고리 15%, 아니면 가죽 25% → 약 36%
    expect(armoured / n, closeTo(0.15 + 0.85 * 0.25, 0.03));
  });

  test('실제 층 생성: 1층은 고블린만, 깊은 층에는 오크가 있다', () {
    final game = Game.newGame(seed: 3);
    expect(game.monsters.every((m) => m.type == MonsterTypes.goblin), isTrue);
    var sawOrc = false;
    for (var i = 0; i < 5 && !sawOrc; i++) {
      game.player.pos = game.stairsDown.first;
      game.playerAct(const UseStairsAction());
      sawOrc = game.monsters.any((m) => m.type == MonsterTypes.orc);
    }
    expect(sawOrc, isTrue);
  });

  test('오크 그림 (맨손·무기)', () async {
    const r = ProceduralTileRenderer();
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    r.drawMonster(c, const Rect.fromLTWH(0, 0, 64, 64), MonsterTypes.orc);
    r.drawMonster(
      c,
      const Rect.fromLTWH(64, 0, 64, 64),
      MonsterTypes.orc,
      weapon: ItemTypes.handAxe,
    );
    final img = await rec.endRecording().toImage(128, 64);
    expect(img.width, 128);
  });
}
