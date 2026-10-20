import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/action/action.dart';
import '../core/game.dart';
import '../core/geometry.dart';
import '../core/progression/attributes.dart';
import '../core/progression/job.dart';
import '../core/progression/skills.dart';
import '../core/progression/species.dart';

/// 자동 이동 종류.
enum AutoMoveMode {
  /// 탭한 목적지까지 이동.
  travel,

  /// 탐험하지 않은 곳을 찾아 계속 이동.
  explore,

  /// HP가 가득 찰 때까지 제자리에서 휴식.
  rest,
}

/// 입력(탭, 버튼)을 게임 행동으로 바꾸고 화면 갱신을 알린다.
class GameController extends ChangeNotifier {
  GameController({int? seed, Species species = Species.human, Job? job})
    : _game = Game.newGame(seed: seed, species: species, job: job);

  static const _autoMoveInterval = Duration(milliseconds: 70);
  static const _restInterval = Duration(milliseconds: 20);

  final Game _game;
  Game get game => _game;

  Timer? _autoMoveTimer;
  AutoMoveMode? _autoMoveMode;
  Pos? _travelTarget;
  List<Pos> _travelPath = const [];
  int _restStartTime = 0;

  /// 현재 이동 목표 (화면에 표시).
  Pos? get travelTarget => _travelTarget;
  bool get isTraveling => _autoMoveTimer != null;
  AutoMoveMode? get autoMoveMode => _autoMoveMode;

  bool get enemyInSight => _game.visibleMonsters.isNotEmpty;

  /// HP와 MP가 모두 가득한지.
  bool get isFullyRested =>
      _game.player.hp >= _game.player.maxHp &&
      _game.player.mp >= _game.player.maxMp;

  /// 자동 탐험 버튼 사용 가능 여부.
  bool get canExplore => !_game.isGameOver && !enemyInSight;

  /// 투자하지 않은 능력치 포인트가 있는지.
  bool get hasStatPoints => _game.player.unspentStatPoints > 0;

  /// 휴식 버튼 사용 가능 여부.
  bool get canRest => !_game.isGameOver && !enemyInSight && !isFullyRested;

  /// 맵의 한 칸을 탭했을 때.
  /// - 자기 자신: 1턴 대기
  /// - 인접 칸: 이동/공격/문 열기
  /// - 먼 칸: 탐험한 길을 따라 자동 이동
  void tapTile(Pos target) {
    if (_game.isGameOver) return;
    if (isTraveling) {
      stopTravel();
      return;
    }
    final here = _game.player.pos;
    if (target == here) {
      _game.playerAct(const WaitAction());
    } else if (target.isAdjacentTo(here)) {
      _game.playerAct(MoveAction(target - here));
    } else {
      _startTravel(target);
    }
    notifyListeners();
  }

  void waitTurn() {
    if (_game.isGameOver) return;
    _game.playerAct(const WaitAction());
    notifyListeners();
  }

  void increaseAttribute(Attribute attribute) {
    if (_game.increaseAttribute(attribute)) notifyListeners();
  }

  /// 숙련도 훈련 켜기/끄기. 턴을 소모하지 않는다.
  void setSkillTraining(Skill skill, bool training) {
    _game.player.skills.setTraining(skill, training);
    notifyListeners();
  }

  void autoFight() {
    if (_game.isGameOver) return;
    final action = _game.autoFightAction();
    if (action == null) {
      _game.message('공격할 대상이 없다.');
    } else {
      _game.playerAct(action);
    }
    notifyListeners();
  }

  /// HP와 MP가 가득 찰 때까지 1턴씩 대기한다.
  void rest() {
    if (isTraveling || !canRest) return;
    _restStartTime = _game.time;
    _autoMoveMode = AutoMoveMode.rest;
    _autoMoveTimer = Timer.periodic(_restInterval, (_) => autoMoveStep());
    notifyListeners();
  }

  void _restStep() {
    final hpBefore = _game.player.hp;
    _game.playerAct(const WaitAction());
    // 상단의 '직전 행동'에 휴식 전체 시간을 표시.
    _game.lastActionCost = _game.time - _restStartTime;
    if (isFullyRested) {
      _game.message('휴식을 마쳤다. HP와 MP가 모두 회복되었다.');
      _stopAutoMove();
    } else if (enemyInSight || _game.player.hp < hpBefore) {
      _stopAutoMove();
    }
    notifyListeners();
  }

  void explore() {
    if (isTraveling || !canExplore) return;
    final target = _game.exploreTarget();
    if (target == null) {
      _game.message('더 탐험할 곳이 없다.');
    } else {
      _beginAutoMove(AutoMoveMode.explore, target);
    }
    notifyListeners();
  }

  void stopTravel() {
    _stopAutoMove();
    notifyListeners();
  }

  void _startTravel(Pos dest) {
    if (_game.travelPath(dest) == null) return;
    if (_game.visibleMonsters.isNotEmpty) {
      _game.message('근처에 몬스터가 있어 자동 이동할 수 없다.');
      return;
    }
    _beginAutoMove(AutoMoveMode.travel, dest);
  }

  void _beginAutoMove(AutoMoveMode mode, Pos target) {
    _autoMoveMode = mode;
    _setTarget(target);
    _autoMoveTimer = Timer.periodic(_autoMoveInterval, (_) => autoMoveStep());
  }

  void _setTarget(Pos target) {
    _travelTarget = target;
    _travelPath = _game.travelPath(target) ?? const [];
  }

  /// 자동 이동 한 걸음. 타이머가 호출하며, 테스트에서 직접 호출할 수 있다.
  @visibleForTesting
  void autoMoveStep() {
    if (!isTraveling) return;
    if (_game.isGameOver) {
      stopTravel();
      return;
    }
    if (_autoMoveMode == AutoMoveMode.rest) {
      _restStep();
      return;
    }

    // 탐험 중이면 목표에 도착했거나 목표가 더 이상 경계가 아닐 때 새 목표를 찾는다.
    if (_autoMoveMode == AutoMoveMode.explore) {
      final target = _travelTarget;
      if (target == null ||
          target == _game.player.pos ||
          !_game.isExploreFrontier(target)) {
        final next = _game.exploreTarget();
        if (next == null) {
          _game.message('탐험을 마쳤다.');
          stopTravel();
          return;
        }
        _setTarget(next);
      }
    }

    final dest = _travelTarget!;
    // 처음 계산한 경로를 그대로 따라간다. 매번 다시 계산하면 기준 직선이
    // 바뀌어 모양이 흔들린다. 다음 칸이 인접하지 않을 때만 재계산.
    if (_travelPath.isEmpty ||
        !_travelPath.first.isAdjacentTo(_game.player.pos)) {
      _travelPath = _game.travelPath(dest) ?? const [];
    }
    if (_travelPath.isEmpty) {
      stopTravel();
      return;
    }

    final next = _travelPath.first;
    final hpBefore = _game.player.hp;
    final acted = _game.playerAct(MoveAction(next - _game.player.pos));
    // 문을 연 경우엔 제자리이므로 같은 칸을 다음 걸음에 다시 시도한다.
    if (_game.player.pos == next) _travelPath = _travelPath.sublist(1);

    final arrived =
        _autoMoveMode == AutoMoveMode.travel && _game.player.pos == dest;
    if (!acted ||
        arrived ||
        _game.visibleMonsters.isNotEmpty ||
        _game.player.hp < hpBefore) {
      _stopAutoMove();
    }
    notifyListeners();
  }

  void _stopAutoMove() {
    _autoMoveTimer?.cancel();
    _autoMoveTimer = null;
    _autoMoveMode = null;
    _travelTarget = null;
    _travelPath = const [];
  }

  @override
  void dispose() {
    _stopAutoMove();
    super.dispose();
  }
}
