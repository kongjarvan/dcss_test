/// 미확인 물약의 겉모습. 게임마다 물약 종류에 무작위로 배정된다.
class PotionAppearance {
  const PotionAppearance(this.name, this.color);

  /// "붉은" → "붉은 물약"
  final String name;

  /// 그림에 쓰는 색 (0xAARRGGBB).
  final int color;

  /// 물약 종류 수보다 많아야 한다.
  static const all = [
    PotionAppearance('붉은', 0xFFD9443B),
    PotionAppearance('푸른', 0xFF3B6FD9),
    PotionAppearance('초록', 0xFF3BA55C),
    PotionAppearance('노란', 0xFFE3C33B),
    PotionAppearance('보랏빛', 0xFF8E4BC9),
    PotionAppearance('주황', 0xFFE38A2E),
    PotionAppearance('하얀', 0xFFEDEDED),
    PotionAppearance('검은', 0xFF2B2B2B),
    PotionAppearance('은빛', 0xFFB8C0C8),
    PotionAppearance('금빛', 0xFFD4AF37),
    PotionAppearance('탁한', 0xFF7A7458),
    PotionAppearance('분홍', 0xFFE07AB0),
    PotionAppearance('갈색', 0xFF8B5A2B),
    PotionAppearance('청록', 0xFF2FB3A8),
  ];
}
