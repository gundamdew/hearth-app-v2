import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../models/user_model.dart';

final _money = NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0);
String formatMoney(num value) => _money.format(value);

/// Мобильная раскладка: ширина меньше 800.
bool isMobileLayout(BuildContext context) => MediaQuery.sizeOf(context).width < 800;

/// Базовая карточка Hearth: белая, мягкая тень, скругление 20.
class HearthCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  const HearthCard({super.key, required this.child, this.padding = const EdgeInsets.all(24), this.color, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor ?? AppTheme.hairline),
        boxShadow: [
          BoxShadow(color: AppTheme.textDark.withValues(alpha: 0.04), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: child,
    );
  }
}

/// Заголовок секции: маленькая подпись капсом + опциональный хвост справа.
class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(text.toUpperCase(), style: AppTheme.eyebrow)),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Заголовок страницы: serif-заголовок, подзаголовок и действия.
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  const PageHeader({super.key, required this.title, this.subtitle, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final mobile = isMobileLayout(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 16,
        runSpacing: 12,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (subtitle != null) ...[Text(subtitle!.toUpperCase(), style: AppTheme.eyebrow), const SizedBox(height: 6)],
              Text(title, style: AppTheme.serif(size: mobile ? 26 : 32)),
            ],
          ),
          if (actions.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ),
    );
  }
}

/// Тонкая полоса прогресса со скруглением.
class ProgressLine extends StatelessWidget {
  final double value;
  final Color color;
  final double height;
  const ProgressLine({super.key, required this.value, this.color = AppTheme.mossGreen, this.height = 6});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: height,
          backgroundColor: AppTheme.textLight.withValues(alpha: 0.1),
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    );
  }
}

class UserAvatar extends StatelessWidget {
  final AppUser? user;
  final double radius;
  const UserAvatar({super.key, required this.user, this.radius = 16});

  @override
  Widget build(BuildContext context) {
    final color = user?.color ?? AppTheme.textLight;
    final initial = (user?.name.isNotEmpty ?? false) ? user!.name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.18),
      child: Text(initial, style: TextStyle(color: color, fontSize: radius * 0.8, fontWeight: FontWeight.w700)),
    );
  }
}

/// Тег жильца в его персональном цвете.
class UserTag extends StatelessWidget {
  final String name;
  final Color color;
  final VoidCallback? onTap;
  const UserTag({super.key, required this.name, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(name.isEmpty ? 'Unassigned' : name, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
              if (onTap != null) ...[const SizedBox(width: 4), Icon(Icons.swap_horiz, size: 13, color: color)],
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const EmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, size: 28, color: AppTheme.textLight.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center, style: AppTheme.serif(size: 15, color: AppTheme.textLight, style: FontStyle.italic)),
        ],
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
}

class ErrorView extends StatelessWidget {
  final Object error;
  const ErrorView(this.error, {super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: HearthCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, color: AppTheme.red),
              const SizedBox(height: 12),
              Text('Could not load data', style: AppTheme.serif(size: 18)),
              const SizedBox(height: 6),
              Text('$error', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textLight, fontSize: 13)),
            ],
          ),
        ),
      );
}

/// Выполняет действие с Firebase и показывает ошибку в SnackBar, если что-то пошло не так.
Future<bool> runSafely(BuildContext context, Future<void> Function() action, {String? success}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    if (success != null) messenger.showSnackBar(SnackBar(content: Text(success)));
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Something went wrong: $e'), backgroundColor: AppTheme.red));
    return false;
  }
}

/// Подтверждение удаления.
Future<bool> confirmDelete(BuildContext context, String what) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Delete $what?'),
      content: const Text('This cannot be undone.', style: TextStyle(color: AppTheme.textLight)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return result ?? false;
}
