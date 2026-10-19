import 'dart:math' as math;
import 'dart:ui';

/// 맵 확대/축소 배율 계산.
///
/// 배율 1.0 = 시야 전체(지름 `2 × 반경 + 1`칸)가 화면에 딱 들어오는 크기.
/// 이보다 작게는 줄일 수 없으므로 시야 안의 칸은 기본 배율에서 항상 보인다.
abstract final class MapZoom {
  static const minZoom = 1.0;

  /// 확대해도 타일 한 칸이 이 크기(논리 픽셀)를 넘지 않는다.
  static const maxTileSize = 72.0;

  static double fitTileSize(Size viewport, int fovRadius) {
    final tiles = 2 * fovRadius + 1;
    return math.min(viewport.width, viewport.height) / tiles;
  }

  static double maxZoom(Size viewport, int fovRadius) =>
      math.max(minZoom, maxTileSize / fitTileSize(viewport, fovRadius));

  static double clamp(double zoom, Size viewport, int fovRadius) =>
      zoom.clamp(minZoom, maxZoom(viewport, fovRadius));

  static double tileSize(Size viewport, int fovRadius, double zoom) =>
      fitTileSize(viewport, fovRadius) * clamp(zoom, viewport, fovRadius);
}
