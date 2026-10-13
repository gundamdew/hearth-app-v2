import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../models/meal_models.dart';
import '../models/inventory_item.dart';
import '../providers/meals_provider.dart';
import '../providers/inventory_provider.dart';
import '../widgets/common.dart';

class MealsScreen extends ConsumerStatefulWidget {
  const MealsScreen({super.key});

  @override
  ConsumerState<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends ConsumerState<MealsScreen> {
  final _nameCtrl = TextEditingController();
  final _prepCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  String? _ingredientId;
  final List<RecipeIngredient> _draft = [];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _prepCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _addIngredient(List<InventoryItem> inventory) {
    final item = inventory.where((i) => i.id == _ingredientId).firstOrNull;
    if (item == null) return;
    final qty = int.tryParse(_qtyCtrl.text) ?? 1;
    setState(() {
      final existing = _draft.indexWhere((d) => d.inventoryId == item.id);
      if (existing != -1) {
        final prev = _draft[existing];
        _draft[existing] = RecipeIngredient(inventoryId: prev.inventoryId, name: prev.name, quantity: prev.quantity + qty);
      } else {
        _draft.add(RecipeIngredient(inventoryId: item.id, name: item.name, quantity: qty));
      }
      _qtyCtrl.text = '1';
      _ingredientId = null;
    });
  }

  Future<void> _saveRecipe() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _draft.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Give the recipe a name and at least one ingredient')));
      return;
    }
    final ok = await runSafely(
      context,
      () => ref.read(mealsControllerProvider).addRecipe(name, int.tryParse(_prepCtrl.text) ?? 30, List.of(_draft)),
      success: '$name saved to the recipe box',
    );
    if (ok && mounted) {
      setState(() {
        _nameCtrl.clear();
        _prepCtrl.clear();
        _draft.clear();
      });
      FocusScope.of(context).unfocus();
    }
  }

  void _pickRecipe(MealPlan plan, List<Recipe> recipes, List<InventoryItem> inventory) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBackground,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(DateFormat('EEEE, MMM d').format(plan.date), style: AppTheme.eyebrow),
            const SizedBox(height: 4),
            Text('What’s for dinner?', style: AppTheme.serif(size: 22)),
            const SizedBox(height: 16),
            if (recipes.isEmpty) const EmptyState(icon: Icons.menu_book_outlined, message: 'Your recipe box is empty. Draft a recipe first.'),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: recipes.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (_, i) {
                  final r = recipes[i];
                  final missing = _missingCount(r, inventory);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${r.ingredients.length} ingredients · ${r.prepTime ?? 30} min${missing > 0 ? ' · $missing missing' : ''}',
                      style: TextStyle(color: missing > 0 ? AppTheme.red : AppTheme.textLight, fontSize: 13),
                    ),
                    trailing: Icon(r.id == plan.recipeId ? Icons.check_circle : Icons.add_circle_outline, color: AppTheme.mossGreen),
                    onTap: () {
                      Navigator.pop(ctx);
                      runSafely(context, () => ref.read(mealsControllerProvider).assignRecipe(plan.id, r.id));
                    },
                  );
                },
              ),
            ),
            if (plan.recipeId != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  runSafely(context, () => ref.read(mealsControllerProvider).clearRecipe(plan.id));
                },
                child: const Text('Clear this day'),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  static int _missingCount(Recipe r, List<InventoryItem> inventory) => r.ingredients.where((ing) {
        final item = inventory.where((i) => i.id == ing.inventoryId).firstOrNull;
        return item == null || item.quantity < ing.quantity;
      }).length;

  Future<void> _cook(MealPlan plan, Recipe recipe, List<InventoryItem> inventory) async {
    final missing = _missingCount(recipe, inventory);
    if (missing > 0) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Some ingredients are short'),
          content: Text('$missing ingredient(s) for ${recipe.name} are not fully in stock. Their quantity will drop to zero.',
              style: const TextStyle(color: AppTheme.textLight)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cook anyway')),
          ],
        ),
      );
      if (go != true || !mounted) return;
    }
    final controller = ref.read(mealsControllerProvider);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await runSafely(context, () => controller.markCooked(plan.id, recipe.id));
    if (ok) {
      messenger.showSnackBar(SnackBar(
        content: Text('${recipe.name} cooked — ingredients deducted from inventory'),
        action: SnackBarAction(label: 'Undo', textColor: AppTheme.amber, onPressed: () => controller.undoCooked(plan.id, recipe.id)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobileLayout(context);
    final planAsync = ref.watch(mealPlanProvider);
    final recipesAsync = ref.watch(recipesProvider);
    final inventoryAsync = ref.watch(inventoryProvider);
    for (final a in [planAsync, recipesAsync, inventoryAsync]) {
      if (a.hasError) return ErrorView(a.error!);
    }
    if (!planAsync.hasValue || !recipesAsync.hasValue || !inventoryAsync.hasValue) return const LoadingView();

    final plan = planAsync.value!;
    final recipes = recipesAsync.value!;
    final inventory = inventoryAsync.value!;
    final planned = plan.where((p) => p.recipeId != null).length;

    final planner = SizedBox(
      height: 188,
      child: plan.isEmpty
          ? const HearthCard(child: EmptyState(icon: Icons.calendar_today_outlined, message: 'The planner will appear after the next app start.'))
          : ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: plan.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _dayCard(plan[i], recipes, inventory),
            ),
    );

    final recipeBox = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionLabel('Recipe box', trailing: Text('${recipes.length}', style: AppTheme.mono(size: 12, color: AppTheme.textLight))),
      const SizedBox(height: 14),
      if (recipes.isEmpty)
        const HearthCard(child: EmptyState(icon: Icons.menu_book_outlined, message: 'No recipes yet. Draft your first one.'))
      else
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth > 560 ? 2 : 1;
          final w = (c.maxWidth - (cols - 1) * 16) / cols;
          return Wrap(spacing: 16, runSpacing: 16, children: [
            for (final r in recipes) SizedBox(width: w, child: _recipeCard(r, inventory)),
          ]);
        }),
    ]);

    final draft = HearthCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Draft a recipe', style: AppTheme.serif(size: 20)),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(flex: 3, child: TextField(controller: _nameCtrl, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'Recipe title'))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _prepCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(hintText: 'Min'))),
        ]),
        const SizedBox(height: 22),
        Text('INGREDIENTS FROM INVENTORY', style: AppTheme.eyebrow),
        const SizedBox(height: 10),
        ..._draft.map((ing) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Text('${ing.quantity}×', style: AppTheme.mono(size: 13, color: AppTheme.textLight)),
                const SizedBox(width: 8),
                Expanded(child: Text(ing.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 16, color: AppTheme.textLight),
                  onPressed: () => setState(() => _draft.remove(ing)),
                ),
              ]),
            )),
        Row(children: [
          SizedBox(
            width: 64,
            child: TextField(controller: _qtyCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(hintText: 'Qty')),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<String>(
              key: ValueKey(_ingredientId == null ? 'empty-${_draft.length}' : _ingredientId),
              initialValue: _ingredientId,
              isExpanded: true,
              hint: const Text('Choose an item'),
              items: inventory.map((i) => DropdownMenuItem(value: i.id, child: Text(i.name, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => setState(() => _ingredientId = v),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filledTonal(onPressed: _ingredientId == null ? null : () => _addIngredient(inventory), icon: const Icon(Icons.add)),
        ]),
        const SizedBox(height: 22),
        ElevatedButton(onPressed: _saveRecipe, child: const Text('Save to recipe box')),
      ]),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageHeader(
          subtitle: 'Meals · $planned of ${plan.length} dinners planned',
          title: 'Upcoming menu',
        ),
        planner,
        const SizedBox(height: 28),
        if (mobile) ...[recipeBox, const SizedBox(height: 24), draft]
        else
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 6, child: recipeBox),
            const SizedBox(width: 20),
            Expanded(flex: 4, child: draft),
          ]),
      ]),
    );
  }

  Widget _dayCard(MealPlan plan, List<Recipe> recipes, List<InventoryItem> inventory) {
    final recipe = plan.recipeId == null
        ? null
        : recipes.where((r) => r.id == plan.recipeId).firstOrNull ?? Recipe(id: '', name: 'Deleted recipe', ingredients: []);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(plan.date.year, plan.date.month, plan.date.day);
    final diff = day.difference(today).inDays;
    final label = diff == 0 ? 'TODAY' : diff == 1 ? 'TOMORROW' : DateFormat('EEEE').format(plan.date).toUpperCase();
    final isToday = diff == 0;
    final missing = recipe != null && recipe.id.isNotEmpty ? _missingCount(recipe, inventory) : 0;

    final bg = plan.isCooked
        ? AppTheme.mossGreen
        : (recipe != null ? AppTheme.cardBackground : AppTheme.cardBackground.withValues(alpha: 0.5));
    final fg = plan.isCooked ? Colors.white : AppTheme.textDark;

    return SizedBox(
      width: 156,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: isToday && !plan.isCooked ? AppTheme.mossGreen : AppTheme.hairline, width: isToday ? 1.5 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _pickRecipe(plan, recipes, inventory),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: AppTheme.eyebrow.copyWith(color: plan.isCooked ? Colors.white70 : (isToday ? AppTheme.mossGreen : AppTheme.textLight))),
              Text(DateFormat('MMM d').format(plan.date), style: AppTheme.mono(size: 11, color: plan.isCooked ? Colors.white60 : AppTheme.textLight)),
              const SizedBox(height: 12),
              Expanded(
                child: recipe == null
                    ? Center(child: Icon(Icons.add, size: 28, color: AppTheme.textLight.withValues(alpha: 0.4)))
                    : Text(recipe.name, maxLines: 3, overflow: TextOverflow.ellipsis, style: AppTheme.serif(size: 15, color: fg)),
              ),
              if (recipe != null && recipe.id.isNotEmpty)
                plan.isCooked
                    ? InkWell(
                        onTap: () => runSafely(context, () => ref.read(mealsControllerProvider).undoCooked(plan.id, recipe.id)),
                        child: const Row(children: [
                          Icon(Icons.check_circle, size: 15, color: Colors.white),
                          SizedBox(width: 6),
                          Text('Cooked · undo', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        ]),
                      )
                    : Row(children: [
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.mossGreen,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            minimumSize: const Size(0, 30),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          onPressed: () => _cook(plan, recipe, inventory),
                          child: const Text('Mark cooked'),
                        ),
                        if (missing > 0) ...[
                          const SizedBox(width: 6),
                          Tooltip(message: '$missing missing', child: const Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.red)),
                        ],
                      ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _recipeCard(Recipe recipe, List<InventoryItem> inventory) {
    final missing = _missingCount(recipe, inventory);
    return HearthCard(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(recipe.name, style: AppTheme.serif(size: 17))),
          IconButton(
            tooltip: 'Delete recipe',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.textLight),
            onPressed: () async {
              if (await confirmDelete(context, 'recipe "${recipe.name}"') && mounted) {
                await runSafely(context, () => ref.read(mealsControllerProvider).deleteRecipe(recipe.id));
              }
            },
          ),
        ]),
        const SizedBox(height: 4),
        Text(
          '${recipe.prepTime ?? 30} min  ·  ${recipe.ingredients.length} ingredients'
          '${missing > 0 ? '  ·  $missing missing' : '  ·  ready to cook'}',
          style: TextStyle(fontSize: 12, color: missing > 0 ? AppTheme.red : AppTheme.mossGreen, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 14),
        Wrap(spacing: 6, runSpacing: 6, children: recipe.ingredients.map((ing) {
          final item = inventory.where((i) => i.id == ing.inventoryId).firstOrNull;
          final short = item == null || item.quantity < ing.quantity;
          final color = short ? AppTheme.red : AppTheme.mossGreen;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(short ? Icons.close : Icons.check, size: 12, color: color),
              const SizedBox(width: 5),
              Text('${ing.quantity} ${ing.name}', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
            ]),
          );
        }).toList()),
      ]),
    );
  }
}
