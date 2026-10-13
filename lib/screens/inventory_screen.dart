import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../models/inventory_item.dart';
import '../providers/inventory_provider.dart';
import '../widgets/common.dart';

const _locationIcons = {
  'Pantry': Icons.shelves,
  'Fridge': Icons.kitchen_outlined,
  'Freezer': Icons.ac_unit,
  'Household': Icons.home_repair_service_outlined,
  'Laundry': Icons.local_laundry_service_outlined,
};

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _filter = 'All';

  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _unitCtrl = TextEditingController(text: 'pcs');
  final _minCtrl = TextEditingController(text: '1');
  String _location = 'Pantry';

  @override
  void dispose() {
    for (final c in [_searchController, _nameCtrl, _qtyCtrl, _unitCtrl, _minCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _addItem() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final unit = _unitCtrl.text.trim().isEmpty ? 'pcs' : _unitCtrl.text.trim();
    final ok = await runSafely(
      context,
      () => ref.read(inventoryControllerProvider).addItem(
            name, _location, int.tryParse(_qtyCtrl.text) ?? 1, unit, int.tryParse(_minCtrl.text) ?? 1),
      success: '$name added to $_location',
    );
    if (ok && mounted) {
      setState(() {
        _nameCtrl.clear();
        _qtyCtrl.text = '1';
        _minCtrl.text = '1';
      });
    }
  }

  Future<void> _remove(InventoryItem item) async {
    final controller = ref.read(inventoryControllerProvider);
    final messenger = ScaffoldMessenger.of(context);
    await runSafely(context, () => controller.removeItem(item.id));
    messenger.showSnackBar(SnackBar(
      content: Text('${item.name} removed'),
      action: SnackBarAction(label: 'Undo', textColor: AppTheme.amber, onPressed: () => controller.restoreItem(item)),
    ));
  }

  Future<void> _editItem(InventoryItem item) async {
    final nameCtrl = TextEditingController(text: item.name);
    final unitCtrl = TextEditingController(text: item.unit);
    final minCtrl = TextEditingController(text: '${item.lowStockThreshold}');
    var location = inventoryLocations.contains(item.location) ? item.location : 'Pantry';
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Edit item'),
          content: SizedBox(
            width: 380,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: location,
                decoration: const InputDecoration(labelText: 'Location'),
                items: inventoryLocations.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                onChanged: (v) => setLocal(() => location = v ?? location),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'Unit'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: minCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Restock at'))),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (save != true || !mounted) return;
    await runSafely(
      context,
      () => ref.read(inventoryControllerProvider).updateItem(item.copyWith(
            name: nameCtrl.text.trim().isEmpty ? item.name : nameCtrl.text.trim(),
            unit: unitCtrl.text.trim().isEmpty ? item.unit : unitCtrl.text.trim(),
            location: location,
            lowStockThreshold: int.tryParse(minCtrl.text) ?? item.lowStockThreshold,
          )),
    );
  }

  void _showBulkImport(List<InventoryItem> existing) {
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import a shopping list'),
        content: SizedBox(
          width: 460,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Paste a message — one item per line, e.g. "* Butter – 2 pcs". Existing items are topped up.',
                style: TextStyle(color: AppTheme.textLight, fontSize: 13, height: 1.4)),
            const SizedBox(height: 16),
            TextField(
              controller: textCtrl,
              maxLines: 10,
              style: AppTheme.mono(size: 13),
              decoration: const InputDecoration(hintText: '* Płyn uniwersalny – 1 szt.\n* Kurczak – 2 szt.\n* Masło – 6 szt.'),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton.icon(
            icon: const Icon(Icons.playlist_add_check, size: 18),
            label: const Text('Import'),
            onPressed: () async {
              final raw = textCtrl.text.trim();
              if (raw.isEmpty) return;
              Navigator.pop(dialogContext);
              try {
                final count = await ref.read(inventoryControllerProvider).bulkAddFromText(raw, existing);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(count > 0 ? 'Imported or updated $count items' : 'No items recognised — check the format'),
                  backgroundColor: count > 0 ? AppTheme.mossGreen : AppTheme.red,
                ));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e'), backgroundColor: AppTheme.red));
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobileLayout(context);
    final inventoryAsync = ref.watch(inventoryProvider);
    if (inventoryAsync.hasError) return ErrorView(inventoryAsync.error!);
    if (!inventoryAsync.hasValue) return const LoadingView();

    final inventory = inventoryAsync.value!;
    final shopping = inventory.where((i) => i.isRunningLow).toList();

    final visible = inventory.where((item) {
      if (_filter == 'Running low' && !item.isRunningLow) return false;
      if (_filter != 'All' && _filter != 'Running low' && item.location != _filter) return false;
      return item.name.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    final grouped = <String, List<InventoryItem>>{};
    for (final item in visible) {
      grouped.putIfAbsent(item.location, () => []).add(item);
    }
    final orderedLocations = [
      ...inventoryLocations.where(grouped.containsKey),
      ...grouped.keys.where((k) => !inventoryLocations.contains(k)),
    ];

    final filters = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _chip('All', count: inventory.length),
        _chip('Running low', count: shopping.length, alert: shopping.isNotEmpty),
        for (final loc in inventoryLocations) _chip(loc, count: inventory.where((i) => i.location == loc).length),
      ]),
    );

    final search = TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _query = v),
      decoration: InputDecoration(
        hintText: 'Search items',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() {
                  _query = '';
                  _searchController.clear();
                })),
      ),
    );

    final list = HearthCard(
      padding: const EdgeInsets.fromLTRB(24, 12, 16, 16),
      child: visible.isEmpty
          ? EmptyState(icon: Icons.inventory_2_outlined, message: inventory.isEmpty ? 'Your shelves are empty. Add an item or paste a list.' : 'Nothing matches this filter.')
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final loc in orderedLocations) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 4),
                  child: Row(children: [
                    Icon(_locationIcons[loc] ?? Icons.inventory_2_outlined, size: 15, color: AppTheme.textLight),
                    const SizedBox(width: 8),
                    Text(loc.toUpperCase(), style: AppTheme.eyebrow),
                    const SizedBox(width: 8),
                    Text('${grouped[loc]!.length}', style: AppTheme.mono(size: 11, color: AppTheme.textLight)),
                  ]),
                ),
                ...grouped[loc]!.map(_itemRow),
              ],
            ]),
    );

    final shoppingCard = HearthCard(
      color: shopping.isEmpty ? null : AppTheme.amber.withValues(alpha: 0.08),
      borderColor: shopping.isEmpty ? null : AppTheme.amber.withValues(alpha: 0.35),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionLabel('Shopping list',
            trailing: shopping.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Copy list',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    onPressed: () {
                      final text = shopping.map((i) => '* ${i.name} – ${(i.lowStockThreshold * 2 - i.quantity).clamp(1, 999)} ${i.unit}').join('\n');
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shopping list copied')));
                    },
                  )),
        const SizedBox(height: 8),
        if (shopping.isEmpty)
          const EmptyState(icon: Icons.shopping_basket_outlined, message: 'Nothing to buy right now.')
        else ...[
          ...shopping.map((i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(i.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text('${i.quantity} ${i.unit} left  ·  ${i.location}', style: const TextStyle(fontSize: 12, color: AppTheme.textLight)),
                    ]),
                  ),
                  TextButton(
                    onPressed: () => runSafely(context, () => ref.read(inventoryControllerProvider).restock(i), success: '${i.name} restocked'),
                    child: const Text('Bought'),
                  ),
                ]),
              )),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => runSafely(context, () => ref.read(inventoryControllerProvider).restockAll(shopping), success: 'All items restocked'),
            child: const Text('Mark all as bought'),
          ),
        ],
      ]),
    );

    final addCard = HearthCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Add an item', style: AppTheme.serif(size: 20)),
        const SizedBox(height: 18),
        TextField(controller: _nameCtrl, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'Item name'), onSubmitted: (_) => _addItem()),
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final loc in inventoryLocations)
            ChoiceChip(
              label: Text(loc),
              avatar: Icon(_locationIcons[loc], size: 14, color: _location == loc ? Colors.white : AppTheme.textLight),
              selected: _location == loc,
              showCheckmark: false,
              selectedColor: AppTheme.mossGreen,
              labelStyle: TextStyle(color: _location == loc ? Colors.white : AppTheme.textDark, fontSize: 13),
              side: const BorderSide(color: AppTheme.hairline),
              shape: const StadiumBorder(),
              onSelected: (_) => setState(() => _location = loc),
            ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: _qtyCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Qty'))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: _unitCtrl, decoration: const InputDecoration(labelText: 'Unit'))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: _minCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Restock at'))),
        ]),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: _addItem, child: const Text('Add to inventory')),
      ]),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageHeader(
          subtitle: 'Inventory',
          title: 'Pantry & supplies',
          actions: [
            OutlinedButton.icon(onPressed: () => _showBulkImport(inventory), icon: const Icon(Icons.content_paste_go, size: 16), label: const Text('Paste list')),
          ],
        ),
        filters,
        const SizedBox(height: 14),
        if (mobile) ...[
          search, const SizedBox(height: 16), shoppingCard, const SizedBox(height: 16), list, const SizedBox(height: 16), addCard,
        ] else
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 6, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [search, const SizedBox(height: 16), list])),
            const SizedBox(width: 20),
            Expanded(flex: 4, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [shoppingCard, const SizedBox(height: 20), addCard])),
          ]),
      ]),
    );
  }

  Widget _itemRow(InventoryItem item) {
    final controller = ref.read(inventoryControllerProvider);
    final stockColor = item.quantity == 0 ? AppTheme.red : (item.isRunningLow ? AppTheme.amber : AppTheme.textDark);
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: AppTheme.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete_outline, color: AppTheme.red),
      ),
      onDismissed: (_) => _remove(item),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onLongPress: () => _editItem(item),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.hairline))),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(item.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
                  if (item.isRunningLow) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: stockColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                      child: Text(item.quantity == 0 ? 'OUT' : 'LOW', style: TextStyle(color: stockColor, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                Text('Restock at ${item.lowStockThreshold} ${item.unit}', style: const TextStyle(fontSize: 12, color: AppTheme.textLight)),
              ]),
            ),
            _StepButton(icon: Icons.remove, onTap: item.quantity == 0 ? null : () => controller.updateQuantity(item.id, item.quantity, -1)),
            SizedBox(
              width: 72,
              child: Text('${item.quantity} ${item.unit}', textAlign: TextAlign.center, style: AppTheme.mono(size: 13, color: stockColor)),
            ),
            _StepButton(icon: Icons.add, onTap: () => controller.updateQuantity(item.id, item.quantity, 1)),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.textLight),
              onSelected: (v) => v == 'edit' ? _editItem(item) : _remove(item),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppTheme.red))),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  Widget _chip(String label, {int? count, bool alert = false}) {
    final active = _filter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: active ? AppTheme.textDark : AppTheme.cardBackground.withValues(alpha: 0.6),
        shape: StadiumBorder(side: BorderSide(color: active ? AppTheme.textDark : AppTheme.hairline)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => setState(() => _filter = label),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(label, style: TextStyle(color: active ? Colors.white : AppTheme.textDark, fontWeight: FontWeight.w500, fontSize: 13)),
              if (count != null) ...[
                const SizedBox(width: 6),
                Text('$count', style: AppTheme.mono(size: 12, color: active ? Colors.white70 : (alert ? AppTheme.amber : AppTheme.textLight))),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: AppTheme.cream,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(7), child: Icon(icon, size: 15, color: onTap == null ? AppTheme.hairline : AppTheme.textDark)),
        ),
      );
}
