import 'package:flutter/material.dart';

import '../core/progression/skills.dart';
import 'game_controller.dart';

/// 적성 값 표시용 색: 높으면 초록, 낮으면 빨강.
Color aptitudeColor(int aptitude) => aptitude > 0
    ? const Color(0xFF7BC67B)
    : aptitude < 0
    ? const Color(0xFFE57373)
    : const Color(0xFF6E685E);

String aptitudeText(int aptitude) => aptitude > 0 ? '+$aptitude' : '$aptitude';

/// 숙련도 목록. 행을 누르면 훈련을 켜고 끈다.
class SkillsScreen extends StatelessWidget {
  const SkillsScreen({super.key, required this.controller});

  final GameController controller;

  static Future<void> open(BuildContext context, GameController controller) =>
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SkillsScreen(controller: controller)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0C0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E0C0A),
        title: const Text('숙련도'),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final skills = controller.game.player.skills;
          final count = skills.training.length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(
                count == 0
                    ? '훈련 중인 숙련도가 없습니다. 얻은 경험치는 보관되었다가 훈련을 켜면 나누어 쌓입니다.'
                    : '얻은 경험치가 훈련 중인 숙련도 $count개에 똑같이 나뉘어 쌓입니다.',
                style: const TextStyle(color: Color(0xFFBDB6A8), fontSize: 13),
              ),
              const SizedBox(height: 4),
              const Text(
                '적성이 높을수록 적은 경험치로 레벨이 오릅니다 (+4마다 절반).',
                style: TextStyle(color: Color(0xFF8A8478), fontSize: 12),
              ),
              for (final category in SkillCategory.values) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 18, bottom: 4),
                  child: Text(
                    category.label,
                    style: const TextStyle(
                      color: Color(0xFFD8B04A),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                for (final skill in Skill.values.where(
                  (s) => s.category == category,
                ))
                  _SkillRow(
                    skill: skill,
                    skills: skills,
                    onToggle: () => controller.setSkillTraining(
                      skill,
                      !skills.isTraining(skill),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SkillRow extends StatelessWidget {
  const _SkillRow({
    required this.skill,
    required this.skills,
    required this.onToggle,
  });

  final Skill skill;
  final SkillSet skills;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final training = skills.isTraining(skill);
    final level = skills.level(skill);
    final apt = skills.aptitude(skill);
    final maxed = level >= SkillProgression.maxLevel;
    return InkWell(
      onTap: maxed ? null : onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Icon(
              training ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 22,
              color: training
                  ? const Color(0xFFFFD54F)
                  : const Color(0xFF4A453E),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 76,
              child: Text(
                skill.label,
                style: TextStyle(
                  color: level > 0 || training
                      ? Colors.white
                      : const Color(0xFF8A8478),
                  fontSize: 15,
                ),
              ),
            ),
            SizedBox(
              width: 30,
              child: Text(
                aptitudeText(apt),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: aptitudeColor(apt),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: skills.progress(skill),
                  minHeight: 5,
                  color: training
                      ? const Color(0xFFFFD54F)
                      : const Color(0xFF6E685E),
                  backgroundColor: const Color(0xFF2A2621),
                ),
              ),
            ),
            SizedBox(
              width: 36,
              child: Text(
                '$level',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
