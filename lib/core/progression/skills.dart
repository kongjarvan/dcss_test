import 'dart:math' as math;

enum SkillCategory {
  melee('근접 무기'),
  ranged('원거리 무기'),
  defense('방어'),
  misc('기타'),
  magic('마법'),
  divine('신앙');

  const SkillCategory(this.label);

  final String label;
}

/// 숙련도 종류.
enum Skill {
  mace('둔기', SkillCategory.melee),
  sword('검', SkillCategory.melee),
  axe('도끼', SkillCategory.melee),
  polearm('장병기', SkillCategory.melee),
  unarmed('맨손격투', SkillCategory.melee),
  bow('활', SkillCategory.ranged),
  throwing('투척무기', SkillCategory.ranged),
  armour('갑옷', SkillCategory.defense),
  dodging('회피', SkillCategory.defense),
  stealth('은신', SkillCategory.misc),
  shield('방패술', SkillCategory.defense),
  arcane('비전마법', SkillCategory.magic),
  fire('화염마법', SkillCategory.magic),
  earth('대지마법', SkillCategory.magic),
  ice('얼음마법', SkillCategory.magic),
  summoning('소환술', SkillCategory.magic),
  invocation('기도술', SkillCategory.divine);

  const Skill(this.label, this.category);

  final String label;
  final SkillCategory category;
}

/// 숙련도 성장 규칙. 밸런스 수치는 여기서 조정한다.
abstract final class SkillProgression {
  static const maxLevel = 27;

  /// 적성 0일 때 [level]에 도달하는 누적 경험치.
  /// 1레벨 10, 3레벨 125, 5레벨 405, 10레벨 약 2000, 27레벨 약 19600.
  static double baseTotalForLevel(int level) =>
      level <= 0 ? 0 : 10 * math.pow(level, 2.3).toDouble();

  /// 적성 배율: 적성 +4마다 필요 경험치 절반, -4마다 두 배 (DCSS와 같음).
  static double aptitudeMultiplier(int aptitude) =>
      math.pow(2, -aptitude / 4).toDouble();

  static double totalForLevel(int level, int aptitude) =>
      baseTotalForLevel(level) * aptitudeMultiplier(aptitude);
}

/// 플레이어의 숙련도 레벨·경험치·훈련 여부.
class SkillSet {
  SkillSet({
    Map<Skill, int> aptitudes = const {},
    Map<Skill, int> startingLevels = const {},
  }) : _aptitudes = Map.of(aptitudes) {
    for (final MapEntry(key: skill, value: level) in startingLevels.entries) {
      _level[skill] = level;
      _xp[skill] = SkillProgression.totalForLevel(level, aptitude(skill));
    }
    // 처음엔 직업이 익힌 숙련도를 훈련한다.
    _training.addAll(startingLevels.keys.where((s) => level(s) > 0));
  }

  final Map<Skill, int> _aptitudes;
  final Map<Skill, int> _level = {};
  final Map<Skill, double> _xp = {};
  final Set<Skill> _training = {};

  /// 훈련 중인 숙련도가 없을 때 받은 경험치. 다음 훈련 때 함께 분배한다.
  double _pool = 0;

  int aptitude(Skill skill) => _aptitudes[skill] ?? 0;
  int level(Skill skill) => _level[skill] ?? 0;
  double xp(Skill skill) => _xp[skill] ?? 0;
  bool isTraining(Skill skill) => _training.contains(skill);
  Set<Skill> get training => Set.unmodifiable(_training);
  double get pool => _pool;

  /// 다음 레벨까지 진행률 (0~1). 최대 레벨이면 1.
  double progress(Skill skill) {
    final lv = level(skill);
    if (lv >= SkillProgression.maxLevel) return 1;
    final apt = aptitude(skill);
    final from = SkillProgression.totalForLevel(lv, apt);
    final to = SkillProgression.totalForLevel(lv + 1, apt);
    return ((xp(skill) - from) / (to - from)).clamp(0.0, 1.0);
  }

  void setTraining(Skill skill, bool training) {
    if (training && level(skill) < SkillProgression.maxLevel) {
      _training.add(skill);
    } else {
      _training.remove(skill);
    }
  }

  /// 경험치 [points]를 훈련 중인 숙련도에 고르게 나눈다.
  /// 레벨이 오른 숙련도와 새 레벨을 반환한다.
  List<(Skill, int)> train(num points) {
    _pool += points;
    final targets = _training.toList();
    if (targets.isEmpty) return const [];

    final share = _pool / targets.length;
    _pool = 0;
    final raised = <(Skill, int)>[];
    for (final skill in targets) {
      _xp[skill] = xp(skill) + share;
      final before = level(skill);
      var lv = before;
      while (lv < SkillProgression.maxLevel &&
          xp(skill) >=
              SkillProgression.totalForLevel(lv + 1, aptitude(skill))) {
        lv++;
      }
      if (lv > before) {
        _level[skill] = lv;
        raised.add((skill, lv));
        if (lv >= SkillProgression.maxLevel) _training.remove(skill);
      }
    }
    return raised;
  }
}
