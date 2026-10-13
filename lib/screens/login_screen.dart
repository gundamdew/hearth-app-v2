import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../models/user_model.dart';
import '../providers/users_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/common.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  AppUser? _selectedUser;
  String _enteredPin = '';
  bool _triedAutoLogin = false;
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));

  final _nameCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _shake.dispose();
    _nameCtrl.dispose();
    _pinCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _tryAutoLogin(List<AppUser> users) {
    if (_triedAutoLogin) return;
    _triedAutoLogin = true;
    final savedId = ref.read(currentUserProvider.notifier).savedUserId;
    if (savedId == null) return;
    for (final u in users) {
      if (u.id == savedId) {
        WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(currentUserProvider.notifier).login(u));
        return;
      }
    }
  }

  void _handleKeyPress(String key) {
    if (_selectedUser == null || _enteredPin.length >= 4) return;
    setState(() => _enteredPin += key);
    if (_enteredPin.length < 4) return;

    if (_enteredPin == _selectedUser!.pinCode) {
      ref.read(currentUserProvider.notifier).login(_selectedUser!);
    } else {
      HapticFeedback.mediumImpact();
      _shake.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 380), () {
        if (mounted) setState(() => _enteredPin = '');
      });
    }
  }

  void _backspace() {
    if (_enteredPin.isNotEmpty) setState(() => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1));
  }

  Future<void> _createFirstUser() async {
    final name = _nameCtrl.text.trim();
    final pin = _pinCtrl.text.trim();
    if (name.isEmpty || !RegExp(r'^\d{4}$').hasMatch(pin)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a name and a 4-digit PIN')));
      return;
    }
    await runSafely(context, () => ref.read(usersControllerProvider).addUser(name, pin, AppTheme.terracotta));
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: usersAsync.when(
                loading: () => const LoadingView(),
                error: (err, _) => ErrorView(err),
                data: (users) {
                  if (users.isEmpty) return _buildFirstUserForm();
                  _tryAutoLogin(users);
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _selectedUser == null ? _buildUserSelection(users) : _buildPinPad(),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _brand() => Column(
        children: [
          Text('Hearth.', style: AppTheme.serif(size: 44)),
          const SizedBox(height: 8),
          Text('A SHARED HOME, KEPT GENTLY', style: AppTheme.eyebrow),
        ],
      );

  Widget _buildFirstUserForm() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        children: [
          _brand(),
          const SizedBox(height: 40),
          HearthCard(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Welcome home.', style: AppTheme.serif(size: 24)),
                const SizedBox(height: 8),
                const Text("Let's create the first resident profile. You can add your housemate later in settings.",
                    style: TextStyle(color: AppTheme.textLight, height: 1.4)),
                const SizedBox(height: 28),
                TextField(controller: _nameCtrl, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 14),
                TextField(
                  controller: _pinCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: '4-digit PIN', counterText: ''),
                  onSubmitted: (_) => _createFirstUser(),
                ),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: _createFirstUser, child: const Text('Create profile')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserSelection(List<AppUser> users) {
    return Column(
      key: const ValueKey('select'),
      children: [
        _brand(),
        const SizedBox(height: 56),
        Text('Who is home?', style: AppTheme.serif(size: 26)),
        const SizedBox(height: 32),
        Wrap(
          spacing: 20,
          runSpacing: 20,
          alignment: WrapAlignment.center,
          children: users
              .map((user) => InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => setState(() {
                      _selectedUser = user;
                      _enteredPin = '';
                      _focus.requestFocus();
                    }),
                    child: HearthCard(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                      child: Column(
                        children: [
                          UserAvatar(user: user, radius: 40),
                          const SizedBox(height: 14),
                          Text(user.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildPinPad() {
    final user = _selectedUser!;
    return KeyboardListener(
      key: const ValueKey('pin'),
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is! KeyDownEvent) return;
        final ch = event.character;
        if (ch != null && RegExp(r'^\d$').hasMatch(ch)) _handleKeyPress(ch);
        if (event.logicalKey == LogicalKeyboardKey.backspace) _backspace();
        if (event.logicalKey == LogicalKeyboardKey.escape) setState(() => _selectedUser = null);
      },
      child: Column(
        children: [
          UserAvatar(user: user, radius: 36),
          const SizedBox(height: 16),
          Text('Hello, ${user.name}', style: AppTheme.serif(size: 24)),
          const SizedBox(height: 6),
          const Text('Enter your PIN', style: TextStyle(color: AppTheme.textLight)),
          const SizedBox(height: 28),
          AnimatedBuilder(
            animation: _shake,
            builder: (context, child) {
              final t = _shake.value;
              final dx = t == 0 ? 0.0 : 10 * (1 - t) * ((t * 8).floor().isEven ? 1 : -1);
              return Transform.translate(offset: Offset(dx, 0), child: child);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(4, (i) {
                final filled = i < _enteredPin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? user.color : Colors.transparent,
                    border: Border.all(color: filled ? user.color : AppTheme.textLight.withValues(alpha: 0.4), width: 1.5),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: 276,
            child: Wrap(
              spacing: 18,
              runSpacing: 18,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 1; i <= 9; i++) _pinButton('$i', onTap: () => _handleKeyPress('$i')),
                _pinButton('Back', isAction: true, onTap: () => setState(() => _selectedUser = null)),
                _pinButton('0', onTap: () => _handleKeyPress('0')),
                _pinButton('', icon: Icons.backspace_outlined, isAction: true, onTap: _backspace),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pinButton(String label, {required VoidCallback onTap, bool isAction = false, IconData? icon}) {
    return Material(
      color: isAction ? Colors.transparent : AppTheme.cardBackground,
      shape: CircleBorder(side: isAction ? BorderSide.none : const BorderSide(color: AppTheme.hairline)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 72,
          height: 72,
          child: Center(
            child: icon != null
                ? Icon(icon, size: 20, color: AppTheme.textLight)
                : Text(label,
                    style: isAction
                        ? const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textLight)
                        : AppTheme.mono(size: 24)),
          ),
        ),
      ),
    );
  }
}
