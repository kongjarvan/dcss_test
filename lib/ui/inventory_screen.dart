import 'package:flutter/material.dart';

import '../core/entity/actor.dart';
import '../core/game.dart';
import '../core/items/item.dart';
import '../core/progression/skill_effects.dart';
import '../core/progression/skills.dart';
import '../core/time/energy.dart';
import '../render/tile_renderer.dart';
import 'game_controller.dart';

const _renderer = ProceduralTileRenderer();
const _dim = TextStyle(color: Color(0xFF8A8478), fontSize: 13);

String _turns(int aut) => (aut / autPerTurn).toStringAsFixed(1);
String _signed(int n) => n >= 0 ? '+$n' : '$n';

/// 아이템 설명 한 줄. 예) "피해 10 · 명중 +1 · 공격 1.4턴 · 검"
/// 미확인 물약은 효과를 알려주지 않는다.
String itemSummary(Game game, Item item) {
  final type = item.type;
  return switch (type) {
    WeaponType() => [
      '피해 ${type.damage}',
      '명중 ${_signed(type.accuracy)}',
      '공격 ${_turns(type.delay)}턴',
      type.skill.label,
      if (type.twoHanded) '양손',
      if (type.reach > 1) '사거리 ${type.reach}',
      if (type.ranged) '원거리',
    ].join(' · '),
    ArmourType() => '방어 ${type.ac} · 무게 ${type.encumbrance}',
    ShieldType() => '막기 ${type.block} · 무게 ${type.encumbrance}',
    PotionType() =>
      game.isIdentified(item)
          ? type.potion.description
          : '마셔 보기 전에는 어떤 물약인지 알 수 없다.',
  };
}

/// 맵과 같은 그림으로 그린 아이템 아이콘. 물약은 게임마다 정해진 색으로.
class ItemIcon extends StatelessWidget {
  const ItemIcon(this.type, {super.key, this.tint, this.size = 40});

  ItemIcon.of(Game game, Item item, {Key? key, double size = 40})
    : this(item.type, key: key, tint: potionTint(game, item.type), size: size);

  final ItemType type;
  final int? tint;
  final double size;

  static int? potionTint(Game game, ItemType type) => switch (type) {
    PotionType(:final potion) => game.potionAppearance[potion]!.color,
    _ => null,
  };

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _ItemPainter(type, tint)),
  );
}

class _ItemPainter extends CustomPainter {
  _ItemPainter(this.type, this.tint);

  final ItemType type;
  final int? tint;

  @override
  void paint(Canvas canvas, Size size) =>
      _renderer.drawItem(canvas, Offset.zero & size, type, tint: tint);

  @override
  bool shouldRepaint(_ItemPainter old) => old.type != type || old.tint != tint;
}

/// 화면 아래에 가장 최근 메시지를 보여준다 (장착 결과 등 확인용).
class _LastMessage extends StatelessWidget {
  const _LastMessage({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final recent = controller.game.log.recent(1);
    return Container(
      width: double.infinity,
      color: const Color(0xFF15120F),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SafeArea(
        top: false,
        child: Text(
          recent.isEmpty ? '' : recent.single.text,
          style: const TextStyle(color: Color(0xFFF2EDE4), fontSize: 13),
        ),
      ),
    );
  }
}

Scaffold _screen({
  required String title,
  required GameController controller,
  required Widget Function() body,
}) {
  return Scaffold(
    backgroundColor: const Color(0xFF0E0C0A),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0E0C0A),
      title: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Text(title),
      ),
    ),
    body: ListenableBuilder(listenable: controller, builder: (_, _) => body()),
    bottomNavigationBar: ListenableBuilder(
      listenable: controller,
      builder: (_, _) => _LastMessage(controller: controller),
    ),
  );
}

// ───────────────────────── 소지품 ─────────────────────────

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key, required this.controller});

  final GameController controller;

  static Future<void> open(BuildContext context, GameController controller) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InventoryScreen(controller: controller),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final player = controller.game.player;
    return _screen(
      title: '소지품',
      controller: controller,
      body: () {
        final items = player.inventory;
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                '${items.length} / ${Player.inventoryCapacity}칸 · 아이템을 누르면 장착·마시기·버리기를 할 수 있습니다.',
                style: _dim,
              ),
            ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('소지품이 비어 있다.', style: _dim)),
              ),
            for (final item in items)
              _ItemTile(
                game: controller.game,
                item: item,
                equipped: player.isEquipped(item),
                onTap: () => _showItemSheet(context, item),
              ),
          ],
        );
      },
    );
  }

  void _showItemSheet(BuildContext context, Item item) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1714),
      showDragHandle: true,
      builder: (sheetContext) => ListenableBuilder(
        listenable: controller,
        builder: (sheetContext, _) =>
            _ItemSheet(controller: controller, item: item),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.game,
    required this.item,
    required this.equipped,
    required this.onTap,
  });

  final Game game;
  final Item item;
  final bool equipped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = item.type;
    return ListTile(
      onTap: onTap,
      leading: ItemIcon.of(game, item),
      title: Row(
        children: [
          Flexible(
            child: Text(
              game.nameOf(item),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          if (equipped && type is EquipmentType) ...[
            const SizedBox(width: 8),
            const Icon(Icons.check_circle, size: 16, color: Color(0xFFFFD54F)),
            const SizedBox(width: 2),
            Text(
              type.slot == EquipSlot.weapon ? '든 것' : '착용',
              style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 12),
            ),
          ],
        ],
      ),
      subtitle: Text(itemSummary(game, item), style: _dim),
    );
  }
}

/// 아이템 하나의 상세와 행동 버튼 (장비: 장착/해제·버리기, 물약: 마시기·버리기).
class _ItemSheet extends StatelessWidget {
  const _ItemSheet({required this.controller, required this.item});

  final GameController controller;
  final Item item;

  @override
  Widget build(BuildContext context) {
    final game = controller.game;
    final player = game.player;
    // 다 마셨거나 버렸으면 창을 닫는다.
    if (!player.inventory.contains(item)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return const SizedBox.shrink();
    }
    final type = item.type;
    final equipped = player.isEquipped(item);
    final problem = type is EquipmentType && !equipped
        ? player.equipProblem(item)
        : null;
    final kind = switch (type) {
      EquipmentType() =>
        '${type.slot.label} · 장착/해제 ${_turns(type.equipTime)}턴',
      PotionType() => '물약 · 마시는 데 1턴',
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ItemIcon.of(game, item, size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game.nameOf(item),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(kind, style: _dim),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              itemSummary(game, item),
              style: const TextStyle(color: Color(0xFFD8CFBF), fontSize: 14),
            ),
            if (problem != null) ...[
              const SizedBox(height: 8),
              Text(
                problem,
                style: const TextStyle(color: Color(0xFFE57373), fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                switch (type) {
                  PotionType() => IconButton.filled(
                    tooltip: '마시기',
                    iconSize: 28,
                    onPressed: () => controller.quaff(item),
                    icon: const Icon(Icons.local_drink),
                  ),
                  EquipmentType() when equipped => IconButton.filledTonal(
                    tooltip: '해제',
                    iconSize: 28,
                    onPressed: () => controller.unequip(type.slot),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  EquipmentType() => IconButton.filled(
                    tooltip: '장착',
                    iconSize: 28,
                    onPressed: problem == null
                        ? () => controller.equip(item)
                        : null,
                    icon: const Icon(Icons.check_circle_outline),
                  ),
                },
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  tooltip: equipped ? '버리기 · 먼저 해제' : '버리기',
                  iconSize: 28,
                  onPressed: equipped ? null : () => controller.drop(item),
                  icon: const Icon(Icons.file_download_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 물약 빠른 선택 창 (아이템 탭의 마시기 버튼). 누르면 바로 마시고 닫힌다.
Future<void> showQuaffSheet(BuildContext context, GameController controller) {
  final game = controller.game;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1A1714),
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final item in game.player.inventory.where(
            (i) => i.type is PotionType,
          ))
            ListTile(
              leading: ItemIcon.of(game, item),
              title: Text(
                game.nameOf(item),
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(itemSummary(game, item), style: _dim),
              onTap: () {
                Navigator.of(sheetContext).pop();
                controller.quaff(item);
              },
            ),
        ],
      ),
    ),
  );
}

// ───────────────────────── 장비 ─────────────────────────

class EquipmentScreen extends StatelessWidget {
  const EquipmentScreen({super.key, required this.controller});

  final GameController controller;

  static Future<void> open(BuildContext context, GameController controller) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EquipmentScreen(controller: controller),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final player = controller.game.player;
    return _screen(
      title: '장비',
      controller: controller,
      body: () => ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final slot in EquipSlot.values)
            _SlotTile(
              game: controller.game,
              slot: slot,
              item: player.equipped(slot),
              onUnequip: () => controller.unequip(slot),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Text(
              '전투 능력',
              style: TextStyle(
                color: Color(0xFFD8B04A),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...combatSummary(player).map(
            (line) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              child: Row(
                children: [
                  Expanded(child: Text(line.$1, style: _dim)),
                  Text(
                    line.$2,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.game,
    required this.slot,
    required this.item,
    required this.onUnequip,
  });

  final Game game;
  final EquipSlot slot;
  final Item? item;
  final VoidCallback onUnequip;

  @override
  Widget build(BuildContext context) {
    final item = this.item;
    return ListTile(
      leading: item == null
          ? const SizedBox.square(
              dimension: 40,
              child: Icon(Icons.crop_square, color: Color(0xFF4A453E)),
            )
          : ItemIcon(item.type),
      title: Text(
        item?.name ?? (slot == EquipSlot.weapon ? '맨손' : '없음'),
        style: TextStyle(
          color: item == null ? const Color(0xFF8A8478) : Colors.white,
        ),
      ),
      subtitle: Text(
        item == null
            ? slot.label
            : '${slot.label} · ${itemSummary(game, item)}',
        style: _dim,
      ),
      trailing: item == null
          ? null
          : IconButton(
              tooltip: '해제',
              onPressed: onUnequip,
              icon: const Icon(
                Icons.remove_circle_outline,
                color: Color(0xFFBDB6A8),
              ),
            ),
    );
  }
}

/// 현재 장비·능력치·숙련도가 모두 반영된 전투 수치.
List<(String, String)> combatSummary(Player player) {
  final melee = player.stats;
  final weapon = player.meleeWeapon;
  final meleeSkill = weapon?.skill ?? Skill.unarmed;
  final ranged = player.rangedStats;
  final dmgBonus = ((player.meleeDamageMultiplier - 1) * 100).round();
  return [
    (
      '근접 (${weapon?.name ?? '맨손'} · ${meleeSkill.label} ${player.skills.level(meleeSkill)})',
      '명중 ${melee.accuracy} · 피해 1~${melee.maxDamage} (${_signedPercent(dmgBonus)})',
    ),
    ('근접 공격 시간', '${_turns(player.meleeDelay)}턴'),
    if (player.reach > 1) ('근접 사거리', '${player.reach}칸'),
    if (ranged != null) ...[
      (
        '원거리 (${player.launcher!.name} · 활 ${player.skills.level(Skill.bow)})',
        '명중 ${ranged.accuracy} · 피해 1~${ranged.maxDamage} '
            '(${_signedPercent(((player.rangedDamageMultiplier - 1) * 100).round())})',
      ),
      ('원거리 공격 시간', '${_turns(player.rangedDelay)}턴'),
    ],
    ('방어력', '${melee.armor}'),
    ('회피', '${melee.evasion}'),
    ('막기 확률', '${(player.blockChance * 100).round()}%'),
    if (player.armourEvasionPenalty > 0)
      ('갑옷·방패 무게로 회피', '-${player.armourEvasionPenalty}'),
    (
      '무기 최소 공격 시간',
      weapon == null
          ? '-'
          : '${_turns(SkillEffects.minAttackDelay(weapon.delay))}턴',
    ),
  ];
}

String _signedPercent(int p) => '${p >= 0 ? '+' : ''}$p%';
