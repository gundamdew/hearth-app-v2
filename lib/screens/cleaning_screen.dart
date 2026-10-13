import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../models/chore.dart';
import '../models/user_model.dart';
import '../providers/cleaning_provider.dart';
import '../providers/users_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/common.dart';

class CleaningScreen extends ConsumerStatefulWidget {
  const CleaningScreen({super.key});

  @override
  ConsumerState<CleaningScreen> createState() => _CleaningScreenState();
}

class _CleaningScreenState extends ConsumerState<CleaningScreen> {
  final _taskCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  String? _assignee;
  String? _personFilter;

  @override
  void dispose() {
    _taskCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _taskCtrl.text.trim();
    if (name.isEmpty || _assignee == null) return;
    final category = _categoryCtrl.text.trim();
    final ok = await runSafely(context,
        () => ref.read(cleaningControllerProvider).addChore(name, category.isEmpty ? 'General' : category, _assignee!));
    if (ok && mounted) {
      _taskCtrl.clear();
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _delete(Chore chore) async {
    final controller = ref.read(cleaningControllerProvider);
    final messenger = ScaffoldMessenger.of(context);
    await runSafely(context, () => controller.deleteChore(chore.id));
    messenger.showSnackBar(SnackBar(
      content: Text('"${chore.name}" removed'),
      action: SnackBarAction(label: 'Undo', textColor: AppTheme.amber, onPressed: () => controller.restoreChore(chore)),
    ));
  }

  Future<void> _newWeek(List<Chore> chores, List<String> names) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start a new week?'),
        content: const Text('All checkmarks are cleared and every chore passes to the other resident.', style: TextStyle(color: AppTheme.textLight)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Swap & reset')),
        ],
      ),
    );
    if (go == true && mounted) {
      await runSafely(context, () => ref.read(cleaningControllerProvider).swapAndNewWeek(chores, names), success: 'Fresh week — roles swapped');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobileLayout(context);
    final choresAsync = ref.watch(cleaningProvider);
    final usersAsync = ref.watch(usersProvider);
    final me = ref.watch(currentUserProvider);

    if (choresAsync.hasError) return ErrorView(choresAsync.error!);
    if (usersAsync.hasError) return ErrorView(usersAsync.error!);
    if (!choresAsync.hasValue || !usersAsync.hasValue) return const LoadingView();

    final chores = choresAsync.value!;
    final users = usersAsync.value!;
    final names = users.map((u) => u.name).toList();
    if (_assignee == null || !names.contains(_assignee)) {
      _assignee = me != null && names.contains(me.name) ? me.name : names.firstOrNull;
    }

    final done = chores.where((c) => c.isDone).length;
    final visible = _personFilter == null ? chores : chores.where((c) => c.assignee == _personFilter).toList();

    AppUser userFor(String name) => users.firstWhere((u) => u.name == name,
        orElse: () => AppUser(id: '', name: name, pinCode: '', color: AppTheme.textLight));

    final overall = HearthCard(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionLabel('Household progress', trailing: Text('$done / ${chores.length}', style: AppTheme.mono(size: 13))),
        const SizedBox(height: 12),
        ProgressLine(value: chores.isEmpty ? 0 : done / chores.length, height: 8),
        const SizedBox(height: 20),
        Wrap(spacing: 12, runSpacing: 12, children: [
          for (final u in users) _residentCard(u, chores),
        ]),
      ]),
    );

    final listCard = HearthCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (visible.isEmpty)
          const EmptyState(icon: Icons.cleaning_services_outlined, message: 'No chores here. Add one below.')
        else
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) const Divider(),
            _choreRow(visible[i], userFor(visible[i].assignee), names),
          ],
        const SizedBox(height: 16),
        _addForm(users, mobile),
      ]),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageHeader(
          subtitle: 'Cleaning',
          title: "This week's rota",
          actions: [
            OutlinedButton.icon(
              onPressed: chores.isEmpty ? null : () => runSafely(context, () => ref.read(cleaningControllerProvider).balanceLoad(chores, names), success: 'Load balanced'),
              icon: const Icon(Icons.balance, size: 16),
              label: const Text('Balance load'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
              onPressed: chores.isEmpty ? null : () => _newWeek(chores, names),
              icon: const Icon(Icons.autorenew, size: 16),
              label: const Text('Swap & new week'),
            ),
          ],
        ),
        overall,
        const SizedBox(height: 16),
        listCard,
      ]),
    );
  }

  Widget _residentCard(AppUser user, List<Chore> chores) {
    final mine = chores.where((c) => c.assignee == user.name).toList();
    final done = mine.where((c) => c.isDone).length;
    final selected = _personFilter == user.name;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _personFilter = selected ? null : user.name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 240,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: user.color.withValues(alpha: selected ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? user.color : Colors.transparent),
        ),
        child: Row(children: [
          UserAvatar(user: user, radius: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(user.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                Text('$done/${mine.length}', style: AppTheme.mono(size: 12, color: AppTheme.textLight)),
              ]),
              const SizedBox(height: 10),
              ProgressLine(value: mine.isEmpty ? 0 : done / mine.length, color: user.color, height: 5),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _choreRow(Chore chore, AppUser user, List<String> names) {
    final controller = ref.read(cleaningControllerProvider);
    return Dismissible(
      key: ValueKey(chore.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppTheme.red.withValues(alpha: 0.1),
        child: const Icon(Icons.delete_outline, color: AppTheme.red),
      ),
      onDismissed: (_) => _delete(chore),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Checkbox(value: chore.isDone, onChanged: (_) => runSafely(context, () => controller.toggleStatus(chore.id, chore.isDone))),
          const SizedBox(width: 4),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  decoration: chore.isDone ? TextDecoration.lineThrough : null,
                  color: chore.isDone ? AppTheme.textLight : AppTheme.textDark,
                ),
                child: Text(chore.name),
              ),
              const SizedBox(height: 2),
              Text(chore.category, style: const TextStyle(fontSize: 12, color: AppTheme.textLight)),
            ]),
          ),
          UserTag(
            name: chore.assignee,
            color: user.color,
            onTap: names.length < 2 ? null : () => runSafely(context, () => controller.changeAssignee(chore.id, chore.assignee, names)),
          ),
          IconButton(
            tooltip: 'Delete',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 16, color: AppTheme.textLight),
            onPressed: () => _delete(chore),
          ),
        ]),
      ),
    );
  }

  Widget _addForm(List<AppUser> users, bool mobile) {
    final people = Wrap(spacing: 6, children: [
      for (final u in users)
        ChoiceChip(
          avatar: UserAvatar(user: u, radius: 10),
          label: Text(u.name),
          selected: _assignee == u.name,
          showCheckmark: false,
          selectedColor: u.color.withValues(alpha: 0.22),
          side: BorderSide(color: _assignee == u.name ? u.color : AppTheme.hairline),
          shape: const StadiumBorder(),
          onSelected: (_) => setState(() => _assignee = u.name),
        ),
    ]);
    final task = TextField(controller: _taskCtrl, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'e.g. Mop kitchen floor'), onSubmitted: (_) => _submit());
    final category = TextField(controller: _categoryCtrl, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'Room / category'));
    final button = ElevatedButton(onPressed: _submit, child: const Text('Add task'));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.cream, borderRadius: BorderRadius.circular(14)),
      child: mobile
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('ADD A TASK', style: AppTheme.eyebrow),
              const SizedBox(height: 12),
              task, const SizedBox(height: 10), category, const SizedBox(height: 10), people, const SizedBox(height: 12), button,
            ])
          : Row(children: [
              Expanded(flex: 3, child: task),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: category),
              const SizedBox(width: 10),
              people,
              const SizedBox(width: 10),
              button,
            ]),
    );
  }
}
