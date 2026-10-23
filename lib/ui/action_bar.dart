import 'package:flutter/material.dart';

import '../core/world/tile.dart';
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

/// 버튼을 쓸 수 없는 이유. 버튼 모서리에 작은 배지 아이콘으로 표시.
enum DisabledReason {
  enemyInSight('적이 보임', Icons.visibility),
  fullyRested('회복 완료', Icons.favorite),
  noTarget('대상 없음', Icons.location_disabled),
  stairsUnknown('계단 모름', Icons.help_outline);

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

  /// 길게 눌렀을 때 툴팁으로 표시.
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final DisabledReason? disabledReason;

  /// 확인할 것이 있음을 알리는 점 표시 (예: 계단 위).
  final bool highlight;

  DisabledReason? get activeReason => onPressed == null ? disabledReason : null;

  String get tooltip {
    final reason = activeReason;
    return reason == null ? label : '$label · ${reason.label}';
  }
}

/// 하단 행동 버튼: 자동 탐험 · 공격 · 휴식 · 계단.
List<GameActionButton> actionsFor(GameController controller) => [
  GameActionButton(
    label: '자동 탐험',
    icon: Icons.explore,
    onPressed: controller.canExplore ? controller.explore : null,
    disabledReason: DisabledReason.enemyInSight,
  ),
  // 무기에 맞춰 알아서 공격: 활이면 쏘고, 장병기면 2칸에서 찌르고, 아니면 다가가 근접.
  GameActionButton(
    label: '공격',
    icon: Icons.gps_fixed,
    onPressed: controller.enemyInSight ? controller.autoFight : null,
    disabledReason: DisabledReason.noTarget,
  ),
  GameActionButton(
    label: '휴식 (HP·MP 완전 회복)',
    icon: Icons.hotel,
    onPressed: controller.canRest ? controller.rest : null,
    disabledReason: controller.enemyInSight
        ? DisabledReason.enemyInSight
        : DisabledReason.fullyRested,
  ),
  // 계단 위면 그 계단을 이용하고, 아니면 가장 가까운 내려가는 계단까지 이동.
  GameActionButton(
    label: switch (controller.stairsHere) {
      _ when !controller.onStairs => '내려가는 계단으로 이동',
      TileType.stairsUp => '계단 올라가기',
      _ => '계단 내려가기',
    },
    icon: switch (controller.stairsHere) {
      _ when !controller.onStairs => Icons.stairs,
      TileType.stairsUp => Icons.arrow_upward,
      _ => Icons.arrow_downward,
    },
    onPressed: controller.canUseStairs ? controller.useOrGoToStairs : null,
    disabledReason: controller.knownStairs == null
        ? DisabledReason.stairsUnknown
        : DisabledReason.enemyInSight,
    highlight: controller.onStairs,
  ),
];

class ActionBar extends StatelessWidget {
  const ActionBar({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF15120F),
      padding: const EdgeInsets.all(8),
      child: SizedBox(
        height: 52,
        // 자동 진행(이동/탐험/휴식) 중에는 '중단'만 표시.
        child: controller.isTraveling
            ? _StopButton(controller: controller)
            : Row(
                children: [
                  for (final (i, action) in actionsFor(controller).indexed) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(child: _ActionButton(action: action)),
                  ],
                ],
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
