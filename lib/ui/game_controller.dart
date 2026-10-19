import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/action/action.dart';
import '../core/game.dart';
import '../core/geometry.dart';

/// 입력(탭, 버튼)을 게임 행동으로 바꾸고 화면 갱신을 알린다.
class GameController extends ChangeNotifier {
  GameController({int? seed}) : _game = Game.newGame(seed: seed);

  static const _travelStepInterval = Duration(milliseconds: 70);

  Game _game;
  Game get game => _game;

  Timer? _travelTimer;
  Pos? _travelTarget;
  Pos? get travelTarget => _travelTarget;
  List<Pos> _travelPath = const [];
  bool get isTraveling => _travelTimer != null;

  void newGame() {
    _stopTravel();
    _game = Game.newGame();
    notifyListeners();
  }

  /// 맵의 한 칸을 탭했을 때.
  /// - 자기 자신: 1턴 대기
  /// - 인접 칸: 이동/공격/문 열기
  /// - 먼 칸: 탐험한 길을 따라 자동 이동
  void tapTile(Pos target) {
    if (_game.isGameOver) return;
    if (isTraveling) {
      _stopTravel();
      notifyListeners();
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

  void rest() {
    _game.rest();
    notifyListeners();
  }

  void stopTravel() {
    _stopTravel();
    notifyListeners();
  }

  void _startTravel(Pos dest) {
    final path = _game.travelPath(dest);
    if (path == null) return;
    if (_game.visibleMonsters.isNotEmpty) {
      _game.message('근처에 몬스터가 있어 자동 이동할 수 없다.');
      return;
    }
    _travelTarget = dest;
    _travelPath = path;
    _travelTimer = Timer.periodic(_travelStepInterval, (_) => _travelStep());
  }

  void _travelStep() {
    final dest = _travelTarget!;
    // 처음 계산한 경로를 그대로 따라간다. 매번 다시 계산하면 기준 직선이
    // 바뀌어 모양이 흔들린다. 다음 칸이 인접하지 않을 때만 재계산.
    if (_travelPath.isEmpty ||
        !_travelPath.first.isAdjacentTo(_game.player.pos)) {
      _travelPath = _game.travelPath(dest) ?? const [];
    }
    if (_travelPath.isEmpty || _game.isGameOver) {
      stopTravel();
      return;
    }
    final next = _travelPath.first;
    final hpBefore = _game.player.hp;
    final acted = _game.playerAct(MoveAction(next - _game.player.pos));
    // 문을 연 경우엔 제자리이므로 같은 칸을 다음 걸음에 다시 시도한다.
    if (_game.player.pos == next) _travelPath = _travelPath.sublist(1);
    if (!acted ||
        _game.player.pos == dest ||
        _game.visibleMonsters.isNotEmpty ||
        _game.player.hp < hpBefore) {
      _stopTravel();
    }
    notifyListeners();
  }

  void _stopTravel() {
    _travelTimer?.cancel();
    _travelTimer = null;
    _travelTarget = null;
    _travelPath = const [];
  }

  @override
  void dispose() {
    _stopTravel();
    super.dispose();
  }
}
