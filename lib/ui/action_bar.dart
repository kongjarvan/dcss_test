import 'package:flutter/material.dart';

import 'game_controller.dart';

/// 하단 행동 버튼의 카테고리.
enum ActionCategory {
  movement('이동', Icons.directions_walk),
  combat('전투', Icons.sports_martial_arts),
  item('아이템', Icons.backpack),
  skill('적성', Icons.auto_graph);

  const ActionCategory(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// 행동 버튼 하나. [onPressed]가 null이면 비활성.
class GameActionButton {
  const GameActionButton({
    required this.label,
    required this.icon,
    this.onPressed,
    this.comingSoon = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  /// 아직 구현되지 않은 기능 자리.
  final bool comingSoon;
}

/// 카테고리별 행동 목록. 새 행동은 여기에 추가한다.
List<GameActionButton> actionsFor(
  ActionCategory category,
  GameController controller,
) {
  switch (category) {
    case ActionCategory.movement:
      return [
        GameActionButton(
          label: '대기',
          icon: Icons.hourglass_bottom,
          onPressed: controller.waitTurn,
        ),
        GameActionButton(
          label: '휴식',
          icon: Icons.bedtime,
          onPressed: controller.rest,
        ),
        const GameActionButton(
          label: '자동 탐험',
          icon: Icons.explore,
          comingSoon: true,
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
          label: '대기',
          icon: Icons.hourglass_bottom,
          onPressed: controller.waitTurn,
        ),
        const GameActionButton(
          label: '원거리 공격',
          icon: Icons.ads_click,
          comingSoon: true,
        ),
      ];
    case ActionCategory.item:
      return const [
        GameActionButton(label: '줍기', icon: Icons.pan_tool, comingSoon: true),
        GameActionButton(
          label: '소지품',
          icon: Icons.inventory_2,
          comingSoon: true,
        ),
        GameActionButton(label: '장비', icon: Icons.shield, comingSoon: true),
      ];
    case ActionCategory.skill:
      return const [
        GameActionButton(label: '적성', icon: Icons.auto_graph, comingSoon: true),
        GameActionButton(
          label: '주문',
          icon: Icons.auto_fix_high,
          comingSoon: true,
        ),
        GameActionButton(label: '능력', icon: Icons.bolt, comingSoon: true),
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
                    onTap: () => setState(() => _category = c),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 56,
            // 자동 이동 중에는 어떤 탭이든 '중단'만 표시.
            child: controller.isTraveling
                ? SizedBox.expand(
                    child: FilledButton.icon(
                      onPressed: controller.stopTravel,
                      icon: const Icon(Icons.stop),
                      label: const Text('이동 중단'),
                    ),
                  )
                : Row(
                    children: [
                      for (final (i, action) in actionsFor(
                        _category,
                        controller,
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
    required this.onTap,
  });

  final ActionCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final color = selected ? accent : const Color(0xFF8A8478);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? accent : const Color(0xFF2E2924),
              width: selected ? 2 : 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(category.icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              category.label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
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
    final enabled = action.onPressed != null;
    return FilledButton.tonal(
      onPressed: action.onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(action.icon, size: 20),
          const SizedBox(height: 2),
          Text(
            action.label,
            style: const TextStyle(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (action.comingSoon && !enabled)
            const Text(
              '준비 중',
              style: TextStyle(fontSize: 9, color: Color(0xFF8A8478)),
            ),
        ],
      ),
    );
  }
}
