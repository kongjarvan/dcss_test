import 'package:flutter/material.dart';

import '../core/entity/actor.dart';
import '../core/game.dart';
import '../core/items/item.dart';
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
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${items.length} / ${Player.inventoryCapacity}칸 · 누르면 상세 정보, 길게 누르면 이름',
              style: _dim,
            ),
            const SizedBox(height: 12),
            InventoryGrid(controller: controller, cellSize: 64),
          ],
        );
      },
    );
  }
}

/// DCSS식 소지품 칸: 아이콘만 보이고, 누르면 상세 정보.
/// 겹친 개수는 오른쪽 아래 숫자, 장착 중이면 노란 테두리. 빈 칸도 흐리게 보여준다.
class InventoryGrid extends StatelessWidget {
  const InventoryGrid({
    super.key,
    required this.controller,
    this.cellSize = 44,
    this.shrinkWrap = true,
  });

  final GameController controller;
  final double cellSize;

  /// 바깥에서 스크롤할 때(true)와 격자 자체가 스크롤할 때(false).
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final game = controller.game;
    final items = game.player.inventory;
    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: shrinkWrap ? EdgeInsets.zero : const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: cellSize,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: Player.inventoryCapacity,
      itemBuilder: (context, i) => i < items.length
          ? _ItemCell(
              game: game,
              item: items[i],
              onTap: () => showItemSheet(context, controller, items[i]),
            )
          : const _EmptyCell(),
    );
  }
}

class _ItemCell extends StatelessWidget {
  const _ItemCell({
    required this.game,
    required this.item,
    required this.onTap,
  });

  final Game game;
  final Item item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final equipped = game.player.isEquipped(item);
    return Tooltip(
      message: game.nameOf(item),
      child: Material(
        color: const Color(0xFF2A2621),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            color: equipped ? const Color(0xFFFFD54F) : const Color(0xFF3A342D),
            width: equipped ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: FittedBox(child: ItemIcon.of(game, item)),
                ),
              ),
              if (item.quantity > 1)
                Positioned(
                  right: 3,
                  bottom: 1,
                  child: Text(
                    '${item.quantity}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 2)],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCell extends StatelessWidget {
  const _EmptyCell();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFF1A1714),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: const Color(0xFF2A2621)),
    ),
  );
}

/// 아이템 상세 창 (장착/해제·마시기·버리기). 소지품 화면과 옆 패널에서 함께 쓴다.
Future<void> showItemSheet(
  BuildContext context,
  GameController controller,
  Item item,
) {
  return showModalBottomSheet<void>(
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

/// 발밑(바닥) 아이템의 상세 창. 줍기 버튼으로 그 아이템만 줍는다.
Future<void> showFloorItemSheet(
  BuildContext context,
  GameController controller,
  Item item,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1A1714),
    showDragHandle: true,
    builder: (sheetContext) => ListenableBuilder(
      listenable: controller,
      builder: (sheetContext, _) =>
          _FloorItemSheet(controller: controller, item: item),
    ),
  );
}

class _FloorItemSheet extends StatelessWidget {
  const _FloorItemSheet({required this.controller, required this.item});

  final GameController controller;
  final Item item;

  @override
  Widget build(BuildContext context) {
    final game = controller.game;
    // 주웠거나 자리를 떠났으면 창을 닫는다.
    if (!game.itemsAt(game.player.pos).contains(item)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return const SizedBox.shrink();
    }
    final full =
        game.player.isInventoryFull &&
        !game.player.inventory.any((owned) => owned.canStackWith(item));
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
                      const Text('바닥 · 줍는 데 1턴', style: _dim),
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
            if (full) ...[
              const SizedBox(height: 8),
              const Text(
                '소지품이 가득 찼다.',
                style: TextStyle(color: Color(0xFFE57373), fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            IconButton.filled(
              tooltip: full ? '줍기 · 소지품 가득' : '줍기',
              iconSize: 28,
              onPressed: full ? null : () => controller.pickUpItem(item),
              icon: const Icon(Icons.pan_tool),
            ),
          ],
        ),
      ),
    );
  }
}

/// 발밑 아이템을 가로로 늘어놓은 아이콘 목록. 누르면 상세 창.
class FloorItemStrip extends StatelessWidget {
  const FloorItemStrip({super.key, required this.controller, this.size = 24});

  final GameController controller;
  final double size;

  @override
  Widget build(BuildContext context) {
    final game = controller.game;
    final items = game.itemsAt(game.player.pos);
    return SizedBox(
      height: size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, i) {
          final item = items[i];
          return Tooltip(
            message: game.nameOf(item),
            child: InkWell(
              onTap: () => showFloorItemSheet(context, controller, item),
              borderRadius: BorderRadius.circular(4),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2621),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ItemIcon.of(game, item, size: size),
              ),
            ),
          );
        },
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
