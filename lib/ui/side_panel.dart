import 'package:flutter/material.dart';

import '../core/progression/skills.dart';
import 'game_controller.dart';
import 'inventory_screen.dart';
import 'skills_screen.dart';

enum SidePanelView {
  inventory('소지품 목록', Icons.inventory_2),
  skills('숙련도 목록', Icons.school);

  const SidePanelView(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// 오른쪽 패널 가운데: 소지품 / 숙련도를 전환해서 보여주는 간단한 목록.
class SidePanel extends StatefulWidget {
  const SidePanel({super.key, required this.controller});

  final GameController controller;

  @override
  State<SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends State<SidePanel> {
  SidePanelView _view = SidePanelView.inventory;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF0E0C0A),
      child: Column(
        children: [
          Row(
            children: [
              for (final v in SidePanelView.values)
                Expanded(
                  child: _ViewTab(
                    view: v,
                    selected: v == _view,
                    onTap: () => setState(() => _view = v),
                  ),
                ),
            ],
          ),
          Expanded(
            child: switch (_view) {
              SidePanelView.inventory => _InventoryList(
                controller: widget.controller,
              ),
              SidePanelView.skills => _SkillList(controller: widget.controller),
            },
          ),
        ],
      ),
    );
  }
}

class _ViewTab extends StatelessWidget {
  const _ViewTab({
    required this.view,
    required this.selected,
    required this.onTap,
  });

  final SidePanelView view;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: view.label,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? accent : const Color(0xFF2E2924),
                width: selected ? 2 : 1,
              ),
            ),
          ),
          child: Icon(
            view.icon,
            size: 18,
            color: selected ? accent : const Color(0xFF8A8478),
          ),
        ),
      ),
    );
  }
}

const _rowStyle = TextStyle(color: Color(0xFFE8E2D6), fontSize: 13);
const _dimStyle = TextStyle(color: Color(0xFF8A8478), fontSize: 12);

class _InventoryList extends StatelessWidget {
  const _InventoryList({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) =>
      InventoryGrid(controller: controller, shrinkWrap: false);
}

class _SkillList extends StatelessWidget {
  const _SkillList({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final skills = controller.game.player.skills;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        for (final skill in Skill.values)
          InkWell(
            onTap: () =>
                controller.setSkillTraining(skill, !skills.isTraining(skill)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              child: Row(
                children: [
                  Icon(
                    skills.isTraining(skill)
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 16,
                    color: skills.isTraining(skill)
                        ? const Color(0xFFFFD54F)
                        : const Color(0xFF4A453E),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      skill.label,
                      style: skills.level(skill) > 0 || skills.isTraining(skill)
                          ? _rowStyle
                          : _dimStyle,
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    child: Text(
                      aptitudeText(skills.aptitude(skill)),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: aptitudeColor(skills.aptitude(skill)),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${skills.level(skill)}',
                      textAlign: TextAlign.right,
                      style: _rowStyle,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
