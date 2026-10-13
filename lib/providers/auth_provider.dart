import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

const _savedUserKey = 'hearth.savedUserId';

/// Переопределяется в main() уже загруженным экземпляром SharedPreferences.
final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

class AuthNotifier extends Notifier<AppUser?> {
  @override
  AppUser? build() => null;

  /// id жильца, который входил последним (для автоматического входа).
  String? get savedUserId => ref.read(sharedPrefsProvider).getString(_savedUserKey);

  void login(AppUser user, {bool remember = true}) {
    state = user;
    if (remember) ref.read(sharedPrefsProvider).setString(_savedUserKey, user.id);
  }

  /// Обновляет данные текущего пользователя (например, после переименования).
  void refresh(AppUser user) {
    if (state?.id == user.id) state = user;
  }

  void logout() {
    state = null;
    ref.read(sharedPrefsProvider).remove(_savedUserKey);
  }
}

final currentUserProvider = NotifierProvider<AuthNotifier, AppUser?>(AuthNotifier.new);
