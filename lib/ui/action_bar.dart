import 'package:flutter/material.dart';

import 'character_sheet.dart';
import 'game_controller.dart';

/// 알림 점 (확인할 것이 있음).
class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: const BoxDecoration(
      color: Color(0xFFFFD54F),
      shape: BoxShape.circle,
    ),
  );
}

/// 하단 행동 버튼의 카테고리.
enum ActionCategory {
  movement('이동', Icons.directions_walk),
  combat('전투', Icons.sports_martial_arts),
  item('아이템', Icons.backpack),
  skill('적성', Icons.auto_graph);

  const ActionCategory(this.label, this.icon);

  /// 길게 눌렀을 때 툴팁으로 표시.
  final String label;
  final IconData icon;
}

/// 버튼을 쓸 수 없는 이유. 버튼 모서리에 작은 배지 아이콘으로 표시.
enum DisabledReason {
  comingSoon('준비 중', Icons.lock_outline),
  enemyInSight('적이 보임', Icons.visibility),
  fullyRested('회복 완료', Icons.favorite);

  const DisabledReason(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// 행동 버튼 하나. [onPressed]가 null이면 비활성.
class GameActionButton {
  const GameActionButton({
    required this.label,
    required this.icon,
    this.onPressed,
    this.disabledReason,
    this.highlight = false,
  });

  const GameActionButton.comingSoon({required this.label, required this.icon})
    : onPressed = null,
      disabledReason = DisabledReason.comingSoon,
      highlight = false;

  /// 길게 눌렀을 때 툴팁으로 표시.
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final DisabledReason? disabledReason;

  /// 확인할 것이 있음을 알리는 점 표시 (예: 남은 능력치 포인트).
  final bool highlight;

  DisabledReason? get activeReason => onPressed == null ? disabledReason : null;

  String get tooltip {
    final reason = activeReason;
    return reason == null ? label : '$label · ${reason.label}';
  }
}

/// 카테고리별 행동 목록. 새 행동은 여기에 추가한다.
List<GameActionButton> actionsFor(
  ActionCategory category,
  GameController controller, {
  required VoidCallback openCharacterSheet,
}) {
  switch (category) {
    case ActionCategory.movement:
      return [
        GameActionButton(
          label: '1턴 대기',
          icon: Icons.hourglass_empty,
          onPressed: controller.waitTurn,
        ),
        GameActionButton(
          label: '휴식 (HP·MP 완전 회복)',
          icon: Icons.hotel,
          onPressed: controller.canRest ? controller.rest : null,
          disabledReason: controller.enemyInSight
              ? DisabledReason.enemyInSight
              : DisabledReason.fullyRested,
        ),
        GameActionButton(
          label: '자동 탐험',
          icon: Icons.explore,
          onPressed: controller.canExplore ? controller.explore : null,
          disabledReason: DisabledReason.enemyInSight,
        ),
      ];
    case ActionCategory.combat:
      return [
        GameActionButton(
          label: '자동 전투',
          icon: Icons.gps_fixed,
          onPressed: controller.autoFight,
        ),
        GameActionButton(
          label: '1턴 대기',
          icon: Icons.hourglass_empty,
          onPressed: controller.waitTurn,
        ),
        const GameActionButton.comingSoon(
          label: '원거리 공격',
          icon: Icons.ads_click,
        ),
      ];
    case ActionCategory.item:
      return const [
        GameActionButton.comingSoon(label: '줍기', icon: Icons.pan_tool),
        GameActionButton.comingSoon(label: '소지품', icon: Icons.inventory_2),
        GameActionButton.comingSoon(label: '장비', icon: Icons.shield),
      ];
    case ActionCategory.skill:
      return [
        GameActionButton(
          label: '캐릭터',
          icon: Icons.person,
          onPressed: openCharacterSheet,
          highlight: controller.hasStatPoints,
        ),
        const GameActionButton.comingSoon(label: '적성', icon: Icons.school),
        const GameActionButton.comingSoon(
          label: '주문',
          icon: Icons.auto_fix_high,
        ),
      ];
  }
}

class ActionBar extends StatefulWidget {
  const ActionBar({super.key, required this.controller});

  final GameController controller;

  @override
  State<ActionBar> createState() => _ActionBarState();
}

class _ActionBarState extends State<ActionBar> {
  ActionCategory _category = ActionCategory.movement;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Container(
      color: const Color(0xFF15120F),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (final c in ActionCategory.values)
                Expanded(
                  child: _CategoryTab(
                    category: c,
                    selected: c == _category,
                    highlight:
                        c == ActionCategory.skill && controller.hasStatPoints,
                    onTap: () => setState(() => _category = c),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 52,
            // 자동 진행(이동/탐험/휴식) 중에는 어떤 탭이든 '중단'만 표시.
            child: controller.isTraveling
                ? _StopButton(controller: controller)
                : Row(
                    children: [
                      for (final (i, action) in actionsFor(
                        _category,
                        controller,
                        openCharacterSheet: () =>
                            showCharacterSheet(context, controller),
                      ).indexed) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(child: _ActionButton(action: action)),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({
    required this.category,
    required this.selected,
    required this.highlight,
    required this.onTap,
  });

  final ActionCategory category;
  final bool selected;
  final bool highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: category.label,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? accent : const Color(0xFF2E2924),
                width: selected ? 2 : 1,
              ),
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(
                category.icon,
                size: 22,
                color: selected ? accent : const Color(0xFF8A8478),
              ),
              if (highlight)
                const Positioned(right: -6, top: -2, child: _Dot()),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action});

  final GameActionButton action;

  @override
  Widget build(BuildContext context) {
    final reason = action.activeReason;
    return Tooltip(
      message: action.tooltip,
      child: FilledButton.tonal(
        onPressed: action.onPressed,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(action.icon, size: 28),
            if (action.highlight)
              const Positioned(right: -10, top: -4, child: _Dot()),
            if (reason != null)
              Positioned(
                right: -14,
                top: -6,
                child: Icon(
                  reason.icon,
                  size: 14,
                  color: const Color(0xFFB0A898),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StopButton extends StatelessWidget {
  const _StopButton({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final (modeIcon, tooltip) = switch (controller.autoMoveMode) {
      AutoMoveMode.explore => (Icons.explore, '탐험 중단'),
      AutoMoveMode.rest => (Icons.hotel, '휴식 중단'),
      _ => (Icons.route, '이동 중단'),
    };
    return Tooltip(
      message: tooltip,
      child: SizedBox.expand(
        child: FilledButton(
          onPressed: controller.stopTravel,
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          // 진행 중인 행동 아이콘 + 정지 아이콘
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(modeIcon, size: 22),
              const SizedBox(width: 6),
              const Icon(Icons.stop_circle, size: 30),
            ],
          ),
        ),
      ),
    );
  }
}
