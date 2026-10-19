import 'dart:ui';

import 'package:dc_test/core/game.dart';
import 'package:dc_test/core/geometry.dart';
import 'package:dc_test/render/map_painter.dart';
import 'package:dc_test/render/map_zoom.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const r = Game.fovRadius;

  group('확대/축소', () {
    for (final viewport in const [
      Size(411, 600),
      Size(360, 480),
      Size(800, 500),
    ]) {
      test('기본 배율에서 시야 전체가 화면 안에 들어온다 $viewport', () {
        final tile = MapZoom.tileSize(viewport, r, MapZoom.minZoom);
        const center = Pos(30, 20);
        // 시야 경계의 네 모서리 칸이 화면 안에 있어야 한다.
        for (final corner in const [
          Pos(-r, -r),
          Pos(r, -r),
          Pos(-r, r),
          Pos(r, r),
        ]) {
          final p = center + corner;
          final origin = MapPainter.cameraOrigin(viewport, center, tile);
          final left = (p.x - origin.dx) * tile;
          final top = (p.y - origin.dy) * tile;
          expect(left, greaterThanOrEqualTo(-0.01), reason: '$corner');
          expect(top, greaterThanOrEqualTo(-0.01), reason: '$corner');
          expect(left + tile, lessThanOrEqualTo(viewport.width + 0.01));
          expect(top + tile, lessThanOrEqualTo(viewport.height + 0.01));
        }
      });
    }

    test('기본 배율보다 작게, 최대 타일 크기보다 크게는 안 된다', () {
      const viewport = Size(411, 600);
      final fit = MapZoom.fitTileSize(viewport, r);
      expect(MapZoom.tileSize(viewport, r, 0.3), fit);
      expect(MapZoom.tileSize(viewport, r, 100), MapZoom.maxTileSize);
      expect(MapZoom.tileSize(viewport, r, 2), closeTo(fit * 2, 1e-9));
    });

    test('탭 좌표 → 타일 변환은 확대 배율과 무관하게 정확하다', () {
      const viewport = Size(411, 600);
      const center = Pos(30, 20);
      for (final zoom in [1.0, 1.7, 2.5]) {
        final tile = MapZoom.tileSize(viewport, r, zoom);
        final origin = MapPainter.cameraOrigin(viewport, center, tile);
        const target = Pos(33, 18);
        final screen = Offset(
          (target.x + 0.5 - origin.dx) * tile,
          (target.y + 0.5 - origin.dy) * tile,
        );
        expect(MapPainter.tileAt(screen, viewport, center, tile), target);
      }
    });
  });

  group('화면 밖 몬스터 화살표', () {
    const size = Size(400, 600);

    test('화면 안이면 표시하지 않는다', () {
      expect(
        MapPainter.edgeIndicatorPosition(size, const Offset(100, 100)),
        isNull,
      );
    });

    test('화면 밖이면 그 방향의 가장자리에 표시한다', () {
      final right = MapPainter.edgeIndicatorPosition(
        size,
        const Offset(900, 300),
      )!;
      expect(right.dx, closeTo(400 - 16, 1e-9));
      expect(right.dy, closeTo(300, 1e-9));

      final topLeft = MapPainter.edgeIndicatorPosition(
        size,
        const Offset(-200, -900),
      )!;
      expect(topLeft.dy, closeTo(16, 1e-9));
      expect(topLeft.dx, lessThan(200));
      expect(topLeft.dx, greaterThan(0));
    });
  });
}
