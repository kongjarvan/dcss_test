import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/entity/actor.dart';
import '../core/entity/status.dart';
import '../core/game.dart';
import '../core/geometry.dart';
import '../core/items/item.dart';
import '../core/progression/job.dart';
import '../core/progression/species.dart';
import '../core/time/energy.dart';
import '../render/map_painter.dart';
import '../render/map_zoom.dart';
import '../render/tile_renderer.dart';
import 'action_bar.dart';
import 'character_sheet.dart';
import 'game_controller.dart';
import 'inventory_screen.dart';
import 'message_log_screen.dart';
import 'side_panel.dart';
import 'species_select_screen.dart';

String _turns(int aut) => (aut / autPerTurn).toStringAsFixed(1);

/// 오른쪽 패널(상태·메시지·버튼) 너비.
const sidePanelWidth = 300.0;

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

  // ── 토스트 (새 메시지를 맵 위쪽에 잠깐 표시) ──
  static const _maxToasts = 3;
  static const _toastTick = Duration(milliseconds: 500);

  /// 토스트가 떠 있는 시간 (틱 수). 6틱 = 3초.
  static const _toastLife = 6;

  /// 이미 토스트로 보여준(또는 로그 화면에서 본) 메시지 수.
  late int _seenMessages;
  final List<_Toast> _toasts = [];
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _lastLevel = _controller.game.player.level;
    _seenMessages = _controller.game.log.total;
    _controller.addListener(_onGameChanged);
  }

  void _collectToasts() {
    final log = _controller.game.log;
    final fresh = log.total - _seenMessages;
    _seenMessages = log.total;
    if (fresh <= 0) return;
    setState(() {
      for (final m in log.recent(min(fresh, _maxToasts))) {
        _toasts.add(_Toast(m.text, _toastLife));
      }
      while (_toasts.length > _maxToasts) {
        _toasts.removeAt(0);
      }
    });
    _toastTimer ??= Timer.periodic(_toastTick, (_) => _ageToasts());
  }

  void _ageToasts() {
    if (!mounted) return;
    setState(() {
      for (final t in _toasts) {
        t.life--;
      }
      _toasts.removeWhere((t) => t.life <= 0);
    });
    if (_toasts.isEmpty) {
      _toastTimer?.cancel();
      _toastTimer = null;
    }
  }

  Future<void> _openLog() async {
    await MessageLogScreen.open(context, _controller.game.log);
    if (!mounted) return;
    // 로그에서 다 봤으므로 떠 있는 토스트는 지운다.
    setState(() {
      _seenMessages = _controller.game.log.total;
      _toasts.clear();
    });
  }

  /// 새 메시지를 토스트로 띄우고, 레벨이 오르면 능력치 선택 창을 띄운다.
  void _onGameChanged() {
    _collectToasts();
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
    _toastTimer?.cancel();
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
                // 가로 화면: 왼쪽은 맵, 오른쪽 패널에 상태·메시지·버튼.
                Row(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          _buildMap(game),
                          // 새 메시지 토스트: 맵 위쪽 가운데.
                          if (_toasts.isNotEmpty)
                            Positioned(
                              left: 24,
                              right: 24,
                              top: 6,
                              child: IgnorePointer(
                                child: _ToastList(toasts: _toasts),
                              ),
                            ),
                          // 상태 효과: 맵 왼쪽 아래.
                          if (game.player.statuses.isNotEmpty)
                            Positioned(
                              left: 8,
                              bottom: 8,
                              right: 8,
                              child: _StatusChips(player: game.player),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: sidePanelWidth,
                      child: Column(
                        children: [
                          _StatusBar(
                            controller: _controller,
                            onNewGame: _confirmNewGame,
                            onOpenLog: _openLog,
                          ),
                          Expanded(child: SidePanel(controller: _controller)),
                          ActionBar(controller: _controller),
                        ],
                      ),
                    ),
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

  /// [tile]에 있는 아이템을 누른 위치([anchor]) 근처에 작은 팝업으로 보여준다.
  /// 본 적 없는 칸은 아무것도 하지 않는다.
  void _showTileItems(Offset anchor, Pos tile) {
    final game = _controller.game;
    if (!game.map.isExplored(tile)) return;
    final items = game.itemsAt(tile);
    // 몬스터는 지금 보이는 칸에 있을 때만.
    final actor = game.map.isVisible(tile) ? game.actorAt(tile) : null;
    final monster = actor is Monster ? actor : null;
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '닫기',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (dialogContext, _, _) {
        final screen = MediaQuery.sizeOf(dialogContext);
        const width = 220.0;
        // 화면 밖으로 나가지 않게 누른 위치 오른쪽 아래에 둔다.
        final left = (anchor.dx + 12).clamp(8.0, screen.width - width - 8);
        final top = (anchor.dy - 12).clamp(8.0, screen.height * 0.5);
        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: width,
              child: _TileItemsPopup(
                game: game,
                items: items,
                monster: monster,
              ),
            ),
          ],
        );
      },
    );
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
          // 길게 누르면 그 칸의 아이템을 팝업으로 보여준다.
          onLongPressStart: (details) => _showTileItems(
            details.globalPosition,
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
  const _StatusBar({
    required this.controller,
    required this.onNewGame,
    required this.onOpenLog,
  });

  final GameController controller;
  Game get game => controller.game;
  final VoidCallback onNewGame;
  final VoidCallback onOpenLog;

  @override
  Widget build(BuildContext context) {
    final player = game.player;
    final ratio = (player.hp / player.maxHp).clamp(0.0, 1.0);
    final hpColor = ratio > 0.5
        ? const Color(0xFF4CAF50)
        : ratio > 0.25
        ? const Color(0xFFFFB300)
        : const Color(0xFFE53935);

    return Container(
      color: const Color(0xFF15120F),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                onPressed: onOpenLog,
                icon: const Icon(Icons.receipt_long, size: 20),
                tooltip: '메시지 로그',
                color: const Color(0xFFBDB6A8),
                visualDensity: VisualDensity.compact,
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
          // 레벨·층, 그 오른쪽에 발밑 아이템 (누르면 상세 정보).
          Row(
            children: [
              Text(
                'Lv ${player.level} · 1층',
                style: const TextStyle(
                  color: Color(0xFFD8B04A),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: FloorItemStrip(controller: controller)),
            ],
          ),
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
        // 첫 줄의 아이콘 버튼 두 개(로그·새 게임) 폭만큼 비워 막대 끝을 맞춘다.
        const SizedBox(width: 80),
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

/// 몬스터 체력 상태 (DCSS식 표현).
String monsterHealthText(Monster m) {
  final ratio = m.hp / m.maxHp;
  if (ratio >= 1) return '다치지 않음';
  if (ratio > 0.75) return '조금 다침';
  if (ratio > 0.5) return '다침';
  if (ratio > 0.25) return '심하게 다침';
  return '거의 죽어감';
}

/// 몬스터가 지금 무엇을 하는지.
String monsterActivityText(Monster m) => !m.awake
    ? '자는 중'
    : m.lastKnownPlayerPos != null
    ? '당신을 쫓는 중'
    : '배회 중';

/// 맵 칸 길게 누르기 팝업: 그 칸의 몬스터 정보와 아이템 목록 (아이콘 + 이름).
class _TileItemsPopup extends StatelessWidget {
  const _TileItemsPopup({
    required this.game,
    required this.items,
    this.monster,
  });

  final Game game;
  final List<Item> items;
  final Monster? monster;

  @override
  Widget build(BuildContext context) {
    final monster = this.monster;
    const dim = TextStyle(color: Color(0xFF8A8478), fontSize: 12);
    return Material(
      color: const Color(0xF21A1714),
      elevation: 6,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (monster != null) ...[
              Text(
                monster.name,
                style: const TextStyle(
                  color: Color(0xFFE57373),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${monsterHealthText(monster)} · ${monsterActivityText(monster)}',
                style: const TextStyle(color: Color(0xFFF2EDE4), fontSize: 12),
              ),
              Text(
                [
                  monster.weaponType?.name ?? '맨손',
                  ?monster.armourType?.name,
                  ?monster.shieldType?.name,
                ].join(' · '),
                style: dim,
              ),
              if (items.isNotEmpty) const Divider(height: 12),
            ],
            if (monster == null && items.isEmpty)
              const Text(
                '아무것도 없다.',
                style: TextStyle(color: Color(0xFF8A8478), fontSize: 13),
              ),
            if (items.isNotEmpty)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final item in items.take(8))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          ItemIcon.of(game, item, size: 26),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              game.nameOf(item),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFF2EDE4),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (items.length > 8)
                    Text(
                      '외 ${items.length - 8}개',
                      style: const TextStyle(
                        color: Color(0xFF8A8478),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Toast {
  _Toast(this.text, this.life);

  final String text;

  /// 남은 틱 수. 0이 되면 사라진다.
  int life;
}

/// 맵 위쪽에 작게 띄우는 메시지들. 사라지기 직전에는 흐려진다.
class _ToastList extends StatelessWidget {
  const _ToastList({required this.toasts});

  final List<_Toast> toasts;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final t in toasts)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: AnimatedOpacity(
              opacity: t.life <= 1 ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 400),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xCC15120F),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  t.text,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFF2EDE4),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusChips extends StatelessWidget {
  const _StatusChips({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final MapEntry(key: status, value: aut) in player.statuses.entries)
          _StatusChip(status: status, aut: aut),
      ],
    );
  }
}

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
        color: const Color(0xCC15120F),
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
