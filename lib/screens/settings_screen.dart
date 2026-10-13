import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../models/user_model.dart';
import '../providers/users_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/common.dart';

const _palette = [AppTheme.terracotta, AppTheme.sage, AppTheme.amber, Color(0xFF6B7FA8), Color(0xFF9B6BA8), Color(0xFF4F8A8B)];

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _showUserDialog(BuildContext context, WidgetRef ref, List<AppUser> users, [AppUser? user]) async {
    final nameCtrl = TextEditingController(text: user?.name ?? '');
    final pinCtrl = TextEditingController(text: user?.pinCode ?? '');
    final usedColors = users.map((u) => u.color.toARGB32()).toSet();
    var color = user?.color ?? _palette.firstWhere((c) => !usedColors.contains(c.toARGB32()), orElse: () => _palette.first);
    String? error;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(user == null ? 'Add a resident' : 'Edit ${user.name}'),
          content: SizedBox(
            width: 360,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(controller: nameCtrl, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 12),
              TextField(
                controller: pinCtrl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: '4-digit PIN', counterText: ''),
              ),
              const SizedBox(height: 16),
              Text('COLOUR', style: AppTheme.eyebrow),
              const SizedBox(height: 10),
              Wrap(spacing: 10, children: [
                for (final c in _palette)
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setLocal(() => color = c),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(color: color.toARGB32() == c.toARGB32() ? AppTheme.textDark : Colors.transparent, width: 2),
                      ),
                    ),
                  ),
              ]),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: const TextStyle(color: AppTheme.red, fontSize: 13)),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final pin = pinCtrl.text.trim();
                if (name.isEmpty || pin.length != 4) {
                  setLocal(() => error = 'Enter a name and a 4-digit PIN.');
                  return;
                }
                if (users.any((u) => u.id != user?.id && u.name.toLowerCase() == name.toLowerCase())) {
                  setLocal(() => error = 'Another resident already uses this name.');
                  return;
                }
                Navigator.pop(ctx);
                final controller = ref.read(usersControllerProvider);
                await runSafely(context, () async {
                  if (user == null) {
                    await controller.addUser(name, pin, color);
                  } else {
                    await controller.updateUser(user.id, user.name, name, pin, color: color);
                    ref.read(currentUserProvider.notifier).refresh(user.copyWith(name: name, pinCode: pin, color: color));
                  }
                });
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersProvider);
    final me = ref.watch(currentUserProvider);
    if (usersAsync.hasError) return ErrorView(usersAsync.error!);
    if (!usersAsync.hasValue) return const LoadingView();
    final users = usersAsync.value!;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageHeader(
          subtitle: 'Settings',
          title: 'Household',
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
              onPressed: () => _showUserDialog(context, ref, users),
              icon: const Icon(Icons.person_add_alt, size: 18),
              label: const Text('Add resident'),
            ),
          ],
        ),
        HearthCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(children: [
            for (var i = 0; i < users.length; i++) ...[
              if (i > 0) const Divider(),
              ListTile(
                leading: UserAvatar(user: users[i], radius: 20),
                title: Row(children: [
                  Text(users[i].name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (users[i].id == me?.id) ...[
                    const SizedBox(width: 8),
                    Text('YOU', style: AppTheme.eyebrow.copyWith(fontSize: 10, color: AppTheme.mossGreen)),
                  ],
                ]),
                subtitle: Text('PIN ••••', style: AppTheme.mono(size: 12, color: AppTheme.textLight)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined, color: AppTheme.textLight), onPressed: () => _showUserDialog(context, ref, users, users[i])),
                  IconButton(
                    tooltip: users[i].id == me?.id ? 'You cannot remove yourself' : 'Remove',
                    icon: Icon(Icons.delete_outline, color: users[i].id == me?.id ? AppTheme.hairline : AppTheme.red),
                    onPressed: users[i].id == me?.id
                        ? null
                        : () async {
                            if (await confirmDelete(context, 'resident ${users[i].name}') && context.mounted) {
                              await runSafely(context, () => ref.read(usersControllerProvider).deleteUser(users[i].id));
                            }
                          },
                  ),
                ]),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        const Text(
          'Residents sign in with a 4-digit PIN. The last resident stays signed in on this device until they switch. '
          'Renaming a resident also updates their chores and transactions.',
          style: TextStyle(color: AppTheme.textLight, fontSize: 13, height: 1.5),
        ),
      ]),
    );
  }
}
