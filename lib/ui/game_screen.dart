import 'package:flutter/material.dart';

import '../core/entity/status.dart';
import '../core/game.dart';
import '../core/message_log.dart';
import '../core/progression/job.dart';
import '../core/progression/species.dart';
import '../core/time/energy.dart';
import '../render/map_painter.dart';
import '../render/map_zoom.dart';
import '../render/tile_renderer.dart';
import 'action_bar.dart';
import 'character_sheet.dart';
import 'game_controller.dart';
import 'species_select_screen.dart';

String _turns(int aut) => (aut / autPerTurn).toStringAsFixed(1);

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    this.seed,
    this.species = Species.human,
    this.job,
    this.controller,
  });

  /// 고정 시드 (테스트/디버깅용). null이면 매번 새 던전.
  final int? seed;

  final Species species;

  final Job? job;

  /// 외부에서 만든 컨트롤러 (테스트용). null이면 직접 만든다.
  final GameController? controller;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameController _controller =
      widget.controller ??
      GameController(
        seed: widget.seed,
        species: widget.species,
        job: widget.job,
      );
  static const _renderer = ProceduralTileRenderer();

  /// 맵 확대 배율. 1.0 = 시야 전체가 화면에 들어오는 크기.
  double _zoom = MapZoom.minZoom;
  double _zoomAtGestureStart = MapZoom.minZoom;

  late int _lastLevel;
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    _lastLevel = _controller.game.player.level;
    _controller.addListener(_onGameChanged);
  }

  /// 레벨이 오르면 능력치 선택 창을 띄운다. 닫고 나중에 골라도 된다.
  void _onGameChanged() {
    final player = _controller.game.player;
    final leveledUp = player.level > _lastLevel;
    _lastLevel = player.level;
    if (!leveledUp || _sheetOpen || player.unspentStatPoints == 0) return;
    _controller.stopTravel();
    _sheetOpen = true;
    // 빌드 중 알림일 수 있으므로 프레임이 끝난 뒤 연다.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showCharacterSheet(context, _controller, requireSpend: true);
      _sheetOpen = false;
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onGameChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final game = _controller.game;
            return Stack(
              children: [
                Column(
                  children: [
                    _StatusBar(game: game, onNewGame: _confirmNewGame),
                    Expanded(child: _buildMap(game)),
                    _MessagePanel(log: game.log, now: game.time),
                    ActionBar(controller: _controller),
                  ],
                ),
                if (game.isGameOver)
                  _GameOverOverlay(
                    game: game,
                    onRestart: () => SpeciesSelectScreen.open(context),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmNewGame() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('새 게임'),
        content: const Text('현재 진행 중인 게임을 버리고 새로 시작할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('새로 시작'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) SpeciesSelectScreen.open(context);
  }

  Widget _buildMap(Game game) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final tileSize = MapZoom.tileSize(size, Game.fovRadius, _zoom);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // 두 손가락 핀치로 확대/축소.
          onScaleStart: (_) => _zoomAtGestureStart = _zoom,
          onScaleUpdate: (details) {
            if (details.pointerCount < 2) return;
            setState(() {
              _zoom = MapZoom.clamp(
                _zoomAtGestureStart * details.scale,
                size,
                Game.fovRadius,
              );
            });
          },
          onTapUp: (details) => _controller.tapTile(
            MapPainter.tileAt(
              details.localPosition,
              size,
              game.player.pos,
              tileSize,
            ),
          ),
          child: CustomPaint(
            size: size,
            painter: MapPainter(
              game: game,
              tileSize: tileSize,
              renderer: _renderer,
              travelTarget: _controller.travelTarget,
            ),
          ),
        );
      },
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.game, required this.onNewGame});

  final Game game;
  final VoidCallback onNewGame;

  @override
  Widget build(BuildContext context) {
    final player = game.player;
    final ratio = (player.hp / player.maxHp).clamp(0.0, 1.0);
    final hpColor = ratio > 0.5
        ? const Color(0xFF4CAF50)
        : ratio > 0.25
        ? const Color(0xFFFFB300)
        : const Color(0xFFE53935);
    const labelStyle = TextStyle(color: Color(0xFFBDB6A8), fontSize: 13);

    return Container(
      color: const Color(0xFF15120F),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 84,
                child: Text(
                  'HP ${player.hp.clamp(0, player.maxHp)}/${player.maxHp}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 10,
                    color: hpColor,
                    backgroundColor: const Color(0xFF3A1A1A),
                  ),
                ),
              ),
              IconButton(
                onPressed: onNewGame,
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: '새 게임',
                color: const Color(0xFFBDB6A8),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          _BarRow(
            label: 'MP ${player.mp}/${player.maxMp}',
            labelColor: const Color(0xFF8FB8FF),
            value: player.maxMp == 0 ? 0 : player.mp / player.maxMp,
            color: const Color(0xFF5B8DEF),
            background: const Color(0xFF1C2433),
            height: 8,
          ),
          const SizedBox(height: 4),
          _BarRow(
            label: 'Lv ${player.level}',
            labelColor: const Color(0xFFD8B04A),
            value: xpProgress(player),
            color: const Color(0xFFD8B04A),
            background: const Color(0xFF2E2614),
            height: 5,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('1층', style: labelStyle),
              Text('시간 ${_turns(game.time)}', style: labelStyle),
              Text('직전 행동 ${_turns(game.lastActionCost)}턴', style: labelStyle),
              Text('처치 ${game.kills}', style: labelStyle),
            ],
          ),
          if (player.statuses.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final MapEntry(key: status, value: aut)
                    in player.statuses.entries)
                  _StatusChip(status: status, aut: aut),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 상태바의 '라벨 + 막대' 한 줄. 첫 줄의 새 게임 버튼 폭만큼 오른쪽을 비워 막대 끝을 맞춘다.
class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.labelColor,
    required this.value,
    required this.color,
    required this.background,
    required this.height,
  });

  final String label;
  final Color labelColor;
  final double value;
  final Color color;
  final Color background;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: height,
              color: color,
              backgroundColor: background,
            ),
          ),
        ),
        const SizedBox(width: 40),
      ],
    );
  }
}

IconData statusIcon(Status status) => switch (status) {
  Status.haste => Icons.fast_forward,
  Status.slow => Icons.slow_motion_video,
  Status.might => Icons.fitness_center,
  Status.agility => Icons.air,
  Status.brilliance => Icons.psychology,
  Status.poison => Icons.sick,
};

/// 상태 효과 표시: 아이콘 + 이름 + 남은 턴. 해로운 효과는 빨간색.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.aut});

  final Status status;
  final int aut;

  @override
  Widget build(BuildContext context) {
    final color = status.harmful
        ? const Color(0xFFE57373)
        : const Color(0xFF7BC67B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon(status), size: 13, color: color),
          const SizedBox(width: 3),
          Text(
            '${status.label} ${(aut / autPerTurn).ceil()}',
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({required this.log, required this.now});

  static const _lines = 5;

  final MessageLog log;
  final int now;

  @override
  Widget build(BuildContext context) {
    final messages = log.recent(_lines);
    return Container(
      height: _lines * 18.0 + 12,
      width: double.infinity,
      color: const Color(0xFF0E0C0A),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final m in messages)
            Text(
              m.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.38,
                // 이번 턴에 발생한 메시지는 밝게.
                color: m.time == now
                    ? const Color(0xFFF2EDE4)
                    : const Color(0xFF8A8478),
              ),
            ),
        ],
      ),
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({required this.game, required this.onRestart});

  final Game game;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xCC000000),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '당신은 죽었다',
                style: TextStyle(
                  color: Color(0xFFE53935),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '생존 시간 ${_turns(game.time)}턴 · 처치 ${game.kills}',
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 24),
              IconButton.filled(
                onPressed: onRestart,
                tooltip: '다시 시작',
                iconSize: 36,
                padding: const EdgeInsets.all(14),
                icon: const Icon(Icons.replay),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
