import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'screens/budget_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/meals_screen.dart';
import 'screens/cleaning_screen.dart';
import 'screens/overview_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'providers/budget_provider.dart';
import 'providers/meals_provider.dart';
import 'providers/auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);

  // Начальное заполнение не должно блокировать запуск приложения при проблемах с сетью
  try {
    await Future.wait([
      container.read(budgetControllerProvider).initializeCategories(),
      container.read(mealsControllerProvider).initializeMealPlans(),
    ]);
  } catch (e) {
    debugPrint('Hearth seed failed: $e');
  }

  runApp(UncontrolledProviderScope(container: container, child: const HearthApp()));
}

class _Destination {
  final String label;
  final String path;
  final IconData icon;
  final IconData activeIcon;
  const _Destination(this.label, this.path, this.icon, this.activeIcon);
}

const _destinations = [
  _Destination('Overview', '/', Icons.home_outlined, Icons.home_rounded),
  _Destination('Budget', '/budget', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet),
  _Destination('Inventory', '/inventory', Icons.kitchen_outlined, Icons.kitchen),
  _Destination('Meals', '/meals', Icons.restaurant_menu_outlined, Icons.restaurant_menu),
  _Destination('Cleaning', '/cleaning', Icons.cleaning_services_outlined, Icons.cleaning_services),
];

Page<void> _fade(GoRouterState state, Widget child) => CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child),
    );

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => MainScaffold(currentPath: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/', pageBuilder: (c, s) => _fade(s, const OverviewScreen())),
        GoRoute(path: '/budget', pageBuilder: (c, s) => _fade(s, const BudgetScreen())),
        GoRoute(path: '/inventory', pageBuilder: (c, s) => _fade(s, const InventoryScreen())),
        GoRoute(path: '/meals', pageBuilder: (c, s) => _fade(s, const MealsScreen())),
        GoRoute(path: '/cleaning', pageBuilder: (c, s) => _fade(s, const CleaningScreen())),
        GoRoute(path: '/settings', pageBuilder: (c, s) => _fade(s, const SettingsScreen())),
      ],
    ),
  ],
);

class HearthApp extends StatelessWidget {
  const HearthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Hearth',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: _router,
    );
  }
}

class MainScaffold extends ConsumerWidget {
  final Widget child;
  final String currentPath;

  const MainScaffold({super.key, required this.child, required this.currentPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    if (currentUser == null) return const LoginScreen();

    final mobile = isMobileLayout(context);
    final selectedIndex = _destinations.indexWhere((d) => d.path == currentPath);

    final userMenu = PopupMenuButton<String>(
      tooltip: 'Account',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) {
        if (value == 'settings') context.go('/settings');
        if (value == 'logout') ref.read(currentUserProvider.notifier).logout();
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'settings', child: ListTile(leading: Icon(Icons.tune), title: Text('Household settings'), contentPadding: EdgeInsets.zero)),
        PopupMenuItem(value: 'logout', child: ListTile(leading: Icon(Icons.logout), title: Text('Switch resident'), contentPadding: EdgeInsets.zero)),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(user: currentUser, radius: 13),
            const SizedBox(width: 8),
            Text(currentUser.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 16, color: AppTheme.textLight),
          ],
        ),
      ),
    );

    final header = Padding(
      padding: EdgeInsets.fromLTRB(mobile ? 20 : 32, mobile ? 12 : 24, mobile ? 20 : 32, mobile ? 12 : 20),
      child: Row(
        children: [
          InkWell(
            onTap: () => context.go('/'),
            borderRadius: BorderRadius.circular(8),
            child: Text('Hearth.', style: AppTheme.serif(size: mobile ? 26 : 32)),
          ),
          const Spacer(),
          if (!mobile) ...[
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.hairline),
              ),
              child: Row(
                children: [for (final d in _destinations) _NavPill(destination: d, active: d.path == currentPath)],
              ),
            ),
            const SizedBox(width: 16),
          ],
          userMenu,
        ],
      ),
    );

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          bottom: !mobile,
          child: Column(
            children: [
              header,
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(mobile ? 16 : 32, 0, mobile ? 16 : 32, mobile ? 0 : 24),
                      child: child,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: mobile
          ? NavigationBar(
              height: 68,
              selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
              indicatorColor: selectedIndex < 0 ? Colors.transparent : null,
              onDestinationSelected: (i) => context.go(_destinations[i].path),
              destinations: [
                for (final d in _destinations)
                  NavigationDestination(
                    icon: Icon(d.icon, color: AppTheme.textLight),
                    selectedIcon: Icon(d.activeIcon, color: AppTheme.mossGreen),
                    label: d.label,
                  ),
              ],
            )
          : null,
    );
  }
}

class _NavPill extends StatelessWidget {
  final _Destination destination;
  final bool active;
  const _NavPill({required this.destination, required this.active});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => context.go(destination.path),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: active ? AppTheme.mossGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            destination.label,
            style: TextStyle(
              color: active ? Colors.white : AppTheme.textLight,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
